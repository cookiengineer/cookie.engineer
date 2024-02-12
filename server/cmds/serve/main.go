package main

import "cookie.engineer/markdown"
import "fmt"
import "os"
import "strings"

func main() {

	cwd, err1 := os.Getwd()

	if err1 == nil {

		if strings.HasSuffix(cwd, "/server") {
			cwd = strings.TrimSpace(cwd[0:len(cwd)-7])
		}

		document := markdown.Parse(cwd + "/weblog/articles/test.md")

		if document.IsValid() {

			html := document.Render()

			lines := strings.Split(html, "\n")

			for l := 0; l < len(lines); l++ {
				fmt.Println(lines[l])
			}

		}

	}

}
