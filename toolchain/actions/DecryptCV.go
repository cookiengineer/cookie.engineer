package actions

import "cookie.engineer/console"
import "cookie.engineer/cvs"
import "os"
import "path/filepath"

func DecryptCV(folder string, password string, output string) bool {

	var result bool = false

	console.Group("actions/DecryptCV")

	filename := cvs.DeriveFilename(password)

	cwd, err0 := os.Getwd()

	if err0 == nil {

		prettyname, err1 := filepath.Rel(cwd, folder + "/" + filename)

		if err1 == nil {
			console.Log("Input:  " + prettyname)
			console.Log("Output: " + output)
		}

	} else {
		console.Log("Input:  " + folder + "/" + filename)
		console.Log("Output: " + output)
	}

	encrypted, err1 := os.ReadFile(folder + "/" + filename)

	if err1 == nil {

		buffer := cvs.Decrypt(encrypted, password)

		if len(buffer) > 0 {

			err2 := os.WriteFile(output, buffer, 0666)

			if err2 == nil {
				result = true
			}

		}

	}

	console.GroupEndResult(result, "actions/DecryptCV")

	return result

}
