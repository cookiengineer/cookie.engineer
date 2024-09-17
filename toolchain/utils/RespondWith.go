package utils

import "net/http"
import "strings"

func RespondWith(response http.ResponseWriter, file string, status int) {

	extension := file[strings.LastIndex(file, ".")+1:]
	content_type, ok := MIME[extension]

	if ok == false {
		content_type = "application/octet-stream"
	}

	response.Header().Set("Content-Type", content_type)
	response.WriteHeader(status)
	response.Write([]byte{})

}
