local CONTEXT = {}

function CONTEXT:buttonClick( btn )
    print( self.test.property.thing )
end

function CONTEXT:PreInit()
    self.test = { property = { thing = "hi" } }
end

function GGML.runExample()
    GGML.CreateView( "exampleView", CONTEXT, include( "ggml/client/example/example.xml.lua" ) )
    vgui.Create( "exampleView" )
end
