package main

import "cookie.engineer/console"
import "cookie.engineer/routes"
import "os"
import "strings"

func main() {

	cwd, err1 := os.Getwd()

	if err1 == nil {

		if strings.HasSuffix(cwd, "/server") {
			cwd = strings.TrimSpace(cwd[0:len(cwd)-7])
		}

		console.Log("Listening on http://localhost:8080")
		routes.Serve(cwd, 8080)

	}

}
