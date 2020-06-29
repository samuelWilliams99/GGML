GGML = GGML or {}
GGML.elements = GGML.elements or {}
GGML.Loaded = false

include( "util/luacompat.lua" )
include( "util/helper.lua" )
include( "parsers/xmlparser.lua" )
include( "parsers/cssparser.lua" )
include( "context.lua" )
include( "fontmanager.lua" )
include( "paintmanager.lua" )
include( "lookups/lookupincludes.lua" )
include( "util/vguimod.lua" )
include( "inflater/inflater.lua" )
include( "layouts/gridlayout.lua" )
include( "layouts/linearlayout.lua" )
include( "example/example.lua" )

--[[
TO TEST

TO DO
layouts :) -- same style as c#
    Requires implementing child properties, valid properties defined on the element
        something like "GetAllChildProperties", check this then check element name
        Decide on structure of child properties and how they'll be stored on the element
    Grid
        \/ for Rows as well
        ColumnDefinitions
            ColumnDefinition
                Width - number (fixed), number* (weight), * (1* - default)
        Column
        ColumnSpan
        Make changing any of these values trigger an invalidateparent, and do all the positioning in the layout
    Linear
        Orientation (Horizontal or Vertical)
        just puts shit in a line

Padding/margin (not using DOCK)
    Enable GGMLPadding/Docking only on elements created by GGML via a "UseGGMLPositioning" func
    Make pos, size, (with percents) work with padding/margin somehow
Think of more selfclosing tags

Css like styling, class support, etc. this one is big -- we gettin there
    bg image (loaded from url() or linear-gradient(https://www.w3schools.com/css/css3_gradients.asp)), 
    url done by loading a DHTML with the image, using GetHTTPMaterial and drawing a rectangle with its current texture, saving that to RT, discard DHTML
    gradient done by layering a coloured alpha gradient over top of itself a few times in a mathsy way, probably easier than above 

BACKLOG
seems underline and strikeout just dont work l o l
]]

function GGML.CreateView( name, context, data )
    if not data then
        error( "Invalid XML for GGML object \"" .. name .. "\": No XML provided" )
    end
    local success, xml = GGML.parseXML( data )

    if not success then
        error( "Invalid XML for GGML object \"" .. name .. "\": " .. xml )
    end

    if #xml.children ~= 1 then
        error( "Invalid XML for GGML object \"" .. name .. "\": Root must be singular" )
    end
    local xmlRoot = xml.children[1]

    context = table.Copy( context ) -- Don't modify the original, in case of recreation

    table.Inherit( context, GGML.ContextBase )

    local contextInit = context.Init or function() end

    function context:Init()
        if self.PreInit then self:PreInit() end

        self.xmlRoot = table.Copy( xmlRoot )
        self.xml = self.xmlRoot

        self.changeListeners = {}
        self.mtGetters = {}
        local err
        local success = xpcall( GGML.Inflate, function( x ) err = x end, name, self.xmlRoot, self )

        if not success then
            self:Remove()
            error( err )
        end

        table.insert( GGML.elements, self )

        self.inflated = true

        contextInit( self )
    end

    local base = GGML.FindClassName( xmlRoot.tag, name )

    vgui.Register( name, context, base )
end

concommand.Add( "ggml_reload", function()
    include( "ggml/client/base.lua" )
end )

concommand.Add( "ggml_example", function()
    if GGML.Loaded then
        GGML.runExample()
    else
        hook.Once( "GGML_Loaded", GGML.runExample )
    end
end )

concommand.Add( "ggml_remove_all", function()
    for k, v in pairs( GGML.elements ) do
        if IsValid( v ) then v:Remove() end
    end
end )
