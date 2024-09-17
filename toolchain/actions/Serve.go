package actions

import "cookie.engineer/routes"
import "cookie.engineer/utils"
import "net/http"
import "os"
import "strconv"
import "strings"

func Serve(root string, port uint) bool {

	var result bool = false

	fsrv := http.FileServer(http.FS(os.DirFS(root)))
	http.Handle("/", fsrv)

	http.HandleFunc("/weblog/index.html", func(response http.ResponseWriter, request *http.Request) {

		if request.Method == http.MethodGet {

			routes.RenderArticles(root)
			routes.RenderFeed(root)
			routes.RenderIndex(root)

			routes.ServeFile(root, "weblog/index.html", response, request)

		} else {

			response.Header().Set("Content-Type", "text/html")
			response.WriteHeader(http.StatusMethodNotAllowed)
			response.Write([]byte{})

		}

	})

	http.HandleFunc("/weblog/articles/*.md", func(response http.ResponseWriter, request *http.Request) {
		routes.ServeArticleIndex(root, response, request)
	})

	http.HandleFunc("/weblog/articles/{file}", func(response http.ResponseWriter, request *http.Request) {

		if request.Method == http.MethodGet {

			file := request.PathValue("file")

			if strings.HasSuffix(file, ".md") {
				routes.ServeArticle(root, response, request)
			} else if strings.HasSuffix(file, ".html") {
				routes.ServeArticle(root, response, request)
			} else {
				routes.ServeFile(root, "weblog/articles/"+file, response, request)
			}

		} else if request.Method == http.MethodPost {

			file := request.PathValue("file")

			if strings.HasSuffix(file, ".md") {
				routes.ModifyFile(root, "weblog/articles/"+file, response, request)
			} else {
				utils.RespondWith(response, file, http.StatusMethodNotAllowed)
			}

		} else if request.Method == http.MethodDelete {

			file := request.PathValue("file")

			if strings.HasPrefix(file, "draft-") && strings.HasSuffix(file, ".md") {
				routes.RemoveFile(root, "weblog/articles/"+file, response, request)
			} else {
				utils.RespondWith(response, file, http.StatusMethodNotAllowed)
			}

		} else {
			utils.RespondWith(response, request.PathValue("file"), http.StatusMethodNotAllowed)
		}

	})

	err1 := http.ListenAndServe(":"+strconv.FormatUint(uint64(port), 10), nil)

	if err1 == nil {
		result = true
	}

	return result

}
