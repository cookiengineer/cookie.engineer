package actions

import "cookie.engineer/console"
import "cookie.engineer/cvs"
import "os"
import "path/filepath"

func EncryptCV(folder string, password string, input string) bool {

	var result bool = false

	console.Group("actions/EncryptCV")

	filename := cvs.DeriveFilename(password)

	cwd, err0 := os.Getwd()

	if err0 == nil {

		prettyname, err1 := filepath.Rel(cwd, folder + "/" + filename)

		if err1 == nil {
			console.Log("Input:  " + input)
			console.Log("Output: " + prettyname)
		}

	} else {
		console.Log("Input:  " + input)
		console.Log("Output: " + folder + "/" + filename)
	}

	buffer, err1 := os.ReadFile(input)

	if err1 == nil {

		encrypted := cvs.Encrypt(buffer, password)

		if len(encrypted) > 0 {

			err2 := os.WriteFile(folder + "/" + filename, encrypted, 0666)

			if err2 == nil {
				result = true
			}

		}

	}

	console.GroupEndResult(result, "actions/EncryptCV")

	return result

}
