local exampleXML = include( "ggml/client/example/example.xml.lua" )

local CONTEXT = {}

function CONTEXT:buttonClick( btn )
    print( self.test.property.thing )
end

function CONTEXT:PreInit()
    self.test = { property = { thing = "hi" } }
end

function GGML.runExample()
    GGML.CreateView( "exampleView", CONTEXT, exampleXML )
    vgui.Create( "exampleView" )
end
