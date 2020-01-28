GGML.fontManager = GGML.fontManager or {
	counter = 0,
	fontPool = {},
	existingFonts = {}
}

local function getDefaultFont()
	if system.IsLinux() then
		return {
			font		= "DejaVu Sans",
			size		= 14,
			weight		= 500
		}
	else
		return {
			font		= "Tahoma",
			size		= 13,
			weight		= 500
		}
	end
end

GGML.fontManager.defaultFont = getDefaultFont()

local function getFontName()
	if #GGML.fontManager.fontPool == 0 then
		local fontName = "GGML_Generated_Font_" .. GGML.fontManager.counter
		GGML.fontManager.counter = GGML.fontManager.counter + 1
		return fontName
	else
		return table.remove(GGML.fontManager.fontPool)
	end
end

function GGML.fontManager.GetFontSetter(attr)
	return function(self, value)
		local d = {}
		d[attr] = value
		GGML.AdjustFont(self, d)
	end
end

function GGML.AdjustFont(elem, data)
	local fontData
	local fontName
	if elem.UsingGGMLFont then
		elem.SetFont = elem.oldSetFont
		elem.OnRemove = elem.oldOnRemove
		fontName = elem:GetFont()
		fontData = GGML.fontManager.existingFonts[fontName]
	else
		fontName = getFontName()
		fontData = table.Copy(GGML.fontManager.defaultFont)
	end

	elem.UsingGGMLFont = true

	table.Merge(fontData, data)
	GGML.fontManager.existingFonts[fontName] = fontData

	surface.CreateFont(fontName, fontData)

	elem:SetFont(fontName)

	elem.oldSetFont = elem.SetFont
	function elem:SetFont(font)
		table.insert(GGML.fontManager.fontPool, self:GetFont())
		self.SetFont = self.oldSetFont
		self.OnRemove = self.oldOnRemove
		self.UsingGGMLFont = false
		self:SetFont(font)
	end
	elem.oldOnRemove = elem.OnRemove or function() end
	function elem:OnRemove()
		table.insert(GGML.fontManager.fontPool, self:GetFont())
		self.SetFont = self.oldSetFont
		self.OnRemove = self.oldOnRemove
		self.UsingGGMLFont = false
		self:OnRemove()
	end
end