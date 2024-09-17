package templates

import "cookie.engineer/structs"

func RenderElement(element structs.Element, indent string) string {
	return element.Render(indent)
}
