package actions

import "cookie.engineer/routes"
import "strings"

func Render(root string, file string) bool {

	var result bool = false

	if !strings.Contains(file, "/") && strings.HasSuffix(file, ".md") {
		result = routes.RenderArticle(root, file)
	}

	return result

}
