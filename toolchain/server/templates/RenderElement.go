package templates

import "cookie.engineer/markdown"

func RenderElement(element markdown.Element, indent string) string {
	return element.Render(indent)
}
