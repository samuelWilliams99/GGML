local function h(parent)
	return parent:GetTall()
end

local function w(parent)
	return parent:GetWide()
end

local function wh(parent)
	return parent:GetSize()
end


GGML.PERCENTABLE = {
	All = {
		SetPos = wh,
		SetSize = wh
	},
	DLabel = {
		SetFontSize = h
	}
}
GGML.VGUI_ADDITIONS = {}
GGML.VGUI_ADDITIONS.OVERRIDES = {
	All = {
		SetWide = function(self, x)
			if self._GGMLMults and self._GGMLMults.SetSize then
				self._GGMLMults.SetSize[1] = x
				self:InvalidateLayout(true)
			else
				local _x, y = self:GetSize()
				self:SetSize(x, y)
			end
		end,
		SetTall = function(self, y)
			if self._GGMLMults and self._GGMLMults.SetSize then
				self._GGMLMults.SetSize[2] = y
				self:InvalidateLayout(true)
			else
				local x, _y = self:GetSize()
				self:SetSize(x, y)
			end
		end,
		SetBorderRadius = function(self, r)
			self:SetBorderRadii(r, r, r, r)
		end,
		GetBorderRadius = function(self)
			local r = self:GetBorderRadii()
			return r
		end
	},
	DLabel = {
		
	},
	DPanel = {

	},
	DFrame = {

	}
}
GGML.VGUI_ADDITIONS.FIELDS = {
	All = {
		Left = {
			Set = function(self, x)
				if self._GGMLMults and self._GGMLMults.SetPos then
					self._GGMLMults.SetPos[1] = x
					self:InvalidateLayout(true)
				else
					local _x, y = self:GetPos()
					self:SetPos(x, y)
				end
			end,
			Get = function(self)
				local x, y = self:GetPos()
				return x
			end
		},
		Top = {
			Set = function(self, y)
				if self._GGMLMults and self._GGMLMults.SetPos then
					self._GGMLMults.SetPos[2] = y
					self:InvalidateLayout(true)
				else
					local x, _y = self:GetPos()
					self:SetPos(x, y)
				end
			end,
			Get = function(self)
				local x, y = self:GetPos()
				return y
			end
		},
		GGMLBackgroundColor = {
			Set = GGML.paintManager.GetPaintSetter("bgColor"),
			Default = Color(0,0,0,0)
		},
		BackgroundTexture = {
			Set = GGML.paintManager.GetPaintSetter("bgTexture"),
		},
		BorderWidth = {
			Set = GGML.paintManager.GetPaintSetter("borderWidth"),
			Default = 0
		},
		BorderColor = {
			Set = GGML.paintManager.GetPaintSetter("borderColor"),
			Default = 0
		},
		BorderRadii = {
			Set = GGML.paintManager.GetPaintSetter("borderRadii"),
			Default = 0
		},
		BorderSides = {
			Set = GGML.paintManager.GetPaintSetter("borderSides")
		}
	},
	DLabel = {
		FontSize = {
			Set = GGML.fontManager.GetFontSetter("size"),
			Default = GGML.fontManager.defaultFont.size
		},
		FontFamily = {
			Set = GGML.fontManager.GetFontSetter("font"),
			Default = GGML.fontManager.defaultFont.font
		},
		FontWeight = {
			Set = GGML.fontManager.GetFontSetter("weight"),
			Default = GGML.fontManager.defaultFont.weight
		},
		FontDecoration = {
			Set = function(self, val)
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
			end,
			Get = function(self)
				local data = GGML.fontManager.GetFontData(self)
				local out = ""
				if data.underline then
					out = out .. "underline "
				end
				if data.italic then
					out = out .. "italic "
				end
				if data.strikeout then
					out = out .. "strikeout "
				end
				if out[#out] == " " then
					out = string.sub(out, 1, #out-1)
				end
				return out
			end
		}
	},
	DPanel = {

	},
	DFrame = {
		
	}
}