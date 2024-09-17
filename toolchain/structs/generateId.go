package structs

import "cookie.engineer/utils"
import "strings"

func generateId(element *Element) string {

	var texts []string

	if element.Text != "" {

		chunks := strings.Split(strings.TrimSpace(utils.ToASCII(element.Text)), "-")

		for c := 0; c < len(chunks); c++ {

			text := strings.TrimSpace(chunks[c])

			if len(text) > 0 {
				texts = append(texts, text)
			}

		}

	} else if len(element.Children) > 0 {

		for c := 0; c < len(element.Children); c++ {

			child := element.Children[c]

			if child.Type == "b" || child.Type == "code" || child.Type == "del" || child.Type == "em" || child.Type == "#text" {

				tmp := strings.TrimSpace(utils.ToASCIIName(child.Text))

				if strings.HasPrefix(tmp, "-") {
					tmp = tmp[1:]
				}

				if strings.HasSuffix(tmp, "-") {
					tmp = tmp[0 : len(tmp)-1]
				}

				chunks := strings.Split(tmp, "-")

				for c := 0; c < len(chunks); c++ {

					text := strings.TrimSpace(chunks[c])

					if len(text) > 0 {
						texts = append(texts, text)
					}

				}

			}

		}

	}

	var filtered []string

	if len(texts) > 0 {

		if utils.IsNumber(string(texts[0][0])) {
			texts = texts[1:]
		}

		for t := 0; t < len(texts); t++ {

			text := strings.ToLower(strings.TrimSpace(texts[t]))

			if text != "" {
				filtered = append(filtered, text)
			}

		}

		return strings.Join(filtered, "-")

	}

	return ""

}
