GGML.NO_VALUE = -1

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
        local argValue = string.match( s, "^[%w_%-]+" )
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

            if isWhiteSpace( char ) then
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
            return false, tagType .. " at " .. GGML.helper.errInfo( inputString, args )
        end

        local oldS = s
        s = newStr

        if tagType == "open" or tagType == "standAlone" then
            local empty = tagType == "standAlone"
            local tag = { tag = tagName, args = args, empty = empty, children = {}, XMLPos = inputLength - #oldS }

            if #stack > 0 then
                table.insert( stack[#stack].children, tag )
            end

            if GGML.TAG_SELF_CLOSE[GGML.FindClassName( tagName, name )] then
                empty = true
            end

            if not empty then
                table.insert( stack, tag )
            end
        elseif tagType == "close" then
            local toClose = table.remove( stack )  -- remove top

            if #stack < 1 then
                local posStr = GGML.helper.errInfo( inputString, inputLength - #s )
                return false, "No open tag to close with " .. tagName .. " at " .. posStr
            end

            if toClose.tag ~= tagName then
                local posStr = GGML.helper.errInfo( inputString, inputLength - #s )
                return false, "Unable to close " .. toClose.tag .. " with " .. tagName .. " at " .. posStr
            end
        elseif tagType == "text" then
            table.insert( stack[#stack].children, tagName )
        end
    end

    if #stack > 1 then
        local posStr = GGML.helper.errInfo( inputString, stack[#stack].XMLPos )
        return false, "Unclosed " .. stack[#stack].tag .. " at " .. posStr
    end

    return true, stack[1]
end
