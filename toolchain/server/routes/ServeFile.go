package routes

import "net/http"
import "os"
import "strconv"
import "strings"

func ServeFile(root string, file string, response http.ResponseWriter, request *http.Request) {

	if request.Method == http.MethodGet {

		extension := file[strings.LastIndex(file, ".")+1:]
		buffer, err1 := os.ReadFile(root + "/" + file)

		if err1 == nil {

			content_type, ok := MIME[extension]

			if ok == false {
				content_type = "application/octet-stream"
			}

			response.Header().Set("Content-Type", content_type)
			response.Header().Set("Content-Length", strconv.Itoa(len(buffer)))
			response.WriteHeader(http.StatusOK)
			response.Write(buffer)

		} else {

			content_type, ok := MIME[extension]

			if ok == false {
				content_type = "application/octet-stream"
			}

			response.Header().Set("Content-Type", content_type)
			response.WriteHeader(http.StatusNotFound)
			response.Write(buffer)

		}

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

}
