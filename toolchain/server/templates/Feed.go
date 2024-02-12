package templates

import _ "embed"
import "text/template"

var Feed *template.Template

//go:embed Feed.tpl
var embedded_Feed []byte

func init() {

	tpl, err := template.New("Feed").Funcs(template.FuncMap{
		"RenderElement":  RenderElement,
		"RenderElements": RenderElements,
		"RenderInteger":  RenderInteger,
		"RenderStrings":  RenderStrings,
	}).Parse(string(embedded_Feed))

	if err == nil {
		Feed = tpl
	}

}
