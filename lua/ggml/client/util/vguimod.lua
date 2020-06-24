local screen = {
    GetWide = ScrW,
    GetTall = ScrH
}

local function getPercent( str )
    if type( str ) == "string" then
        local n = tonumber( string.sub( str, 1, #str - 1 ) )
        if str[#str] == "%" and n then
            return n / 100
        end
    end
    return nil
end

local function performLayout( self )
    for fName, values in pairs( self._GGMLMults ) do
        local prevVal = self._GGMLPrevVals[fName] or {}
        local pFunc = self._GGMLPercentFuncs[fName]
        local pVals = { pFunc( self:GetParent() or screen ) }

        values = table.Copy( values )

        local changed = false
        for k, v in ipairs( values ) do
            local n = getPercent( v )
            if pVals[k] ~= nil and n then
                values[k] = n * pVals[k]
            end
            if values[k] ~= prevVal[k] then
                changed = true
            end
        end

        if changed then
            self._GGMLPrevVals[fName] = values
            self._GGMLOldSetters[fName]( self, unpack( values ) )
        end

    end

    self._GGMLOldPerformLayout( self )
end

local function addPerformLayout( element )
    if not element._GGMLOldPerformLayout then
        element._GGMLOldPerformLayout = element.PerformLayout or function() end
    end

    element.PerformLayout = performLayout
end

local function makePercentable( element, fName, percentFunc )
    if type( element ) == "string" then
        element = vgui.GetControlTable( element )
    end

    if not element then error( "Element does not exist" ) end

    element._GGMLOldSetters = element._GGMLOldSetters or {}
    if not element._GGMLOldSetters[fName] then
        element._GGMLOldSetters[fName] = element[fName]
    end

    element._GGMLPercentFuncs = element._GGMLPercentFuncs or {}
    element._GGMLPercentFuncs[fName] = percentFunc

    element[fName] = function( self, ... )
        self._GGMLPrevVals = self._GGMLPrevVals or {}
        self._GGMLMults = self._GGMLMults or {}

        local args = { ... }
        local foundPercent = false
        for k, v in ipairs( args ) do
            n = getPercent( v )
            if n then
                local pFunc = self._GGMLPercentFuncs[fName]
                local pVals = { pFunc( self:GetParent() or screen ) }

                if pVals[k] ~= nil then

                    foundPercent = true

                    self._GGMLMults[fName] = args

                    addPerformLayout( self )
                    self:InvalidateLayout( true )

                    break
                end
            end
        end

        if not foundPercent then
            if self._GGMLOldPerformLayout then
                self._GGMLMults[fName] = nil

                if #table.GetKeys( self._GGMLMults ) == 0 then
                    self.PerformLayout = self._GGMLOldPerformLayout
                    self._GGMLOldPerformLayout = nil
                end
            end
            self._GGMLOldSetters[fName]( self, ... )
        end
    end
end

local elems = { "DPanel", "DFrame", "DLabel", "DTextEntry" }

local function addField( panel, k, data )
    -- Setter
    panel._GGMLFieldFunctions = panel._GGMLFieldFunctions or {}
    local funcs = panel._GGMLFieldFunctions
    funcs["Set" .. k] = funcs["Set" .. k] or panel["Set" .. k] or function() end

    panel["Set" .. k] = function( self, ... )
        self._GGMLFields = self._GGMLFields or {}
        self._GGMLFields[k] = { ... }
        if data.Set then
            data.Set( self, ... )
        end
    end

    -- Getter
    funcs["Get" .. k] = funcs["Get" .. k] or panel["Get" .. k] or function() end

    if data.Get then
        panel["Get" .. k] = data.Get
    else
        panel["Get" .. k] = function( self )
            if self._GGMLFields and self._GGMLFields[k] then
                return unpack( self._GGMLFields[k] )
            else
                return data.Default
            end
        end
    end
end

-- Wait until vgui has loaded
timer.Create( "GGML_Wait", 0.1, 0, function()
    if not vgui.GetControlTable( "DFrame" ) then return end
    timer.Remove( "GGML_Wait" )

    -- Adding stuff for "All", which simply means the 3 base elements in vgui
    for k, class in pairs( elems ) do
        local panel = vgui.GetControlTable( class )
        for k, v in pairs( GGML.VGUI_ADDITIONS.OVERRIDES.All ) do
            panel[k] = v
        end
        for k, data in pairs( GGML.VGUI_ADDITIONS.FIELDS.All ) do
            addField( panel, k, data )
        end
        for funcName, pFunc in pairs( GGML.PERCENTABLE.All ) do
            makePercentable( panel, funcName, pFunc )
        end
    end

    -- Adding stuff for individual elements
    for k, v in pairs( GGML.VGUI_ADDITIONS.OVERRIDES ) do
        if k == "All" then continue end
        local panel = vgui.GetControlTable( k )
        if panel then
            for name, func in pairs( v ) do
                panel[name] = func
            end
        else
            print( "[GGML] Warning, panel " .. k .. " not found" )
        end
    end

    -- Adding stuff for individual elements
    for panelName, panelData in pairs( GGML.VGUI_ADDITIONS.FIELDS ) do
        if panelName == "All" then continue end
        local panel = vgui.GetControlTable( panelName )
        if panel then
            for k, data in pairs( panelData ) do
                addField( panel, k, data )
            end
        else
            print( "[GGML] Warning, panel " .. k .. " not found" )
        end
    end

    -- Make things accept %'s when needed
    -- This means you can call things like panel:SetSize("10%", 50)
    -- Aka, this modifies existing setters
    for k, v in pairs( GGML.PERCENTABLE ) do
        if k == "All" then continue end
        local panel = vgui.GetControlTable( k )
        if panel then
            for name, func in pairs( v ) do
                makePercentable( panel, name, func )
            end
        else
            print( "[GGML] Warning, panel " .. k .. " not found" )
        end
    end

    GGML.oldVGUICreate = GGML.oldVGUICreate or vgui.Create
    vgui.Create = function( className, parent, ... )
        if parent and parent.PreChildAdded then
            parent = parent:PreChildAdded( className ) or parent
        end
        local panel = GGML.oldVGUICreate( className, parent, ... )
        if parent and parent.PostChildAdded then
            parent:PostChildAdded( panel )
        end
        return panel
    end

    print( "[GGML] VGUIMOD Loaded" )
    GGML.Loaded = true
    hook.Run( "GGML_Loaded" )
end )
