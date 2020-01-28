# GGML
GMod Graphics Markup Language.  
GGML is a VGUI Wrapper that add WPF like UI creation, including automated font creation/reuse, property binding, layouts, etc.

## Usage
A UI element consists of 2 parts (normally in 2 files), the *context* and the *xml*

### Context
Here you define an object where handlers, properties, etc. will be stored.  
For example (example.lua):
```
local CONTEXT = {}

function CONTEXT:buttonClick(elem)
  self.testProperty = "Clicked!"
end

function CONTEXT:PreInit()
  self.testProperty = "Not yet clicked!"
end

function CONTEXT:Init()
  self:FindElementById("testLabel"):SetTextColor(Color(255,0,0))
end
```

### XML
This is a string containing the XML, it is preferred to store this in a separate file, so that you can use separate syntax highlighting for it.  
For example (example.xml.lua):
```
exampleXML = [[
<Frame Width="50%" 
       Height="50%"
       Title="Example frame"
       Center
       MakePopup >
  <Label id="testLabel" Top="50%" Left="50%" Text="@@testProperty" Font-Size="10%" SizeToContent></Label>
  <Button OnClick="@buttonClick" TextColor="#ff0000" Top="150" Left="50">Click me?</Button>
</Frame>
]]
```

### Creating the element
Lastly, simply call `GGML.CreateView("exampleView", CONTEXT, exampleXML)` to register a vgui element with the given name.
You are then able to call `vgui.Create("exampleView")` to use this element.

## XML syntax
### Tags
GGML will look for vgui elements named either your tag name, or `D[yourTagName]`, so `<Image/>` will create a `DImage` element.  
There are some name aliases to give elements more obvious names, e.g. `DListView` can be created simply with `<List/>`
### Attributes Names
- When GGML find an attribute name, it will look for setter functions by the name `Attribute` or `SetAttribute` and call them with the value  
So the attribute `Wide="10"` will internally call `element:SetWide(10)`  
  
- Some attributes do not call the setter, but instead replace it, for example `DoClick`  
So the attribute `DoClick="@myFunc"` will internally call `element.DoClick = context.myFunc` (More on value syntax below)  
**Note, any functions will automatically be passed in the context and calling element as first 2 arguments, so it is recommended to define them as** `CONTEXT:myFunc(elem, ...)` **rather than** `CONTEXT.myFunc(context, elem, ...)`
  
- You can force GGML to replace values by prefixing the attribute name with `$`  
So the attribute `$myVar="10"` will internally call `element.myVar = 10`  
  
- Lastly, if you do not provide a value to an attribute name, e.g. `<Frame Center/>`, GGML will call that function on the element, e.g. `element:Center()`  
Also, non-value attributes prefixed with `$` will set that field to nil, e.g. `<Button $DoClick/>` => `element.DoClick = nil`  

### Attribute Values
- All attribute values must be surrounded in quotes
- Normal strings will be parsed as such, e.g.  
`Text="Hello world"`
- Prefixing any value with `&` will force it to be parsed as a string, e.g.  
`Text="&10"`
- Numbers (Integer or float) will be parsed as expected, e.g.  
`FontSize="30"`
- The constants `"true"` and `"false"` are parsed as booleans, e.g.  
`Visible="true"`
- Colors can be inputed as hex when prefixed with `#`, e.g.  
`TextColor="#ff0000"`
- Prefixing a value with `^` will read it as a global variable (supporting dot notation), e.g.  
`Dock="^TOP"`
- Prefixing a value with `@` will read it as a member of the context, e.g.  
`Text="@myString"` => `element:SetText(context.myString)`
- Prefixing a value with `@@` will bind the attribute to a property, e.g.  
`Text="@@myProperty"`.  
Setting `context.myProperty` will set the text on this value automatically.  
**Note, be sure to give this property a default value in `CONTEXT:PreInit()`, `CONTEXT:Init()` is called too late.**
- Postfixing a number with `%` will take it as a percent of the parents appropriate property, e.g.  
`Height="50%"`

## Font manager
Creating and managing fonts in GMod is annoying, the font manager keeps track of some internal fonts to allow you direct access to simply set font size, family, weight and decoration with ease.

## Layouts
**NOT YET ADDED**  
Will have a GridLayout and LinearLayout similar in style to WPF, allowing for ColumnDefinitions and RowDefinitions along with Span.

## Useful attributes
- FontSize
- FontWeight
- FontFamily
- FontDecoration (Space separated list of `underline`, `strikethrough`, `italic` or `bold`)
- Top (y position)
- Left (x position)
- Width (Wide)
- Height (Tall)
- id (used for context:FindElementById())
- OnClick (DoClick)

