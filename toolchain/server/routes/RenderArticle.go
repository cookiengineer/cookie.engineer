package routes

import "cookie.engineer/console"
import "cookie.engineer/markdown"
import "cookie.engineer/templates"
import "bytes"
import "os"
import "strings"

func RenderArticle(root string, file string) bool {

	var result bool = false

	name := ""

	if strings.HasSuffix(file, ".html") {
		name = file[0:len(file)-5]
	} else if strings.HasSuffix(file, ".md") {
		name = file[0:len(file)-3]
	}

	if name != "" {

		buffer, err1 := os.ReadFile(root + "/weblog/articles/"+name+".md")

		if err1 == nil {

			document := markdown.NewDocument(name+".md", string(buffer))

			var buffer bytes.Buffer

			if templates.Article != nil {

				err2 := templates.Article.Execute(&buffer, document)

				if err2 == nil {

					err3 := os.WriteFile(root+"/weblog/articles/"+name+".html", buffer.Bytes(), 0666)

					if err3 == nil {
						result = true
					}

				}

			}

		}

	}

	if result == true {
		console.Info("Rendered \"" + name + ".md\"")
	} else {
		console.Error("Cannot render \"" + name + ".md\"")
	}

	return result

}
