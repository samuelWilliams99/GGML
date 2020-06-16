local exampleXML = include( "ggml/client/example/example.xml.lua" )

local CONTEXT = {}

function CONTEXT:buttonClick( elem )
    print( self.test.property.thing )
    elem:SetFontSize( 10 )
    local elem = self:GetElementByID( "yote" )
    elem:SetBackgroundColor( Color( 255, 0, 0 ) )
    elem:SetBorderRadius( 10 )
end

function CONTEXT:PreInit()
    self.test = { property = { thing = "hi" } }
end

function GGML.runExample()
    GGML.CreateView( "exampleView", CONTEXT, exampleXML )
    local a = vgui.Create( "exampleView" )
end
