package routes

import "cookie.engineer/utils"
import "fmt"
import "net/http"

func RemoveFile(root string, file string, response http.ResponseWriter, request *http.Request) {

	if request.Method == http.MethodDelete {

		fmt.Println("TODO: Remove file " + file)
		// TODO

	} else {
		utils.RespondWith(response, file, http.StatusMethodNotAllowed)
	}

}
