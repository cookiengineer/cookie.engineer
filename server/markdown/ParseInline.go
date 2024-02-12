package markdown

import "strings"

func ParseInline(value string) []Element {

	var result []Element

	var remaining = strings.TrimSpace(value)

	for len(remaining) > 0 {

		is_emoji := strings.HasPrefix(remaining, ":")
		is_img := strings.HasPrefix(remaining, "![") && strings.Contains(remaining, "](") && strings.Contains(remaining, ")")
		is_a := strings.HasPrefix(remaining, "[") && strings.Contains(remaining, "](") && strings.Contains(remaining, ")")
		is_b := strings.HasPrefix(remaining, "**")
		is_code := strings.HasPrefix(remaining, "`")
		is_em := strings.HasPrefix(remaining, "*")
		is_del := strings.HasPrefix(remaining, "~")

		if is_emoji {

			remaining = remaining[1:]

			if strings.Index(remaining, ":") != -1 {

				name := remaining[0:strings.Index(remaining, ":")]
				unicode, ok := Emojis[name]

				if ok == true {

					element := NewElement("#text")
					element.Text = " " + unicode + " "
					result = append(result, element)

				}

				remaining = remaining[strings.Index(remaining, ":")+1:]

			}

		} else if is_img {

			remaining = remaining[2:]

			text := remaining[0:strings.Index(remaining, "](")]
			href := remaining[strings.Index(remaining, "](")+2 : strings.Index(remaining, ")")]

			element := NewElement("img")
			element.SetAttribute("alt", text)
			element.SetAttribute("src", href)
			result = append(result, element)

			remaining = remaining[strings.Index(remaining, ")")+1:]

		} else if is_a {

			remaining = remaining[1:]

			text := remaining[0:strings.Index(remaining, "](")]
			href := remaining[strings.Index(remaining, "](")+2 : strings.Index(remaining, ")")]

			element := NewElement("a")
			element.SetText(text)
			element.SetAttribute("href", href)
			result = append(result, element)

			remaining = remaining[strings.Index(remaining, ")")+1:]

		} else if is_b {

			remaining = remaining[2:]

			if strings.Index(remaining, "**") != -1 {

				text := remaining[0:strings.Index(remaining, "**")]

				element := NewElement("b")
				element.SetText(text)
				result = append(result, element)

				remaining = remaining[strings.Index(remaining, "**")+2:]

			}

		} else if is_code {

			remaining = remaining[1:]

			if strings.Index(remaining, "`") != -1 {

				text := remaining[0:strings.Index(remaining, "`")]

				element := NewElement("code")
				element.SetText(text)
				result = append(result, element)

				remaining = remaining[strings.Index(remaining, "`")+1:]

			}

		} else if is_em {

			remaining = remaining[1:]

			if strings.Index(remaining, "*") != -1 {

				text := remaining[0:strings.Index(remaining, "*")]

				element := NewElement("em")
				element.SetText(text)
				result = append(result, element)

				remaining = remaining[strings.Index(remaining, "*")+1:]

			}

		} else if is_del {

			remaining = remaining[1:]

			if strings.Index(remaining, "~") != -1 {

				text := remaining[0:strings.Index(remaining, "~")]

				element := NewElement("del")
				element.SetText(text)
				result = append(result, element)

				remaining = remaining[strings.Index(remaining, "~")+1:]

			}

		} else {

			seek_emoji := strings.Index(remaining, ":")
			seek_img := strings.Index(remaining, "![")
			seek_a := strings.Index(remaining, "[")
			seek_b := strings.Index(remaining, "**")
			seek_code := strings.Index(remaining, "`")
			seek_em := strings.Index(remaining, "*")
			seek_del := strings.Index(remaining, "~")

			var seek int = len(remaining)

			if seek_emoji != -1 && seek_emoji < seek {
				seek = seek_emoji
			}

			if seek_img != -1 && seek_img < seek {
				seek = seek_img
			}

			if seek_a != -1 && seek_a < seek {
				seek = seek_a
			}

			if seek_b != -1 && seek_b < seek {
				seek = seek_b
			}

			if seek_code != -1 && seek_code < seek {
				seek = seek_code
			}

			if seek_em != -1 && seek_em < seek {
				seek = seek_em
			}

			if seek_del != -1 && seek_del < seek {
				seek = seek_del
			}

			if seek > 0 {

				element := NewElement("#text")
				element.SetText(remaining[0:seek])
				result = append(result, element)
				remaining = remaining[seek:]

			} else {
				break
			}

		}

	}

	return result

}
