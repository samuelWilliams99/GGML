local function height(parent)
	return helper.curry(parent.GetTall, parent)
end

local function width(parent)
	return helper.curry(parent.GetWide, parent)
end

GGML.PERCENT_FUNCS = {
	Top = height,
	Tall = height,
	Left = width,
	Wide = width,
	FontSize = height
}