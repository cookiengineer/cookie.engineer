package routes

import "cookie.engineer/utils"
import "net/http"
import "io"
import "os"

func ModifyFile(root string, file string, response http.ResponseWriter, request *http.Request) {

	if request.Method == http.MethodPost {

		buffer, err1 := io.ReadAll(request.Body)
		result := false

		if err1 == nil {

			err2 := os.WriteFile(root + "/" + file, buffer, 0666)

			if err2 == nil {
				result = true
			}

		}

		if result == true {
			utils.RespondWith(response, file, http.StatusOK)
		} else {
			utils.RespondWith(response, file, http.StatusForbidden)
		}

	} else {
		utils.RespondWith(response, file, http.StatusMethodNotAllowed)
	}

}
