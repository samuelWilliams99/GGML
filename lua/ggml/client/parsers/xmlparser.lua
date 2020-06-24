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

-- the rewrite

local function isWhiteSpace( c )
    return c == " " or c == "\t" or c == "\n" or c == "\r"
end

-- return argName, argValue, rest
-- if error, return nil, errMsg, pos
local function getNextArgument( s, inputLength )
    local argName = string.match( s, "^([%$]?[%w_%-]+)" )

    if not argName then
        return nil, "Malformed argument name", inputLength - #s
    end

    s = string.sub( s, #argName + 1 )

    local equals = string.match( s, "^[%s\n]*=[%s\n]*" )
    if not equals then
        return argName, GGML.NO_VALUE, s
    end

    s = string.sub( s, #equals + 1 )

    local quote = s[1]
    if quote ~= "\"" and quote ~= "'" then
        local argValue = string.match( s, "^%S+" )
        return argName, argValue, string.sub( s, #argValue + 1 )
    end

    local k = 1
    local argValue = ""
    while k < #s do
        k = k + 1
        if s[k] == "\\" then
            k = k + 1
        elseif s[k] == quote then
            return argName, argValue, string.sub( s, k + 1 )
        end
        argValue = argValue .. s[k]
    end

    return nil, "Unclosed quotes", inputLength - #s
end

-- return tagName, tagType (open, close, standAlone, text (tagName=text), comment (tagName=comment)), args (or nil), newStr
-- if error, return nil, errMsg, pos
local function getNextTag( s, inputLength )
    if s[1] ~= "<" then
        local text = ""

        local k = 0
        while k < #s do
            k = k + 1
            if s[k] == "/" and s[k + 1] == "<" then
                k = k + 1
            elseif s[k] == "<" then
                break
            end
            text = text .. s[k]
        end

        return text, "text", nil, string.sub( s, #text + 1 )
    elseif string.sub( s, 2, 4 ) == "!--" then
        local startPos, endPos = string.find( s, "-->", 4, true )
        local comment = string.sub( s, 5, startPos - 1 )

        return comment, "comment", nil, string.sub( s, endPos + 1 )
    else
        local tagName = string.match( s, "^</?([%w_%-]+)" )

        if not tagName then return nil, "Malformed tag", inputLength - #s end

        local close = s[2] == "/"

        local rest = string.sub( s, #tagName + ( close and 3 or 2 ) )

        if close then
            rest = string.TrimLeft( rest )
            if rest[1] ~= ">" then
                return nil, "Closing tags cannot contain arguments", inputLength - #rest
            end

            return tagName, "close", nil, string.sub( rest, 2 )
        end

        local tagType = "open"
        local args = {}
        while #rest > 0 do
            local char = rest[1]

            if char == ">" then
                rest = string.sub( rest, 2 )
                break
            end

            if char == "/" and rest[2] == ">" then
                tagType = "standAlone"
                rest = string.sub( rest, 3 )
                break
            end

            if char == " " or char == "\t" or char == "\n" then
                rest = string.sub( rest, 2 )
                continue
            end

            local argName, argValue, newRest = getNextArgument( rest, inputLength )

            if not argName then
                local err = argValue
                local pos = newRest
                return nil, err, pos
            end
            rest = newRest

            table.insert( args, { key = argName, value = argValue } )
        end

        return tagName, tagType, args, rest
    end
end

function GGML.parseXML( s, name )
    local stack = {{ children = {} }}
    local inputString = s
    local inputLength = #inputString

    while #s > 0 do
        local char = s[1]
        if isWhiteSpace( char ) then
            s = string.sub( s, 2 )
            continue
        end

        local tagName, tagType, args, newStr = getNextTag( s, inputLength )

        if not tagName then
            local err = tagType
            local pos, pointer = GGML.helper.errInfo( inputString, args )
            local pre = err .. " at "
            pointer = string.rep( " ", #pre ) .. pointer
            return false, pre .. pos .. "\n" .. pointer
        end

        s = newStr

        if tagType == "open" or tagType == "standAlone" then
            local empty = tagType == "standAlone"
            local tag = { tag = tagName, args = args, empty = empty, children = {} }

            if #stack > 0 then
                table.insert( stack[#stack].children, tag )
            end

            if not empty then
                table.insert( stack, tag )
            end
        elseif tagType == "close" then
            while true do
                local toClose = table.remove( stack )  -- remove top

                if #stack < 1 then
                    return false, "No open tag to close with " .. tagName
                end

                local canSelfClose = GGML.TAG_SELF_CLOSE[GGML.FindClassName( toClose.tag, name )] or false

                if toClose.tag == tagName then break end

                if not canSelfClose then
                    return false, "Unable to close " .. toClose.tag .. " with " .. tagName
                end
            end
        elseif tagType == "text" then
            table.insert( stack[#stack].children, tagName )
        end
    end

    if #stack > 1 then
        return false, "Unclosed " .. stack[#stack].tag
    end
    return true, stack[1]
end
