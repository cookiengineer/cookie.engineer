package templates

import "cookie.engineer/markdown"

func RenderElements(elements []*markdown.Element, indent string) string {

	var result string

	for e := 0; e < len(elements); e++ {

		tmp := elements[e].Render(indent)

		if e == 0 {
			result += tmp
		} else {
			result += " " + tmp
		}

	}

	return result

}
