package routes

import "os"
import "strings"

func RenderArticles(root string) {

	entries, err1 := os.ReadDir(root + "/weblog/articles")

	if err1 == nil {

		for _, entry := range entries {

			name := entry.Name()

			if strings.HasSuffix(name, ".md") {
				RenderArticle(root, name)
			}

		}

	}

}
