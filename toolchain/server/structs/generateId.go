package structs

import "cookie.engineer/utils"
import "strings"

func generateId(element *Element) string {

	var texts []string

	if element.Text != "" {

		texts = append(texts, strings.TrimSpace(utils.ToASCII(element.Text)))

	} else if len(element.Children) > 0 {

		for c := 0; c < len(element.Children); c++ {

			child := element.Children[c]

			if child.Type == "b" || child.Type == "code" || child.Type == "del" || child.Type == "em" || child.Type == "#text" {

				text := strings.TrimSpace(utils.ToASCIIName(child.Text))

				if strings.HasPrefix(text, "-") {
					text = text[1:]
				}

				if strings.HasSuffix(text, "-") {
					text = text[0 : len(text)-1]
				}

				texts = append(texts, text)

			}

		}

	}

	var filtered []string

	for t := 0; t < len(texts); t++ {

		text := strings.ToLower(strings.TrimSpace(texts[t]))

		if text != "" {
			filtered = append(filtered, text)
		}

	}

	return strings.Join(filtered, "-")

}
