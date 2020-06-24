local helper = {}
GGML.helper = helper

-- Pull out basic ops into functions
function helper.add( a, b )
    return a + b
end

function helper.sub( a, b )
    return a - b
end

function helper.mul( a, b )
    return a * b
end

function helper.div( a, b )
    return a / b
end

function helper.lAnd( a, b )
    return a and b
end

function helper.lOr( a, b )
    return a or b
end

function helper.lNot( x )
    return not x
end

function helper.eq( a, b )
    return a == b
end

function helper.nEq( a, b )
    return a ~= b
end

function helper.compose( a, b )
    return function( ... )
        return a( b( ... ) )
    end
end

function helper.rep( x, n )
    return unpack( table.rep( x, n ) )
end

function helper.curry( f, ... )
    local args = { ... }
    return function( ... ) return f( unpack( args ), ... ) end
end

function helper.unCurry( f )
    return function( a, ... ) return f( ... ) end
end

function table.mapSelf( tab, f )
    for k, v in pairs( tab ) do
        tab[k] = f( v )
    end
end

function table.map( tab, f )
    local out = table.Copy( tab )
    table.mapSelf( out, f )
    return out
end

function table.reduce( tab, f, s )
    local total = s
    for k, v in pairs( tab ) do
        total = f( total, v )
    end
    return total
end

function table.sum( tab )
    return table.reduce( tab, helper.add, 0 )
end

function table.product( tab )
    return table.reduce( tab, helper.mul, 1 )
end

-- Lazy all and any, they don't bother calling next funcs if not needed
function table.all( tab )
    return table.reduce( tab, function( a, b )
        return a and b
    end, true )
end

function table.any( tab )
    return table.reduce( tab, function( a, b )
        return a or b
    end, false )
end

function table.Repeat( x, n )
    local out = {}
    for k = 1, n do
        table.insert( out, x )
    end
    return out
end

table.rep = table.Repeat

function string.findFirst( s, ... )
    local patterns = { ... }
    local matchData
    local matchIndex = -1

    for idx, pattern in ipairs( patterns ) do
        local data = { string.find( s, pattern ) }
        if #data == 0 then continue end

        if not matchData or data[1] < matchData[1] then
            matchData = data
            matchIndex = idx
        end
    end

    return matchIndex, matchData
end

function helper.const( x )
    return function() return x end
end

function helper.getFrom( k, ... )
    return ( { ... } )[k]
end

helper.fst = helper.curry( helper.getFrom, 1 )
helper.snd = helper.curry( helper.getFrom, 2 )

function pack( ... )
    return { ... }
end

function printA( ... )
    local d = { ... }
    if #d == 0 then
        print( nil )
        return
    end
    for k, v in ipairs( d ) do
        if istable( v ) then
            PrintTable( v )
        else
            print( v )
        end
    end
end

pp = printA

function helper.indexable( x )
    local s = xpcall( function() return x[1] end, function() end )
    return s
end

local function idxValid( a, b )
    if not a then return false end
    local valid = tobool( string.match( b, "^%a%w-$" ) )
    return valid
end

function helper.index( tab, idx )
    local idxs = string.Explode( "[./]", idx, true )
    local allValid = table.reduce( idxs, idxValid, true )
    if not allValid then
        error( "Malformed index " .. idx )
    end

    local poses = {}
    local pos = tab
    for k, v in ipairs( idxs ) do
        if not helper.indexable( pos ) then return nil end
        table.insert( poses, pos )
        pos = pos[v]
    end

    return pos, poses, idxs
end

local hookCounter = 0
function hook.Once( event, f )
    hookCounter = hookCounter + 1
    local id = "HOOKONCE" .. hookCounter
    hook.Add( event, id, function( ... )
        f( ... )
        hook.Remove( event, id )
    end )
end

function helper.errInfo( str, c )
    local pre = string.sub( str, 1, c )
    local line = helper.snd( string.gsub( pre, "\n", "" ) ) + 1
    local col = c
    local nextN = string.find( str, "\n" ) - 1
    local lineStr = string.sub( str, 1, nextN )
    for k = c - 1, 1, -1 do
        if str[k] == "\n" then
            col = c - k
            local nextN = string.find( string.sub( str, c + 1 ), "\n" )
            lineStr = string.sub( str, k + 1, nextN and ( nextN + c - 1 ) or #str )
            break
        end
    end
    return "line " .. line .. ", column " .. col .. " (" .. lineStr .. ")"
end

local index = {}
function helper.getProxy( x )
    if type( x ) ~= "table" then return x end
    if ( debug.getmetatable( x ) or {} ).__IsProxy then return x end

    local newX = {}
    newX[index] = x

    local oldmt = getmetatable( x ) or {}
    local mt = {}

    for k, v in pairs( oldmt ) do
        if isfunction( v ) then
            local f_k = k
            mt[k] = function( self, ... )
                return oldmt[f_k]( self[index], ... )
            end
        else
            mt[k] = oldmt[k]
        end
    end

    mt.__index = function( t, k )
        return t[index][k]
    end

    mt.__newindex = function( t, k, v )
        t[index][k] = v
    end

    mt.__metatable = oldmt
    mt.__pairs = function( tbl )
        return pairs( tbl[index] )
    end
    mt.__ipairs = function( tbl )
        return ipairs( tbl[index] )
    end
    mt.__type = function() return type( x ) end
    mt.__IsProxy = true

    debug.setmetatable( newX, mt )
    return newX
end

function helper.splitStringSpecial( str, splitChars, surrChars )
    local surr = nil
    local t = ""
    local out = {}
    surrChars = surrChars or {}
    for k = 1, #str do
        local v = str[k]
        if not surr then
            if surrChars[v] then
                surr = v
                t = t .. v
            else
                if table.HasValue( splitChars, v ) then
                    if #t == 0 then
                        if #out == 0 then
                            table.insert( out, { str = "", split = "" } )
                        end
                        out[#out].split = out[#out].split .. v
                    else
                        table.insert( out, { str = t, split = v } )
                        t = ""
                    end
                else
                    t = t .. v
                end
            end
        else
            t = t .. v
            if v == surrChars[surr] then
                surr = nil
            end
        end
    end

    if #t > 0 then
        table.insert( out, { str = t } )
    end

    return out
end
