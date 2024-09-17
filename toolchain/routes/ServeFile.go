package routes

import "cookie.engineer/utils"
import "net/http"
import "os"
import "strconv"
import "strings"

func ServeFile(root string, file string, response http.ResponseWriter, request *http.Request) {

	if request.Method == http.MethodGet {

		extension := file[strings.LastIndex(file, ".")+1:]
		buffer, err1 := os.ReadFile(root + "/" + file)

		if err1 == nil {

			content_type, ok := utils.MIME[extension]

			if ok == false {
				content_type = "application/octet-stream"
			}

			response.Header().Set("Content-Type", content_type)
			response.Header().Set("Content-Length", strconv.Itoa(len(buffer)))
			response.WriteHeader(http.StatusOK)
			response.Write(buffer)

		} else {
			utils.RespondWith(response, file, http.StatusNotFound)
		}

	} else {
		utils.RespondWith(response, file, http.StatusMethodNotAllowed)
	}

}
