GGML.FORCE_SET = "FORCE_SET"

GGML.ATTR_SETTERS = {
	All = {
		ID = function(self, val)
			self.id = val
		end,
		Left = function(self, val)
			local x, y = self:GetPos()
			self:SetPos(val, y)
		end,
		Top = function(self, val)
			local x, y = self:GetPos()
			self:SetPos(x, val)
		end
	},
	Label = {
		DoClick = GGML.FORCE_SET,
		FontSize = GGML.fontManager.GetFontSetter("size"),
		FontFamily = GGML.fontManager.GetFontSetter("font"),
		FontWeight = GGML.fontManager.GetFontSetter("weight"),
		FontDecoration = function(self, val)
			local decos = string.Split(val, " ")
			local d = {}
			for k, v in pairs(decos) do
				v = string.lower(v)
				if v == "underline" then
					d.underline = true
				elseif v == "italic" or v == "italics" then
					d.italic = true
				elseif v == "strikeout" or v == "strike-out" or v == "strikethrough" or v == "strike-through" then
					d.strikeout = true
				elseif v == "bold" then
					d.weight = 800
				end
			end
			GGML.AdjustFont(self, d)
		end
	}
}