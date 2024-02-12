package templates

import _ "embed"
import "text/template"

var Article *template.Template

//go:embed Article.tpl
var embedded_Article []byte

func init() {

	tpl, err := template.New("Article").Funcs(template.FuncMap{
		"RenderElement":  RenderElement,
		"RenderElements": RenderElements,
		"RenderInteger":  RenderInteger,
		"RenderStrings":  RenderStrings,
	}).Parse(string(embedded_Article))

	if err == nil {
		Article = tpl
	}

}
