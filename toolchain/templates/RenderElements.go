package templates

import "cookie.engineer/structs"

func RenderElements(elements []*structs.Element, indent string) string {

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
