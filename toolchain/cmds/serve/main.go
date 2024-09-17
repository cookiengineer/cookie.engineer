package main

import "cookie.engineer/console"
import "cookie.engineer/actions"
import "os"
import "strings"

func main() {

	cwd, err1 := os.Getwd()

	if err1 == nil {

		if strings.HasSuffix(cwd, "/server") {
			cwd = strings.TrimSpace(cwd[0:len(cwd)-7])
		}

		if strings.HasSuffix(cwd, "/toolchain") {
			cwd = strings.TrimSpace(cwd[0:len(cwd)-10])
		}

		console.Log("Listening on http://localhost:8080")

		actions.Serve(cwd, 8080)

	}

}
