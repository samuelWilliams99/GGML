include("ggml/client/example/example.xml.lua")

local CONTEXT = {}

function CONTEXT:buttonClick(elem)
	self.testProperty = "nou"
end

function CONTEXT:PreInit()
	self.testProperty = "test"
end

function GGML.runExample()
	GGML.CreateView("exampleView", CONTEXT, exampleXML)
	local a = vgui.Create("exampleView")
end