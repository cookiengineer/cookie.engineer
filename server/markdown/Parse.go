package markdown

import "os"

func Parse(file string) Document {

	var document Document

	buffer, err := os.ReadFile(file)

	if err == nil {
		document = NewDocument(file, string(buffer))
	}

	return document

}
