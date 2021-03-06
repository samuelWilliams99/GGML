local textAliases = {
    ["Font-Size"] = "FontSize",
    ["Font-Family"] = "FontFamily",
    ["Font-Weight"] = "FontWeight",
    ["Font-Decoration"] = "FontDecoration"
}

GGML.ATTR_ALIASES = {
    All = {
        id = "ID",
        Id = "ID",
        Width = "Wide",
        Height = "Tall",
        SizeToContent = "SizeToContents"
    },
    Button = {
        OnClick = "DoClick"
    },
    Label = textAliases,
    TextEntry = textAliases,
}
