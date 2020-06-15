-- This makes pairs and ipairs check metatable, as they do in Lua 5.2+
LUA_COMPAT52 = LUA_COMPAT52 or {}

local function recIndex( t, k )
    local out = t[k]
    while istable( out ) do
        out = out[k]
    end
    return out
end

local function overrideSingle( f, mtName, compatName, raw )
    LUA_COMPAT52[compatName] = LUA_COMPAT52[compatName] or f
    _G[raw] = LUA_COMPAT52[compatName]
    return function( x )
        local mt = debug.getmetatable( x )
        if mt and mt[mtName] then
            local out = recIndex( mt, mtName ) or LUA_COMPAT52[compatName]
            if isfunction( out ) then
                return out( x )
            else
                return out
            end
        else
            return LUA_COMPAT52[compatName]( x )
        end
    end
end

pairs = overrideSingle( pairs, "__pairs", "oldPairs", "rawpairs" )
ipairs = overrideSingle( ipairs, "__ipairs", "oldIPairs", "rawipairs" )
table.getn = overrideSingle( table.getn, "__len", "oldTableGetn", "rawlen" )
type = overrideSingle( type, "__type", "oldType", "rawtype" )
