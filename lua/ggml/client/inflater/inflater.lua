GGML.inflater = {}

include( "attributehandler.lua" )

GGML.inflater.getGlobalValue = GGML.helper.curry( GGML.helper.index, _G )

function GGML.inflater.indexAllSuper( tab, tag, key )
    if tab.All and tab.All[key] then
        return tab.All[key]
    end
    while true do
        local t = vgui.GetControlTable( tag )
        if not t then break end

        if tag[1] == "D" then
            local newTag = string.sub( tag, 2 )
            if tab[newTag] and tab[newTag][key] then
                return tab[newTag][key]
            end
        end

        if tab[tag] and tab[tag][key] then
            return tab[tag][key]
        end
        if tag == t.Base then return nil end -- Recursive table, aka t.Base = t, very illegal >:(
        tag = t.Base
    end
    return nil
end

function GGML.FindClassName( tag, name )
    tag = GGML.TAG_ALIASES[tag] or tag
    if not vgui.GetControlTable( tag ) then
        if not vgui.GetControlTable( "D" .. tag ) then
            error( "Invalid XML for GGML object \"" .. name .. "\": Couldn't resolve tag \"" .. tag .. "\"" )
        else
            return "D" .. tag
        end
    end
    return tag
end

function GGML.Inflate( name, xml, parent, root )
    local tag = xml.tag
    local args = xml.args
    local className = GGML.FindClassName( tag )

    local elem
    if root then
        elem = vgui.Create( className, parent )
    else
        root = parent
        elem = root
    end
    xml.element = elem

    for i, data in ipairs( xml.args ) do
        local rawKey, value = data.key, data.value
        local key = rawKey
        local doSet = false
        if key[1] == "$" then
            key = string.sub( key, 2 )
            doSet = true
        end
        key = GGML.inflater.indexAllSuper( GGML.ATTR_ALIASES, className, key ) or key

        local setterSuccess, setter = GGML.inflater.getSetter( elem, className, key, doSet, root )
        if not setterSuccess then
            error( "Invalid XML for GGML object \"" .. name .. "\": " .. setter .. " in attribute \"" .. rawKey .. "\" for tag \"" .. tag .. "\"" )
        end

        local getterSuccess, getter = GGML.inflater.getGetter( elem, className, key, root )

        if value == GGML.NO_VALUE then
            setter()
        else
            -- Pass in getter success as it is allowed to fail if not needed by handleField
            local err = GGML.inflater.handleField( setter, getterSuccess, getter, value, root, elem )
            if err then
                error( "Invalid XML for GGML object \"" .. name .. "\": " .. err .. " in attribute \"" .. rawKey .. "\" for tag \"" .. tag .. "\"" )
            end
        end
    end

    if type( xml[1] ) == "string" and not xml[2] then
        if elem.SetText then
            elem:SetText( xml[1] )
        elseif elem.SetValue then
            elem:SetValue( xml[1] )
        else
            error( "Invalid XML for GGML object \"" .. name .. "\": Couldn't resolve text content for tag \"" .. tag .. "\"" )
        end
        xml[1] = nil
    end

    for k, v in ipairs( xml ) do
        if not istable( v ) then
            error( "Invalid XML for GGML object \"" .. name .. "\": Text content must be singular for tag \"" .. tag .. "\"" )
        end
        GGML.Inflate( name, v, elem, root )
    end
end
