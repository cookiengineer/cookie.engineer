package templates

import "strings"

func RenderStrings(slice []string, separator string) string {
	return strings.Join(slice, separator)
}
