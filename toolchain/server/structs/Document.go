package structs

import "regexp"
import "strings"

type Document struct {
	File string `json:"file"`
	Meta struct {
		Name string   `json:"name"`
		Date string   `json:"date"`
		Tags []string `json:"tags"`
		Type []string `json:"type"`
		Crux string   `json:"crux"`
	} `json:"meta"`
	Statistics struct {
		Minutes int `json:"minutes"`
		Words   int `json:"words"`
	} `json:"statistics"`
	Body []*Element `json:"body"`
}

func NewDocument(file string, value string) Document {

	var document Document

	document.File = strings.TrimSpace(file)
	document.Meta.Tags = make([]string, 0)
	document.Meta.Type = make([]string, 0)
	document.Body = make([]*Element, 0)

	document.Parse(value)

	return document

}

func (document *Document) AddElement(value Element) {

	var element = &value
	document.Body = append(document.Body, element)

}

func (document *Document) Count() {

	var words int = 0

	for b := 0; b < len(document.Body); b++ {
		words += countWords(document.Body[b])
	}

	document.Statistics.Words = words
	document.Statistics.Minutes = int(document.Statistics.Words / 200)

}

func (document *Document) GetLastElement() *Element {

	var element *Element = nil

	if len(document.Body) > 0 {
		element = document.Body[len(document.Body)-1]
	}

	return element

}

func (document *Document) IsValid() bool {

	var result bool = false

	if document.File != "" && len(document.Body) > 0 {

		result = true

		if document.Meta.Name == "" {
			result = false
		}

		if document.Meta.Date == "" {
			result = false
		}

		if len(document.Meta.Tags) == 0 {
			result = false
		}

		if len(document.Meta.Type) == 0 {
			result = false
		}

		if document.Meta.Crux == "" {
			result = false
		}

	}

	return result

}

func (document *Document) Parse(value string) {

	lines := strings.Split(strings.TrimSpace(value), "\n")
	regexp_ul, _ := regexp.Compile("^([\\*\\-+]+)[[:space:]]")
	regexp_ol, _ := regexp.Compile("^([0-9]+)\\.[[:space:]]")

	var first_line = 0

	if lines[0] == "===" {

		for l := 1; l < len(lines); l++ {

			line := strings.TrimSpace(lines[l])

			if strings.HasPrefix(line, "- ") && strings.Contains(line, ":") {

				key := strings.TrimSpace(line[2:strings.Index(line, ":")])
				val := strings.TrimSpace(line[strings.Index(line, ":")+1:])

				if key == "date" {
					document.SetDate(val)
				} else if key == "name" {
					document.SetName(val)
				} else if key == "tags" {
					values := strings.Split(val, ",")
					document.SetTags(values)
				} else if key == "type" {
					values := strings.Split(val, ",")
					document.SetType(values)
				} else if key == "crux" {
					document.SetCrux(val)
				}

			} else if line == "===" {
				first_line = l + 1
				break
			}

		}

	}

	for l := first_line; l < len(lines); l++ {

		line := strings.TrimSpace(lines[l])

		pointer := document.GetLastElement()

		if pointer != nil && pointer.Type == "pre" {

			if line == "```" {
				element := NewElement("#text")
				element.SetText("")
				document.AddElement(element)
			} else {
				// Preserve indention
				pointer.AddText(lines[l])
			}

		} else if line == "" {

			if pointer == nil {
				// Do Nothing
			} else if pointer.Type == "pre" {
				// Do Nothing
			} else if pointer.Type == "p" {
				element := NewElement("#text")
				element.SetText("")
				document.AddElement(element)
			}

		} else if strings.HasPrefix(line, "![") && strings.Contains(line, "](") && strings.HasSuffix(line, ")") {

			text := line[2:strings.Index(line, "](")]
			href := line[strings.Index(line, "](")+2 : strings.Index(line, ")")]

			element := NewElement("img")
			element.SetAttribute("alt", text)
			element.SetAttribute("src", href)
			document.AddElement(element)

		} else if len(line) > 3 && strings.HasPrefix(line, "```") {

			if pointer == nil || pointer.Type != "pre" {
				element := NewElement("pre")
				element.SetAttribute("class", strings.TrimSpace(line[3:]))
				document.AddElement(element)
			}

		} else if strings.HasPrefix(line, "####") {

			element := NewElement("h4")
			element.SetChildren(parseInlineElements(strings.TrimSpace(line[4:])))
			document.AddElement(element)

		} else if strings.HasPrefix(line, "###") {

			element := NewElement("h3")
			element.SetChildren(parseInlineElements(strings.TrimSpace(line[3:])))
			document.AddElement(element)

		} else if strings.HasPrefix(line, "##") {

			element := NewElement("h2")
			element.SetChildren(parseInlineElements(strings.TrimSpace(line[2:])))
			document.AddElement(element)

		} else if strings.HasPrefix(line, "#") {

			element := NewElement("h1")
			element.SetChildren(parseInlineElements(strings.TrimSpace(line[1:])))
			document.AddElement(element)

		} else if regexp_ul.MatchString(line) {

			if pointer == nil || pointer.Type != "ul" {
				element := NewElement("ul")
				document.AddElement(element)
				pointer = document.GetLastElement()
			}

			item := NewElement("li")
			item.SetChildren(parseInlineElements(strings.TrimSpace(line[2:])))
			pointer.AddChild(item)

		} else if regexp_ol.MatchString(line) {

			if pointer == nil || pointer.Type != "ol" {
				element := NewElement("ol")
				document.AddElement(element)
				pointer = document.GetLastElement()
			}

			item := NewElement("li")
			item.SetChildren(parseInlineElements(strings.TrimSpace(line[2:])))
			pointer.AddChild(item)

		} else if line != "" {

			if pointer == nil {
				element := NewElement("p")
				element.AddChildren(parseInlineElements(strings.TrimSpace(line)))
				document.AddElement(element)
			} else if pointer.Type == "p" {
				pointer.AddChildren(parseInlineElements(strings.TrimSpace(line)))
			} else {
				element := NewElement("p")
				element.AddChildren(parseInlineElements(strings.TrimSpace(line)))
				document.AddElement(element)
			}

		}

	}

}

func (document *Document) Render() string {

	var result []string

	result = append(result, "<section>")

	for b := 0; b < len(document.Body); b++ {

		element := document.Body[b]

		if element.Type == "h1" {

			result = append(result, "</section>")
			result = append(result, "<section>")
			result = append(result, element.Render("\t"))

		} else if element.Type == "h2" {

			result = append(result, "</section>")
			result = append(result, "<section>")
			result = append(result, element.Render("\t"))

		} else if element.Type != "#text" {
			result = append(result, element.Render("\t"))
		}

	}

	result = append(result, "</section>")

	return strings.Join(result, "\n")

}

func (document *Document) SetCrux(value string) {
	document.Meta.Crux = strings.TrimSpace(value)
}

func (document *Document) SetDate(value string) {
	document.Meta.Date = strings.TrimSpace(value)
}

func (document *Document) SetName(value string) {
	document.Meta.Name = strings.TrimSpace(value)
}

func (document *Document) SetTags(values []string) {

	var filtered []string

	for v := 0; v < len(values); v++ {
		filtered = append(filtered, strings.TrimSpace(strings.ToLower(values[v])))
	}

	document.Meta.Tags = filtered

}

func (document *Document) SetType(values []string) {

	var filtered []string

	for v := 0; v < len(values); v++ {
		filtered = append(filtered, strings.TrimSpace(strings.ToLower(values[v])))
	}

	document.Meta.Type = filtered

}

func (document Document) String(indent string) string {

	var result []string

	result = append(result, indent+"<section>")

	for b := 0; b < len(document.Body); b++ {

		element := document.Body[b]

		if element.Type == "h1" {

			result = append(result, indent+"</section>")
			result = append(result, indent+"<section>")
			result = append(result, element.Render(indent+"\t"))

		} else if element.Type == "h2" {

			result = append(result, indent+"</section>")
			result = append(result, indent+"<section>")
			result = append(result, element.Render(indent+"\t"))

		} else if element.Type != "#text" {
			result = append(result, element.Render(indent+"\t"))
		}

	}

	result = append(result, indent+"</section>")

	return strings.Join(result, "\n")

}
