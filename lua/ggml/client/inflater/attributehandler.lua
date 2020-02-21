function GGML.inflater.handleField(setter, hasGetter, getter, value, root, self)
    local prefix = value[1]
    local rest = string.sub(value, 2)
    if prefix == "@" then
        -- Property = on context
        -- field = on element
        local match = false
        if value[2] == "<" or value[2] == "=" then
            -- property -> element
            match = true
            local attrName = string.sub(rest, 2)
            local v = helper.index(root, attrName)
            root:AddChangeListener(attrName, setter)
            if v then
                setter(v)
            end
        end
        if value[2] == ">" or value[2] == "=" then
            -- element -> property
            if hasGetter then
                match = true
                local attrName = string.sub(rest, 2)
                root:MakeGetter(attrName, getter)
            else
                return "Could not backwards/2-way bind, " .. getter
            end
        end
        if not match then
            local v = helper.index(root, rest)
            setter(v)
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

function GGML.inflater.parseSetValue(self, v)
    if type(v) == "function" then
        return helper.curry(v, self)
    end
    return v
end

function GGML.inflater.getSetter(elem, tag, key, doSet, self)
    local setterName = "Set" .. key
    local setter = GGML.inflater.indexAllSuper(GGML.ATTR_SETTERS, tag, key)

    if setter == GGML.FORCE_SET then
        doSet = true
    end

    if isfunction(setter) then
        return true, helper.curry(setter, elem) -- Global setter
    elseif elem[setterName] then
        if doSet then
            return true, function(v) elem[setterName] = GGML.inflater.parseSetValue(self, v) end
        else
            return true, function(v) elem[setterName](elem, v) end
        end
    elseif elem[key] then
        if doSet then
            return true, function(v) elem[key] = GGML.inflater.parseSetValue(self, v) end
        else
            return true, function(v) elem[key](elem, v) end
        end
    else
        return false, "Couldn't resolve key"
    end
end

function GGML.inflater.getGetter(elem, tag, key, self)
    local getterName = "Get" .. key
    local getter = GGML.inflater.indexAllSuper(GGML.ATTR_GETTERS, tag, key)

    if isfunction(getter) then
        return true, helper.curry(getter, elem) -- Global setter
    elseif elem[getterName] then
        return true, function() elem[getterName](elem) end
    elseif elem[key] then
        return true, function() elem[key](elem) end
    else
        return false, "Couldn't resolve key"
    end
end