package templates

import _ "embed"
import "text/template"

var Index *template.Template

//go:embed Index.tpl
var embedded_Index []byte

func init() {

	tpl, err := template.New("Index").Funcs(template.FuncMap{
		"RenderElement":  RenderElement,
		"RenderElements": RenderElements,
		"RenderInteger":  RenderInteger,
		"RenderStrings":  RenderStrings,
	}).Parse(string(embedded_Index))

	if err == nil {
		Index = tpl
	}

}
