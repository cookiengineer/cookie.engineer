package main

import "cookie.engineer/console"
import "cookie.engineer/actions"
import "os"
import "strings"

func showUsage() {

	console.Group("Usage:")
	console.Log("render <filename>.md")
	console.Log("$PWD must be the cookie.engineer/ folder")
	console.GroupEnd("------")

}

func main() {

	cwd, err1 := os.Getwd()

	if err1 == nil {

		if strings.HasSuffix(cwd, "/server") {
			cwd = strings.TrimSpace(cwd[0:len(cwd)-7])
		}

		if strings.HasSuffix(cwd, "/toolchain") {
			cwd = strings.TrimSpace(cwd[0:len(cwd)-10])
		}

		file := ""

		if len(os.Args) == 2 {

			if strings.HasSuffix(os.Args[1], ".md") {

				file = os.Args[1]

				if strings.Contains(file, "/") {
					file = strings.TrimSpace(file[strings.LastIndex(file, "/")+1:])
				}

			}

		}

		if file != "" {

			result := actions.Render(cwd, file)

			if result == true {
				os.Exit(0)
			} else {
				os.Exit(1)
			}

		} else {

			showUsage()
			os.Exit(1)

		}

	} else {

		showUsage()
		os.Exit(1)

	}

}
