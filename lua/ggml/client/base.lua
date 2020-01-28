GGML = GGML or {}
GGML.elements = GGML.elements or {}

include("xmlparser.lua")
include("context.lua")
include("helper.lua")
include("fontmanager.lua")
include("lookups/tagaliases.lua")
include("lookups/attraliases.lua")
include("lookups/attrsetters.lua")
include("lookups/percentfuncs.lua")
include("example/example.lua")

local screen = {
    GetWide = ScrW,
    GetTall = ScrH
}

local function indexAllSuper(tab, tag, key)
    if tab.All and tab.All[key] then
        return tab.All[key]
    end
    while true do
        local t = vgui.GetControlTable(tag)
        if not t then break end
        
        if tag[1] == "D" then
            local newTag = string.sub(tag, 2)
            if tab[newTag] and tab[newTag][key] then
                return tab[newTag][key]
            end
        end

        if tab[tag] and tab[tag][key] then
            return tab[tag][key]
        end
        tag = t.Base
    end
    return nil
end

local function getGlobalValue(v)
    local pos = _G
    local vs = string.Split(v, ".")
    for k, v in ipairs(vs) do
        pos = pos[v]
        if not istable(pos) then return pos end
    end
    return pos
end

local function findClassName(tag)
    if not vgui.GetControlTable(tag) then
        if not vgui.GetControlTable("D" .. tag) then
            error("Invalid XML for GGML object \"" .. name .. "\": Couldn't resolve tag \"" .. tag .. "\"")
        else
            return "D" .. tag
        end
    end
    return tag
end

local function handleSetter(setter, value, root, self, percentFunc)
    local prefix = value[1]
    local rest = string.sub(value, 2)

    if prefix == "@" then
        if value[2] == "@" then
            local attrName = string.sub(rest, 2)
            root:AddChangeListener(attrName, setter)
            if root[attrName] ~= nil then
                setter(root[attrName])
            end
        else
            setter(root[rest])
        end
    elseif prefix == "&" then
        setter(rest)
    elseif prefix == "#" then
        -- Parse as Color
        local asNum = tonumber(rest, 16)
        if (#rest == 6 or #rest == 8) and asNum ~= nil then
            if #rest == 6 then asNum = asNum * 256 + 255 end
            local t = {}
            for i = 0, 3 do
                t[i+1] = bit.band(bit.rshift(asNum, (i * 8)), 0xFF)
            end
            setter(Color(t[1], t[2], t[3], t[4]))
        else
            return "Invalid color structure"
        end
    elseif prefix == "^" then
        local v = getGlobalValue(rest)
        if v ~= nil then
            setter(v)
        else
            return "Unknown global " .. rest
        end
    elseif value == "true" then
        setter(true)
    elseif value == "false" then
        setter(false)
    elseif value[#value] == "%" and tonumber(string.sub(value, 1, #value - 1)) then
        if not percentFunc then
            return "Unsupported use of %"
        end
        local n = tonumber(string.sub(value, 1, #value - 1)) / 100
        local oldLayout = self.PerformLayout or function() end
        function self:PerformLayout()
            setter(n * percentFunc())
            oldLayout(self)
        end
        --setter(n * percentFunc())
        self:InvalidateLayout(true)
    else
        -- Check if its a number, send that, else str
        local asNum = tonumber(value)
        if asNum ~= nil then
            setter(asNum)
        else
            setter(value)
        end
    end
end

function GGML.ParseSetValue(self, v)
    if type(v) == "function" then
        return helper.curry(v, self)
    end
    return v
end

local function getSetter(elem, tag, key, doSet, self)
    local setterName = "Set" .. key
    local setter = indexAllSuper(GGML.ATTR_SETTERS, tag, key)

    if setter == GGML.FORCE_SET then
        doSet = true
    end

    if isfunction(setter) then
        return true, helper.curry(setter, elem) -- Global setter
    elseif elem[setterName] then
        if doSet then
            return true, function(v) elem[setterName] = GGML.ParseSetValue(self, v) end
        else
            return true, function(v) elem[setterName](elem, v) end
        end
    elseif elem[key] then
        if doSet then
            return true, function(v) elem[key] = GGML.ParseSetValue(self, v) end
        else
            return true, function(v) elem[key](elem, v) end
        end
    else
        return false, "Couldn't resolve key"
    end
end

function GGML.CreateView(name, context, data)
    local success, xml = GGML.parseXML(data)

    if not success then
        error("Invalid XML for GGML object \"" .. name .. "\": " .. xml)
    end

    local rootKeys = table.GetKeys(xml)
    if #rootKeys ~= 1 or rootKeys[1] ~= 1 then
        error("Invalid XML for GGML object \"" .. name .. "\": Root must be singular")
    end
    local xmlRoot = xml[1]

    table.Inherit(context, GGML.ContextBase)

    local contextInit = context.Init or function() end

    function context:Init()
        if self.PreInit then self:PreInit() end

        self.xmlRoot = table.Copy(xmlRoot)
        self.changeListeners = {}

        local mt = getmetatable(self)
        local oldNewIndex = mt.__newindex
        local this = self
        local mtCopy = table.Copy(mt)
        mtCopy.__newindex = function(t, k, v)
            oldNewIndex(t, k, v)
            if this.changeListeners and this.changeListeners[k] then
                for i, f in pairs(this.changeListeners[k]) do
                    f(v)
                end
            end
        end
        debug.setmetatable(self, mtCopy) -- Debug cuz "self" is a userdata, and setmetatable no like userdata

        local err
        local success = xpcall(GGML.Inflate, function( x ) err = x end, name, self.xmlRoot, self)

        if not success then 
            self:Remove()
            error(err)
        end

        table.insert(GGML.elements, self)

        self.inflated = true

        contextInit(self)
    end

    local base = findClassName(xmlRoot.tag)

    vgui.Register(name, context, base)
end

function GGML.Inflate(name, xml, parent, root)
    local tag = GGML.TAG_ALIASES[xml.tag] or xml.tag
    local args = xml.args
    local className = findClassName(tag)

    local elem
    if root then
        elem = vgui.Create(className, parent)
    else
        root = parent
        elem = root
    end
    xml.element = elem

    for i, data in ipairs(xml.args) do
        local rawKey, value = data.key, data.value
        local key = rawKey
        local doSet = false
        if key[1] == "$" then
            key = string.sub(key, 2)
            doSet = true
        end
        key = indexAllSuper(GGML.ATTR_ALIASES, className, key) or key

        local success, setter = getSetter(elem, className, key, doSet, root)
        if not success then
            error("Invalid XML for GGML object \"" .. name .. "\": " .. setter .. " in attribute \"" .. rawKey .. "\" for tag \"" .. tag .. "\"")
        end

        if value == GGML.NO_VALUE then
            setter()
        else

            local percentFuncGetter = GGML.PERCENT_FUNCS[key]
            local percentFunc = nil
            if percentFuncGetter then
                percentFunc = percentFuncGetter(elem:GetParent() or screen)
            end

            local err = handleSetter(setter, value, root, elem, percentFunc)
            if err then
                error("Invalid XML for GGML object \"" .. name .. "\": " .. err .. " in attribute \"" .. rawKey .. "\" for tag \"" .. tag .. "\"")
            end
        end
    end

    if type(xml[1]) == "string" and not xml[2] then
        if elem.SetText then 
            elem:SetText(xml[1])
        elseif elem.SetValue then
            elem:SetValue(xml[1])
        else
            error("Invalid XML for GGML object \"" .. name .. "\": Couldn't resolve text content for tag \"" .. tag .. "\"")
        end
        xml[1] = nil
    end

    for k, v in ipairs(xml) do
        if not istable(v) then
            error("Invalid XML for GGML object \"" .. name .. "\": Text content must be singular for tag \"" .. tag .. "\"")
        end
        GGML.Inflate(name, v, elem, root)
    end
end

concommand.Add( "ggml_reload", function()
    include("ggml/client/base.lua")
end )

concommand.Add( "ggml_example", function()
    GGML.runExample()
end )

concommand.Add( "ggml_remove_all", function()
    for k, v in pairs(GGML.elements) do
        if IsValid(v) then v:Remove() end
    end
end )

