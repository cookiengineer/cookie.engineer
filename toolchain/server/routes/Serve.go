package routes

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

			RenderArticles(root)
			RenderFeed(root)
			RenderIndex(root)

			ServeFile(root, "weblog/index.html", response, request)

		} else {

			response.Header().Set("Content-Type", "text/html")
			response.WriteHeader(http.StatusMethodNotAllowed)
			response.Write([]byte{})

		}

	})

	http.HandleFunc("/weblog/articles/*.md", func(response http.ResponseWriter, request *http.Request) {
		ServeArticleIndex(root, response, request)
	})

	http.HandleFunc("/weblog/articles/{file}", func(response http.ResponseWriter, request *http.Request) {

		if request.Method == http.MethodGet {

			file := request.PathValue("file")

			if strings.HasSuffix(file, ".md") {
				ServeArticle(root, response, request)
			} else if strings.HasSuffix(file, ".html") {
				ServeArticle(root, response, request)
			} else {
				ServeFile(root, "weblog/articles/"+file, response, request)
			}

		} else if request.Method == http.MethodPost {

			file := request.PathValue("file")

			if strings.HasSuffix(file, ".md") {

				ModifyFile(root, "weblog/articles/"+file, response, request)

			} else {

				extension := file[strings.LastIndex(file, ".")+1:]
				content_type, ok := MIME[extension]

				if ok == false {
					content_type = "application/octet-stream"
				}

				response.Header().Set("Content-Type", content_type)
				response.WriteHeader(http.StatusMethodNotAllowed)
				response.Write([]byte{})

			}

		} else {

			file := request.PathValue("file")

			extension := file[strings.LastIndex(file, ".")+1:]
			content_type, ok := MIME[extension]

			if ok == false {
				content_type = "application/octet-stream"
			}

			response.Header().Set("Content-Type", content_type)
			response.WriteHeader(http.StatusMethodNotAllowed)
			response.Write([]byte{})

		}

	})

	err1 := http.ListenAndServe(":"+strconv.FormatUint(uint64(port), 10), nil)

	if err1 == nil {
		result = true
	}

	return result

}
