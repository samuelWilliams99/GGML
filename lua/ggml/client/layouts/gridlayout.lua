local PANEL = {}

function PANEL:Init()
    self._rows = {}
    self._columns = {}
    self._panels = {}
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

    self._changed = true

    local curSize = Vector( #self._columns, #self._rows )
    if self._prevSize ~= curSize then
        self._prevSize = curSize

        -- Delay to avoid complaints about creating elements in PerformLayout
        timer.Simple( 0, function()
            self:CreatePanels()
        end )
    else
        self:PositionPanels()
    end
end

function PANEL:CreatePanels()
    for k, child in pairs( self._children ) do
        child:SetParent( nil )
    end

    self:Clear()
    self._panels = {}
    for x, colData in pairs( self._columns ) do
        self._panels[x] = {}
        for y, rowData in pairs( self._rows ) do
            self._addingChildPanel = true
            self._panels[x][y] = vgui.Create( "DPanel", self )
            self._addingChildPanel = false
            self._panels[x][y].Paint = nil
        end
    end

    for k, child in pairs( self._children ) do
        self:UpdateGridPosition( child )
    end

    self:PositionPanels()
end

function PANEL:PositionPanels()
    local w, h = self:GetSize()
    local totalColumnWeight = 0
    local totalRowWeight = 0

    for _, colData in pairs( self._columns ) do
        if colData.type == "const" then
            w = w - colData.size
        elseif colData.type == "ratio" then
            totalColumnWeight = totalColumnWeight + colData.weight
        end
    end

    for _, rowData in pairs( self._rows ) do
        if rowData.type == "const" then
            h = h - rowData.size
        elseif rowData.type == "ratio" then
            totalRowWeight = totalRowWeight + rowData.weight
        end
    end

    local x = 0

    for gridX, col in pairs( self._panels ) do
        local colData = self._columns[gridX]
        local slotWidth = 0
        if colData.type == "const" then
            slotWidth = colData.size
        elseif colData.type == "ratio" then
            slotWidth = ( colData.weight / totalColumnWeight ) * w
        end

        local y = 0
        for gridY, panel in pairs( col ) do
            local rowData = self._rows[gridY]
            local slotHeight = 0
            if rowData.type == "const" then
                slotHeight = rowData.size
            elseif rowData.type == "ratio" then
                slotHeight = ( rowData.weight / totalRowWeight ) * h
            end

            panel:SetPos( x, y )
            panel:SetSize( slotWidth, slotHeight )

            y = y + slotHeight
        end

        x = x + slotWidth
    end
end

function PANEL:UpdateGridPosition( panel )
    if #self._panels == 0 then return end
    local gridX, gridY = panel:GetGridColumn(), panel:GetGridRow()
    gridX = math.Clamp( gridX, 1, #self._columns )
    gridY = math.Clamp( gridY, 1, #self._rows )
    local gridPanel = self._panels[gridX][gridY]
    panel:SetParent( gridPanel )
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

    panel._gridColumn = 1
    panel._gridRow = 1
    table.insert( self._children, panel )
    self:UpdateGridPosition( panel )
    panel:Dock( FILL )
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

            local success, val = self:_validateDefinitions( property.children, false )
            if not success then
                return false, "Invalid ColumnDefintion Width \"" .. val .. "\""
            end
        elseif property.name == "RowDefinitions" then
            if hadRows then
                return false, "Only one RowDefinitions is allowed"
            end
            hadRows = true

            local success, val = self:_validateDefinitions( property.children, true )
            if not success then
                return false, "Invalid RowDefintion Width \"" .. val .. "\""
            end
        end
    end

    return true
end

vgui.Register( "GridLayout", PANEL )
