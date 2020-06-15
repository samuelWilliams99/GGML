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
include( "example/example.lua" )

-- TO TEST
-- Make PerformLayouts get removed when u set width, height, size, etc.
-- Change binding to support 2way, @<prop for property > field, @>prop for field > property, @= for 2way
-- add a lookup for selfclosing tags, like <br> -- test on labels

-- TO DO
--    bg image (loaded from url() or linear-gradient(https://www.w3schools.com/css/css3_gradients.asp)), 
--    url done by loading a DHTML with the image, using GetHTTPMaterial and drawing a rectangle with its current texture, saving that to RT, discard DHTML
--    gradient done by layering a coloured alpha gradient over top of itself a few times in a mathsy way, probably easier than above 

-- Css like styling, class support, etc. this one is big -- we gettin there
-- layouts :) -- same style as c#, override vgui.Create in vguimod to add a preAdd and postAdd function to panels
-- Selectable lookups, so I can have a html/css mode -- probably no point, just have all at once

-- BACKLOG
-- seems underline and strikeout just dont work l o l


function GGML.CreateView( name, context, data )
    local success, xml = GGML.parseXML( data )

    if not success then
        error( "Invalid XML for GGML object \"" .. name .. "\": " .. xml )
    end

    local rootKeys = table.GetKeys( xml )
    if #rootKeys ~= 1 or rootKeys[1] ~= 1 then
        error( "Invalid XML for GGML object \"" .. name .. "\": Root must be singular" )
    end
    local xmlRoot = xml[1]

    table.Inherit( context, GGML.ContextBase )

    local contextInit = context.Init or function() end

    function context:Init()
        if self.PreInit then self:PreInit() end

        self.xmlRoot = table.Copy( xmlRoot )

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

    local base = GGML.FindClassName( xmlRoot.tag )

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
