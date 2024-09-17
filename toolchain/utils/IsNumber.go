package utils

func IsNumber(value string) bool {

	var result bool = true

	for v := 0; v < len(value); v++ {

		character := string(value[v])

		if character >= "0" && character <= "9" {
			continue
		} else {
			result = false
			break
		}

	}

	return result

}
