local PANEL = {}

function PANEL:Init()
    self._rows = { { type = "ratio", weight = 1 } }
    self._columns = { { type = "ratio", weight = 1 } }
    self._children = {}
end

function PANEL:AddConstColumn( size )
    table.insert( self._columns, { type = "const", size = size } )
    self._changed = true
    self:InvalidateLayout()
end

function PANEL:AddRatioColumn( weight )
    table.insert( self._columns, { type = "ratio", weight = weight } )
    self._changed = true
    self:InvalidateLayout()
end

function PANEL:AddConstRow( size )
    table.insert( self._rows, { type = "const", size = size } )
    self._changed = true
    self:InvalidateLayout()
end

function PANEL:AddRatioRow( weight )
    table.insert( self._rows, { type = "ratio", weight = weight } )
    self._changed = true
    self:InvalidateLayout()
end

function PANEL:OnSizeChanged()
    self._changed = true
end

function PANEL:PerformLayout()
    if not self._changed then return end

    self._changed = false

    self:CalculatePositionData()

    for k, child in pairs( self._children ) do
        self:UpdateGridPosition( child )
    end
end

function PANEL:CalculatePositionData()
    local w, h = self:GetSize()
    local totalColumnWeight = 0
    local totalRowWeight = 0

    for _, colData in pairs( self._columns ) do
        if colData.type == "const" then
            w = math.max( w - colData.size, 0 )
        elseif colData.type == "ratio" then
            totalColumnWeight = totalColumnWeight + colData.weight
        end
    end

    local x = 0
    for gridX, colData in pairs( self._columns ) do
        local slotWidth = 0
        if colData.type == "const" then
            slotWidth = colData.size
        elseif colData.type == "ratio" then
            slotWidth = ( colData.weight / totalColumnWeight ) * w
        end

        colData.x = x
        colData.w = slotWidth

        x = x + slotWidth
    end


    for _, rowData in pairs( self._rows ) do
        if rowData.type == "const" then
            h = math.max( h - rowData.size, 0 )
        elseif rowData.type == "ratio" then
            totalRowWeight = totalRowWeight + rowData.weight
        end
    end

    local y = 0
    for gridY, rowData in pairs( self._rows ) do
        local slotHeight = 0
        if rowData.type == "const" then
            slotHeight = rowData.size
        elseif rowData.type == "ratio" then
            slotHeight = ( rowData.weight / totalRowWeight ) * h
        end

        rowData.y = y
        rowData.h = slotHeight

        y = y + slotHeight
    end

    self._gridDataCalculated = true
end

function PANEL:UpdateGridPosition( panel )
    if not self._gridDataCalculated then return end

    local gridX, gridY = panel:GetGridColumn(), panel:GetGridRow()

    gridX = math.Clamp( gridX, 1, #self._columns )
    gridY = math.Clamp( gridY, 1, #self._rows )

    local gridXSpan, gridYSpan = panel:GetGridColumnSpan(), panel:GetGridRowSpan()
    gridXSpan = math.max( gridXSpan, 1 )
    gridYSpan = math.max( gridYSpan, 1 )

    local x, y = self._columns[gridX].x, self._rows[gridY].y
    local w, h = 0, 0

    for k = gridX, gridX + gridXSpan - 1 do
        local colData = self._columns[k]
        if not colData then break end

        w = w + colData.w
    end

    for k = gridY, gridY + gridYSpan - 1 do
        local colData = self._rows[k]
        if not colData then break end

        h = h + colData.h
    end

    panel:SetPos( x, y )
    panel:SetSize( w, h )
end

function PANEL:PostChildAdded( panel )
    if self._addingChildPanel then return end

    local this = self
    function panel:SetGridColumn( x )
        self._gridColumn = x
        this:UpdateGridPosition( self )
    end
    function panel:SetGridRow( x )
        self._gridRow = x
        this:UpdateGridPosition( self )
    end
    function panel:GetGridColumn()
        return self._gridColumn
    end
    function panel:GetGridRow()
        return self._gridRow
    end

    function panel:SetGridColumnSpan( x )
        self._gridColumnSpan = x
        this:UpdateGridPosition( self )
    end
    function panel:SetGridRowSpan( x )
        self._gridRowSpan = x
        this:UpdateGridPosition( self )
    end
    function panel:GetGridColumnSpan()
        return self._gridColumnSpan
    end
    function panel:GetGridRowSpan()
        return self._gridRowSpan
    end

    panel._gridColumn = 1
    panel._gridRow = 1
    panel._gridColumnSpan = 1
    panel._gridRowSpan = 1
    table.insert( self._children, panel )
    self:UpdateGridPosition( panel )
end

function PANEL:GetChildPropertyStructure()
    return {
        ColumnDefinitions = {
            children = {
                ColumnDefinition = {
                    fields = {
                        Width = "1*"
                    },
                },
            },
        },
        RowDefinitions = {
            children = {
                RowDefinition = {
                    fields = {
                        Height = "1*"
                    },
                },
            },
        },
    }
end

function PANEL:_validateDefinitions( defs, isRows )
    for _, def in pairs( defs ) do
        local val = isRows and def.fields.Height or def.fields.Width
        local _val = val

        local isStar = false
        if val[#val] == "*" then
            isStar = true
            val = string.Left( val, #val - 1 )
        end

        if val == "" and isStar then
            val = 1
        else
            val = tonumber( val )
            if not val then
                return false, _val
            end
        end

        if isRows then
            if isStar then
                self:AddRatioRow( val )
            else
                self:AddConstRow( val )
            end
        else
            if isStar then
                self:AddRatioColumn( val )
            else
                self:AddConstColumn( val )
            end
        end
    end

    return true
end

function PANEL:SetChildProperties( props )
    local hadCols, hadRows = false, false

    for _, property in pairs( props ) do
        if property.name == "ColumnDefinitions" then
            if hadCols then
                return false, "Only one ColumnDefinitions is allowed"
            end
            hadCols = true

            self._columns = {}
            local success, val = self:_validateDefinitions( property.children, false )
            if not success then
                return false, "Invalid ColumnDefintion Width \"" .. val .. "\""
            end
        elseif property.name == "RowDefinitions" then
            if hadRows then
                return false, "Only one RowDefinitions is allowed"
            end
            hadRows = true

            self._rows = {}
            local success, val = self:_validateDefinitions( property.children, true )
            if not success then
                return false, "Invalid RowDefintion Width \"" .. val .. "\""
            end
        end
    end

    return true
end

vgui.Register( "GridLayout", PANEL )
