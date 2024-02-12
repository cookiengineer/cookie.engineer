package routes

import "cookie.engineer/markdown"
import "cookie.engineer/templates"
import "bytes"
import "os"
import "strings"

func RenderFeed(root string) bool {

	var result bool = false

	entries, err1 := os.ReadDir(root + "/weblog/articles")

	feed := markdown.NewFeed()

	if err1 == nil {

		for _, entry := range entries {

			name := entry.Name()

			if strings.HasSuffix(name, ".md") {

				buffer, err2 := os.ReadFile(root + "/weblog/articles/"+name)

				if err2 == nil {

					document := markdown.NewDocument(name[0:len(name)-3]+".html", string(buffer))

					if document.IsValid() {
						feed.AddDocument(document)
					}

				}

			}

		}

	}

	feed.Sort()

	var buffer bytes.Buffer

	if templates.Feed != nil {

		err2 := templates.Feed.Execute(&buffer, feed)

		if err2 == nil {

			err3 := os.WriteFile(root + "/weblog/feed.xml", buffer.Bytes(), 0666)

			if err3 == nil {
				result = true
			}

		}

	}

	return result

}
