package templates

import "strconv"

func RenderInteger(number int) string {
	return strconv.Itoa(number)
}
