package routes

import "net/http"
import "io"
import "os"
import "strings"

func ModifyFile(root string, file string, response http.ResponseWriter, request *http.Request) {

	if request.Method == http.MethodPost {

		extension := file[strings.LastIndex(file, ".")+1:]
		buffer, err1 := io.ReadAll(request.Body)

		result := false

		if err1 == nil {

			err2 := os.WriteFile(root + "/" + file, buffer, 0666)

			if err2 == nil {
				result = true
			}

		}

		if result == true {

			content_type, ok := MIME[extension]

			if ok == false {
				content_type = "application/octet-stream"
			}

			response.Header().Set("Content-Type", content_type)
			response.WriteHeader(http.StatusOK)
			response.Write([]byte{})

		} else {

			content_type, ok := MIME[extension]

			if ok == false {
				content_type = "application/octet-stream"
			}

			response.Header().Set("Content-Type", content_type)
			response.WriteHeader(http.StatusForbidden)
			response.Write([]byte{})

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
