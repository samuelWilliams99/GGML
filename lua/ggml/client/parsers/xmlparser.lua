GGML.NO_VALUE = -1

-- what on earth is going on here, patterns aren't always the best way
local function parseargs( s )
    local arg = {}
    local ni1, ni2, key1, key2, j2, q, value
    local i, j = 1, 1
    while true do
        -- perhaps string.matchFirst would be good here
        ni1, j1, key1, q, value = string.find( s, "(%$?[%-%w]+)%s?=%s?([\"'])(.-)%2", i )
        ni2, j2, key2 = string.find( s, "(%$?[%-%w]+)", i )
        if not ni1 and not ni2 then break end

        if ni1 and not ni2 then
            i = j1 + 1
            table.insert( arg, { key = key1, value = value } )
        elseif ( ni2 and not ni1 ) or ni2 < ni1 then
            i = j2 + 1
            table.insert( arg, { key = key2, value = GGML.NO_VALUE } )
        else
            i = j1 + 1
            table.insert( arg, { key = key1, value = value } )
        end
    end
    return arg
end

--[[ Current output structure
{
    [1] = firstChild,
    [2] = secondChild,
    tag = tagName,
    empty = #self > 0,
    args = parseargs( argstring )
}

]]
function GGML.parseXML( s, name )
    s = string.gsub( s, "<!%-%-.-%-%->", "" )

    local stack = {}
    local top = {}
    table.insert( stack, top )
    local ni, c, tag, xarg, empty
    local i, j = 1, 1
    while true do
        ni, j, c, tag, xarg, empty = string.find( s, "<(%/?)([%w:]+)(.-)(%/?)>", i )
        if not ni then break end
        local text = string.sub( s, i, ni - 1 )
        if not string.find( text, "^%s*$" ) then
            table.insert( top, text )
        end
        if empty == "/" then  -- empty element tag
            table.insert( top, { tag = tag, args = parseargs( xarg ), empty = true } )
        elseif c == "" then   -- start tag
            top = { tag = tag, args = parseargs( xarg ) }
            table.insert( stack, top )   -- new level
        else  -- end tag
            while true do
                local toclose = table.remove( stack )  -- remove top
                top = stack[#stack]
                if #stack < 1 then
                    return false, "No open tag to close with " .. tag
                end
                local canSelfClose = GGML.TAG_SELF_CLOSE[GGML.FindClassName( toclose.tag, name )] or false
                if toclose.tag ~= tag then
                    if not canSelfClose then
                        return false, "Unable to close " .. toclose.tag .. " with " .. tag
                    else
                        table.insert( top, toclose )
                    end
                else
                    table.insert( top, toclose )
                    break
                end
            end
        end
        i = j + 1
    end
    local text = string.sub( s, i )
    if not string.find( text, "^%s*$" ) then
        table.insert( stack[#stack], text )
    end
    if #stack > 1 then
        return false, "Unclosed " .. stack[#stack].tag
    end
    return true, stack[1]
end
