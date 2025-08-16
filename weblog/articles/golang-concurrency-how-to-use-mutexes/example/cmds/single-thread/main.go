// cmds/single-thread/main.go
package main

import "example"
import "fmt"

func main() {

	database := example.NewDatabase()

	database.Write("user1", example.Entry{
		Name: "Alice",
	})

	entry1 := database.Read("user1")

	fmt.Println("Read user1:", entry1.Name)

}
