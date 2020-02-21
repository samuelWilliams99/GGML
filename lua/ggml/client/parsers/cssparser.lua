GGML.css = {}
local css = GGML.css

css.attributeOpLookup = {
	["="]  = helper.eq,
	["~="] = function(a, b)
		return asBool(string.find(" " .. a .. " ", "%s" .. string.PatternSafe(b) .. "%s"))
	end,
	["|="] = function(a, b)
		return a == b or string.sub(a, 1, #b + 1) == b .. "-"
	end,
	["^="] = function(a, b)
		return string.sub(a, 1, #b) == b
	end,
	["$="] = function(a, b)
		return string.sub(a, #a - #b + 1) == b
	end,
	["*="] = function(a, b)
		return asBool(string.find(a, b, 1, true))
	end,
	["CLASSCHECK"] = function(a, classes)
		return table.all(table.map(classes, function(class)
			return css.attributeOpLookup["~="](a, class)
		end))
	end,
	["NOTNIL"] = function(a)
		return a ~= nil
	end
}

css.contextFreeFunctions = {
    hsl = function(args) 
        table.insert(args, {{num=1, type="Value"}})
        return css.contextFreeFunctions.hsla(args)
    end,
    hsla = function(args)
        p(args)
        local valid = #args == 4 and
            #args[1] == 1 and args[1][1].type == "Value" and args[1][1].num >= 0 and args[1][1].num <= 360 and
            #args[2] == 1 and args[2][1].type == "UnitValue" and args[2][1].unit == "%" and
            #args[3] == 1 and args[3][1].type == "UnitValue" and args[3][1].unit == "%" and
            #args[4] == 1 and args[4][1].type == "Value" and args[4][1].num >= 0 and args[4][1].num <= 1

        if not valid then error("Invalid arguments to hsla()") end

        local h = args[1][1].num
        local s = args[2][1].num
        local l = args[3][1].num
        local col = HSLToColor(h, s/100, l/100)

        args[1][1] = {num=col.r, type="Value"}
        args[2][1] = {num=col.g, type="Value"}
        args[3][1] = {num=col.b, type="Value"}
        args[4][1].num = args[4][1].num * 255

        return css.contextFreeFunctions.rgba(args)
    end,
    rgb = function(args)
        table.insert(args, {{num=255, type="Value"}})
        return css.contextFreeFunctions.rgba(args)
    end,
    rgba = function(args)
        local valid = #args == 4 and table.reduce(args, function(a, b)
            if not a then return false end
            return #b == 1 and b[1].type == "Value" and b[1].num >= 0 and b[1].num <= 255
        end, true)
        if not valid then error("Invalid arguments to rgb()") end
        local r = args[1][1].num
        local g = args[2][1].num
        local b = args[3][1].num
        local a = args[4][1].num
        return {text=string.format("#%02X%02X%02X%02X", r, g, b, a), type="String"}
    end,
    var = function(args)
        local valid = #args == 1 and #args[1] == 1 and args[1][1].type == "String"
        if not valid then error("Invalid argument to var()") end

        -- Lookup in root tag, can't really be done here without more info :(

        return {text="VAR", type="String"}
    end
}

local function parseSelectorExp(str)
	if #str == 0 then error("Malformed selector, selectors cannot be empty") end
	local entry = {attributes = {}}
	local brPos = string.find(str, "[", 1, true)
	local pre = str
	local post
	if brPos then
		pre = string.sub(str, 1, brPos-1)
		post = string.sub(str, brPos)
	end
	local s, e = string.find(pre, "^[%w%-_%*]+")
	if s then
		entry.tag = string.sub(pre, s, e)
		if string.find(entry.tag, "*", 1, true) and entry.tag ~= "*" then
			error("Malformed selector, * can only be used alone")
		end
		pre = string.sub(pre, e+1)
	else
		entry.tag = "*"
	end

	local classList = {}
	local noClasses = string.gsub(pre, "%.([%w%-_]+)", function(class)
		table.insert(classList, class)
		return ""
	end)
	if #classList > 0 then
		entry.attributes.class = {
			func = "CLASSCHECK", 
			val = classList
		}
	end

	local id
	local nothing = string.gsub(noClasses, "#([%w%-_]+)", function(_id)
		if id then
			error("Malformed selector, cannot define mutiple ID matches")
		end
		id = _id
		return ""
	end)
	if id then
		entry.attributes.id = {
			func = "=", 
			val = id
		}
	end

	-- At this point, nothing should be an empty string, all cases matched
	-- If not, the label was malformed
	if #nothing ~= 0 then
		error("Malformed selector, failed to parse \"" .. nothing .. "\"")
	end

	if post then
		local noAssigns = string.gsub(post, "%[([%w%-_]+)%]", function(attr)
			entry.attributes[attr] = {
				func = "NOTNIL"
			}
			return ""
		end)

		local nothing = string.gsub(noAssigns, "%[%s*([%w%-_]+)%s*([~|%^%$%*]?=)%s*([\"']?)([^%]]+)%3%s*%]", function(attr, op, _, val)
			entry.attributes[attr] = {
				func = op, 
				val = val
			}
			return ""
		end)
		-- At this point, nothing should be an empty string, all cases matched
		-- If not, the label was malformed
		if #nothing ~= 0 then
			error("Malformed selector, failed to parse attributes \"" .. nothing .. "\"")
		end
	end
	return entry
end

local function parseLabels(str)
	str = string.Trim(str)
	local labels = string.Explode("[%s\n]*,[%s\n]*", str, true)
	local out = {}
	for _, label in pairs(labels) do
		local selectors = helper.splitStringSpecial(label, {" ", ">", "+", "~"}, {
			["["] = "]",
			["\""] = "\"",
			["'"] = "'",
			["("] = ")"
		})

		local selectorOut = {}
		for i = #selectors, 1, -1 do
			local selector = selectors[i]
			local op = selector.split or ""
			op = string.Trim(op)
			if #op == 0 then op = " " end
			local entry = parseSelectorExp(selector.str)

			if op == " " then
				entry.immediate = false
			elseif op == ">" then
				entry.immediate = true
			else
				error("Operator " .. op .. " not yet supported :(")
			end

			table.insert(selectorOut, entry)

		end

		table.insert(out, selectorOut)
	end
	return out
end

local function attemptResolveFunction(data)
    local fn = data.funcName
    if css.contextFreeFunctions[fn] then
        return css.contextFreeFunctions[fn](data.args)
    else
        return data
    end
end

local function parseAttributeValue(value)
    local valueSplit = helper.splitStringSpecial(value, {" ", ","}, {
        ["\""] = "\"",
        ["'"] = "'",
        ["("] = ")"
    })
    local out = {{}}
    for k, singleData in ipairs(valueSplit) do
        local str = string.Trim(singleData.str)
        if str == "" then continue end
        local sep = string.Trim(singleData.split or "")
        local cur
        -- Is it a function call?
        local s, _, funcName, args = string.find(str, "^([%w%-]+)%(([^%)]+)%)$")
        if s then
            -- Yes
            cur = {
                funcName = funcName,
                args = parseAttributeValue(args),
                type = "FunctionCall"
            }

            cur = attemptResolveFunction(cur)
        end

        if not cur then
            -- Is it a value with unit (10% or 30px)
            local s, _, num, unit = string.find(str, "^([%d%.]+)([%a%%]+)$")
            if s then
                -- Maybe, is the num ok?
                num = tonumber(num)
                if num then
                    -- Yes
                    if unit == "%" and (num < 0 or num > 100) then
                        error("% value out of range 0-100")
                    end
                    cur = {
                        num = num,
                        unit = unit,
                        type = "UnitValue"
                    }
                end
            end
        end

        if not cur then
            local num = tonumber(str)

            if num then
                cur = {
                    num = num,
                    type = "Value"
                }
            end
        end

        cur = cur or {
            text = str,
            type = "String"
        }

        table.insert(out[#out], cur)

        if sep == "," then
            table.insert(out, {})
        end
    end
    return out
end

local function parseAttributes(attrs)
    local out = {}
    local attrsSplit = helper.splitStringSpecial(attrs, {";"}, {
        ["\""] = "\"",
        ["'"] = "'",
        ["("] = ")"
    })
    table.mapSelf(attrsSplit, function(x) return string.Trim(x.str) end)

    for k, pair in ipairs(attrsSplit) do
        if pair == "" then continue end
        local s, _, property, value = string.find(pair, "^([%w_%-]+)%s*:%s*(.+)")
        if not s then
            error("Malformed css")
        end
        local valueTable = parseAttributeValue(value)
        out[property] = valueTable
    end

    return out
end

function GGML.parseCSS(str)
	str = string.gsub(str, "/%*.-%*/", "")

    local out = {}

	local s, e, ne, labels, attributes
	e = 0
	while true do
		s, ne, labelsStr, attributesStr = string.find(str, "[%s\n]*([%w%s,:%*%.#=~|%^%$]+){[%s/n]*([^}]+)[%s/n]*}[%s\n]*", e+1)
		if not s then 
			if e == #str then
				break
			else
				return false, "Invalid format at " .. helper.errInfo(str, e)
			end
		end
		if s ~= e + 1 then
			return false, "Invalid format at " .. helper.errInfo(str, s)
		end
		e = ne
		local labels = parseLabels(labelsStr)
		local attributes = parseAttributes(attributesStr)
		for k, v in pairs(labels) do
            out[v] = attributes
        end
	end
    p(out)
	return true, out
end


--[[

/* Variables
/* ---------------------------------------------------------- */

:root {
    /* Colours */
    --dark-blue: #002ead;
    --theme-color: #0a0a23;
    --gray90: #0a0a23;
    --gray85: #1b1b32;
    --gray80: #2a2a40;
    --gray75: #3b3b4f;
    --gray15: #d0d0d5;
    --gray10: #dfdfe2;
    --gray05: #eeeef0;
    --gray00: #fff;
    --header-height: 38px;
}

/* Fonts
/*------------------------------------------------------------*/
/*@import url("https://fonts.googleapis.com/css?family=Lato:400,400i,700|Roboto+Mono:400,700");*/

/* Reset
/* ---------------------------------------------------------- */

html,
body,
div,
span,
applet,
object,
iframe,
h1,
h2,
h3,
h4,
h5,
h6,
p,
blockquote,
pre,
a,
abbr,
acronym,
address,
big,
cite,
code,
del,
dfn,
em,
img,
ins,
kbd,
q,
s,
samp,
small,
strike,
strong,
sub,
sup,
tt,
var,
dl,
dt,
dd,
ol,
ul,
li,
fieldset,
form,
label,
legend,
table,
caption,
tbody,
tfoot,
thead,
tr,
th,
td,
article,
aside,
canvas,
details,
embed,
figure,
figcaption,
footer,
header,
hgroup,
menu,
nav,
output,
ruby,
section,
summary,
time,
mark,
audio,
video {
    margin: 0;
    padding: 0;
    border: 0;
    font: inherit;
    font-size: 100%;
    vertical-align: baseline;
}
body {
    line-height: 1;
}
ol,
ul {
    list-style: none;
}
blockquote,
q {
    quotes: none;
}
blockquote:before,
blockquote:after,
q:before,
q:after {
    content: "";
    content: none;
}
table {
    border-spacing: 0;
    border-collapse: collapse;
}
img {
    max-width: 100%;
}
html {
    box-sizing: border-box;
    font-family: "Lato", sans-serif;

    -ms-text-size-adjust: 100%;
    -webkit-text-size-adjust: 100%;
}
*,
*:before,
*:after {
    box-sizing: inherit;
}
a {
    background-color: transparent;
}
a:active,
a:hover {
    outline: 0;
}
b,
strong {
    font-weight: bold;
}
i,
em,
dfn {
    font-style: italic;
}
h1 {
    margin: 0.67em 0;
    font-size: 2em;
}
small {
    font-size: 80%;
}
sub,
sup {
    position: relative;
    font-size: 75%;
    line-height: 0;
    vertical-align: baseline;
}
sup {
    top: -0.5em;
}
sub {
    bottom: -0.25em;
}
img {
    border: 0;
}
svg:not(:root) {
    overflow: hidden;
}
mark {
    background-color: #fdffb6;
}
code,
kbd,
pre,
samp {
    font-family: "Roboto Mono", monospace;
    font-size: 1em;
}
button,
input,
optgroup,
select,
textarea {
    margin: 0; /* 3 */
    color: inherit; /* 1 */
    font: inherit; /* 2 */
}
button {
    overflow: visible;
    border: none;
}
button,
select {
    text-transform: none;
}
button,
html input[type="button"],
/* 1 */
input[type="reset"],
input[type="submit"] {
    cursor: pointer; /* 3 */

    -webkit-appearance: button; /* 2 */
}
button[disabled],
html input[disabled] {
    cursor: default;
}
button::-moz-focus-inner,
input::-moz-focus-inner {
    padding: 0;
    border: 0;
}
input {
    line-height: normal;
}
input:focus {
    outline: none;
}
input[type="checkbox"],
input[type="radio"] {
    box-sizing: border-box; /* 1 */
    padding: 0; /* 2 */
}
input[type="number"]::-webkit-inner-spin-button,
input[type="number"]::-webkit-outer-spin-button {
    height: auto;
}
input[type="search"] {
    box-sizing: content-box; /* 2 */

    -webkit-appearance: textfield; /* 1 */
}
input[type="search"]::-webkit-search-cancel-button,
input[type="search"]::-webkit-search-decoration {
    -webkit-appearance: none;
}
legend {
    padding: 0; /* 2 */
    border: 0; /* 1 */
}
textarea {
    overflow: auto;
}
table {
    border-spacing: 0;
    border-collapse: collapse;
}
td,
th {
    padding: 0;
}

/* ==========================================================================
   Base styles: opinionated defaults
   ========================================================================== */

html {
    overflow-x: hidden;
    overflow-y: scroll;
    font-size: 62.5%;

    -webkit-tap-highlight-color: rgba(0, 0, 0, 0);
}
body {
    overflow-x: hidden;
    color: var(--gray90);
    font-family: "Lato", sans-serif;
    font-size: 1.5rem;
    line-height: 1.6em;
    font-weight: 400;
    font-style: normal;
    letter-spacing: 0;
    text-rendering: optimizeLegibility;
    background: #fff;

    -webkit-font-smoothing: antialiased;
    -moz-osx-font-smoothing: grayscale;
    -moz-font-feature-settings: "liga" on;
    font-feature-settings: "liga1" on;
}

::selection {
    text-shadow: none;
    background: var(--dark-blue);
    color: var(--gray00);
}

hr {
    position: relative;
    display: block;
    width: 100%;
    margin: 2.5em 0 3.5em;
    padding: 0;
    height: 1px;
    border: 0;
    border-top: 1px solid var(--gray75);
}

audio,
canvas,
iframe,
img,
svg,
video {
    vertical-align: middle;
}

fieldset {
    margin: 0;
    padding: 0;
    border: 0;
}

textarea {
    resize: vertical;
}

p,
ul,
ol,
dl,
blockquote {
    margin: 0 0 1.5em 0;
}

ol,
ul {
    padding-left: 1.3em;
    padding-right: 1.5em;
}

ol ol,
ul ul,
ul ol,
ol ul {
    margin: 0.5em 0 1em;
}

ul {
    list-style: disc;
}

ol {
    list-style: decimal;
}

ul,
ol {
    max-width: 100%;
}

li {
    margin: 0.5em 0;
    padding-left: 0.3em;
    line-height: 1.6em;
}

dt {
    float: left;
    margin: 0 20px 0 0;
    width: 120px;
    color: var(--gray90);
    font-weight: 500;
    text-align: right;
}

dd {
    margin: 0 0 5px 0;
    text-align: left;
}

blockquote {
    margin: 1.5em 0;
    padding: 0 1.6em 0 1.6em;
    border-left: var(--gray10) 0.5em solid;
}

blockquote p {
    margin: 0.8em 0;
    font-size: 1.2em;
    font-weight: 300;
}

blockquote small {
    display: inline-block;
    margin: 0.8em 0 0.8em 1.5em;
    font-size: 0.9em;
    opacity: 0.8;
}
/* Quotation marks */
blockquote small:before {
    content: "\2014 \00A0";
}

blockquote cite {
    font-weight: bold;
}
blockquote cite a {
    font-weight: normal;
}

a {
    color: var(--dark-blue);
    text-decoration: none;
    cursor: pointer;
}

a:hover {
    text-decoration: underline;
}

h1,
h2,
h3,
h4,
h5,
h6 {
    margin-top: 0;
    line-height: 1.15;
    font-weight: 700;
    text-rendering: optimizeLegibility;
}

h1 {
    margin: 0 0 0.5em 0;
    font-size: 5rem;
    font-weight: 700;
}
@media (max-width: 500px) {
    h1 {
        font-size: 2.2rem;
    }
}

h2 {
    margin: 1.5em 0 0.5em 0;
    font-size: 2rem;
}
@media (max-width: 500px) {
    h2 {
        font-size: 1.8rem;
    }
}

h3 {
    margin: 1.5em 0 0.5em 0;
    font-size: 1.8rem;
    font-weight: 500;
}
@media (max-width: 500px) {
    h3 {
        font-size: 1.7rem;
    }
}

h4 {
    margin: 1.5em 0 0.5em 0;
    font-size: 1.6rem;
    font-weight: 500;
}

h5 {
    margin: 1.5em 0 0.5em 0;
    font-size: 1.4rem;
    font-weight: 500;
}

h6 {
    margin: 1.5em 0 0.5em 0;
    font-size: 1.4rem;
    font-weight: 500;
}



]]