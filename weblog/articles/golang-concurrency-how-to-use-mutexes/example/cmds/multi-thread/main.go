// cmds/multi-thread/main.go
package main

import "example"
import "sync"
import "fmt"

func main() {

	database  := example.NewDatabase()
	waitgroup := sync.WaitGroup{}

	// Start 100 Write threads
	for i := 0; i < 100; i++ {

		waitgroup.Add(1)

		go func(i int) {

			defer waitgroup.Done()

			key  := fmt.Sprintf("user%d", i)
			name := fmt.Sprintf("Name%d", i)

			database.Write(key, example.Entry{
				Name: name,
			})

		}(i)

	}

	// Start 100 Read threads
	for i := 0; i < 100; i++ {

		waitgroup.Add(1)

		go func(i int) {

			defer waitgroup.Done()

			key   := fmt.Sprintf("user%d", i)
			entry := database.Read(key)

			if entry != nil {
				fmt.Println("Read %s: %s", key, entry.Name)
			}

		}(i)

	}

	waitgroup.Wait()

}
