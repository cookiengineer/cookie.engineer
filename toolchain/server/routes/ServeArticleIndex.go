package routes

import "encoding/json"
import "net/http"
import "os"
import "strconv"
import "strings"

func ServeArticleIndex(root string, response http.ResponseWriter, request *http.Request) {

	if request.Method == http.MethodGet {

		entries, err1 := os.ReadDir(root + "/weblog/articles")

		if err1 == nil {

			var result []string

			for _, entry := range entries {

				name := entry.Name()

				if strings.HasSuffix(name, ".md") {
					result = append(result, name)
				}

			}

			buffer, err2 := json.MarshalIndent(result, "", "\t")

			if err2 == nil {

				response.Header().Set("Content-Type", "application/json")
				response.Header().Set("Content-Length", strconv.Itoa(len(buffer)))
				response.WriteHeader(http.StatusOK)
				response.Write(buffer)

			} else {

				response.Header().Set("Content-Type", "application/json")
				response.WriteHeader(http.StatusInternalServerError)
				response.Write([]byte{})

			}

		} else {

			response.Header().Set("Content-Type", "application/json")
			response.WriteHeader(http.StatusNotFound)
			response.Write([]byte{})

		}

	} else {

		response.Header().Set("Content-Type", "application/json")
		response.WriteHeader(http.StatusMethodNotAllowed)
		response.Write([]byte{})

	}

}
