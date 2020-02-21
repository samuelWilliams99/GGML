GGML.paintManager = GGML.paintManager or {}
GGML.paintManager.default = {
	background = Color(255, 255, 255),
	backgroundType = "Color",
	border = {
		radii = {0, 0, 0, 0},
		width = 0,
		color = Color(255, 255, 255),
		sides = {true, true, true, true}
	}
}

local function addSegment(poly, centX, centY, radius, startAngle, w, h, borderW)
	radius = math.min( math.Round( radius ), math.floor( w / 2 ) )
	local segs = math.Clamp(radius, 4, 30)
	local start = #poly + 1
	for k = 0, segs do
		local ang = math.rad(startAngle + (k/segs) * 90)
		local bRadius = radius - borderW / 2
		local x = centX + math.sin( ang ) * bRadius
		local y = centY - math.cos( ang ) * bRadius
		table.insert( poly, { x = x, y = y, u = x/w, v = y/h} )
	end
	return start, #poly
end

local double = function(x) return helper.rep(x, 2) end

-- This function is really gross, please don't judge me :(
local function generatePolygons(w, h, borderW, sides, tl, tr, br, bl)
	local poly = {}
	local indexes = {}
	local s
	local cornerStart, cornerEnd
	-- Make corner one
	if tl > 0 then
		cornerStart, cornerEnd = addSegment(poly, tl, tl, tl, -90, w, h, borderW)
	else
		cornerStart, cornerEnd = double(table.insert(poly, {x = borderW/2, y = borderW/2, u=0, v=0}))
	end
	-- Add border indices
	if sides[1] and sides[4] then
		s = cornerStart
	elseif sides[1] and not sides[4] then
		s = cornerEnd
	end
	-- corner two
	if tr > 0 then
		cornerStart, cornerEnd = addSegment(poly, w-tr, tr, tr, 0, w, h, borderW)
	else
		cornerStart, cornerEnd = double(table.insert(poly, {x = w - borderW/2, y = borderW/2, u=1, v=0}))
	end

	if sides[2] and not s then
		s = cornerEnd
	elseif not sides[2] and s then
		table.insert(indexes, {s, cornerStart})
		s = nil
	end
	-- corner three
	if br > 0 then
		cornerStart, cornerEnd = addSegment(poly, w-br, h-br, br, 90, w, h, borderW)
	else
		cornerStart, cornerEnd = double(table.insert(poly, {x = w - borderW/2, y = h - borderW/2, u=1, v=1}))
	end

	if sides[3] and not s then
		s = cornerEnd
	elseif not sides[3] and s then
		table.insert(indexes, {s, cornerStart})
		s = nil
	end
	-- corner four
	if bl > 0 then
		cornerStart, cornerEnd = addSegment(poly, bl, h-bl, bl, 180, w, h, borderW)
	else
		cornerStart, cornerEnd = double(table.insert(poly, {x = borderW/2, y = h - borderW/2, u=0, v=1}))
	end

	if sides[4] and not s then
		s = cornerEnd
	elseif not sides[4] and s then
		table.insert(indexes, {s, cornerStart})
		s = nil
	end
	-- Tie up loose end
	if s then
		table.insert(indexes, {s, #poly + 1})
	end

	local borderShapes = {}
	for l, v in pairs(indexes) do
		table.insert(borderShapes, {})
		for k = v[1], v[2] - 1 do
			local curPoint = poly[k]
			local nextPoint = poly[(k % #poly) + 1]
			local centX = (curPoint.x + nextPoint.x) / 2
			local centY = (curPoint.y + nextPoint.y) / 2

			local sizeX = borderW + 1
			local sizeY = Vector(curPoint.x, curPoint.y):Distance(Vector(nextPoint.x, nextPoint.y)) + 2

			local ang = math.deg(math.atan2(curPoint.y - nextPoint.y, curPoint.x - nextPoint.x))

			table.insert(borderShapes[#borderShapes], {x = centX, y = centY, w = sizeX, h = sizeY, ang = 90 - ang})
		end
	end
	return poly, borderShapes
end

local function drawBorder(data)
	draw.NoTexture()
	surface.SetDrawColor(data.border.color)
	for k, shape in pairs(data.borderShapes) do
		for l, d in pairs(shape) do
			surface.DrawTexturedRectRotated(d.x, d.y, d.w, d.h, d.ang)
		end
	end
end

function GGML.paintManager.GetPaintSetter(attr)
	return function(self, ...)
		GGML.paintManager.addPaint(self)
		self._GGMLPaintData.changed = true
		if attr == "bgColor" then
			self._GGMLPaintData.background = ...
			self._GGMLPaintData.backgroundType = "Color"
		elseif attr == "bgTexture" then
			self._GGMLPaintData.background = ...
			self._GGMLPaintData.backgroundType = "Image"
		elseif attr == "borderWidth" then
			self._GGMLPaintData.border.width = ...
		elseif attr == "borderColor" then
			self._GGMLPaintData.border.color = ...
		elseif attr == "borderRadii" then
			self._GGMLPaintData.border.radii = { ... }
		elseif attr == "borderSides" then
			self._GGMLPaintData.border.sides = { ... }
		end
	end
end

function GGML.paintManager.addPaint(elem)
	if elem._GGMLPaintData then return end
	elem._GGMLPaintData = table.Copy(GGML.paintManager.default)
	elem.Paint = GGML.paintManager.Paint
end

function GGML.paintManager.Paint(self, w, h)
	local data = self._GGMLPaintData
	if not data.border then
		data.border = GGML.paintManager.default.border
	end
	local cornerRadii = data.border.radii

	if not data.noRadius or data.changed then
		data.noRadius = table.sum(cornerRadii) == 0
	end

	if not data.poly or data.changed then
		data.poly, data.borderShapes = generatePolygons(w, h, data.border.width, data.border.sides, unpack(cornerRadii))
	end

	local noRadius = data.noRadius

	data.changed = false

	if data.backgroundType == "Color" then
		local color = data.background or GGML.paintManager.default.background
		surface.SetDrawColor(color)
		draw.NoTexture()
	elseif data.backgroundType == "Image" then
		surface.SetDrawColor(Color(255,255,255))
		surface.SetTexture(data.background)
	end

	if noRadius then
		surface.DrawRect(0, 0, w, h)
	else
		surface.DrawPoly(data.poly)
	end

	if data.border.width > 0 then
		drawBorder(data)
	end
end