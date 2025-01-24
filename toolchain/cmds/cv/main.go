package main

import "cookie.engineer/console"
import "cookie.engineer/actions"
import "os"
import "strings"

func showHelp() {

	console.Info("")
	console.Info("CV Encrypter/Decrypter Tool")
	console.Info("")

	console.Group("Usage: [Action] [Password]")
	console.GroupEnd("-----")

	console.Group("Examples")
	console.Log("")
	console.Log("# Write decrypted CV to ../cv/source/DECRYPTED.cv")
	console.Log("cv decrypt \"password\";")
	console.Log("")
	console.Log("# Write encrypted CV to ../cv/source/<derived password>.cv")
	console.Log("cv encrypt \"password\";")
	console.Log("")
	console.GroupEnd("--------")

}

func main() {

	action := ""
	password := ""

	if len(os.Args) == 3 {

		if os.Args[1] == "encrypt" {

			if os.Args[2] != "" {
				action = "encrypt"
				password = os.Args[2]
			}

		} else if os.Args[1] == "decrypt" {

			if os.Args[2] != "" {
				action = "decrypt"
				password = os.Args[2]
			}

		}

	}

	cwd, err1 := os.Getwd()

	if err1 == nil {

		if strings.HasSuffix(cwd, "/toolchain") {
			cwd = cwd[0:len(cwd)-10]
		}

		if action == "encrypt" {

			result := actions.EncryptCV(cwd + "/cv/source", password, cwd + "/cv/source/DECRYPTED.cv")

			if result == true {
				os.Exit(0)
			} else {
				os.Exit(1)
			}

		} else if action == "decrypt" {

			result := actions.DecryptCV(cwd + "/cv/source", password, cwd + "/cv/source/DECRYPTED.cv")

			if result == true {
				os.Exit(0)
			} else {
				os.Exit(1)
			}

		} else {
			showHelp()
			os.Exit(1)
		}

	} else {
		showHelp()
		os.Exit(1)
	}

}
