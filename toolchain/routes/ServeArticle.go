package routes

import "net/http"
import "strings"

func ServeArticle(root string, response http.ResponseWriter, request *http.Request) {

	file := request.PathValue("file")

	if strings.HasSuffix(file, ".html") {

		result := RenderArticle(root, file)

		if result == true {

			ServeFile(root+"/weblog/articles", file, response, request)

		} else {

			response.Header().Set("Content-Type", "text/html")
			response.WriteHeader(http.StatusInternalServerError)
			response.Write([]byte("Syntax Error in Markdown Document"))

		}

	} else if strings.HasSuffix(file, ".md") {
		ServeFile(root+"/weblog/articles", file, response, request)
	} else {
		ServeFile(root+"/weblog/articles", file, response, request)
	}

}
