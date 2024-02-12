package routes

import "cookie.engineer/markdown"
import "cookie.engineer/templates"
import "bytes"
import "os"
import "strings"

func RenderIndex(root string) bool {

	var result bool = false

	entries, err1 := os.ReadDir(root + "/weblog/articles")

	index := markdown.NewIndex()

	if err1 == nil {

		for _, entry := range entries {

			name := entry.Name()

			if strings.HasSuffix(name, ".md") {

				buffer, err2 := os.ReadFile(root + "/weblog/articles/"+name)

				if err2 == nil {

					document := markdown.NewDocument(name[0:len(name)-3]+".html", string(buffer))

					if document.IsValid() {
						index.AddDocument(document)
					}

				}

			}

		}

	}

	index.Sort()

	var buffer bytes.Buffer

	if templates.Index != nil {

		err2 := templates.Index.Execute(&buffer, index)

		if err2 == nil {

			err3 := os.WriteFile(root + "/weblog/index.html", buffer.Bytes(), 0666)

			if err3 == nil {
				result = true
			}

		}

	}

	return result

}
