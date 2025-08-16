// cmds/multi-thread-with-mutex/main.go
package main

import "example"
import "sync"
import "fmt"

func main() {

	database        := example.NewDatabaseWithMutex()
	waitgroup_read  := sync.WaitGroup{}
	waitgroup_write := sync.WaitGroup{}

	// Start 100 Write threads
	for i := 0; i < 100; i++ {

		waitgroup_write.Add(1)

		go func(i int) {

			defer waitgroup_write.Done()

			key  := fmt.Sprintf("user%d", i)
			name := fmt.Sprintf("Name%d", i)

			database.Write(key, example.Entry{
				Name: name,
			})

		}(i)

	}

	waitgroup_write.Wait()

	// Start 100 Read threads
	for i := 0; i < 100; i++ {

		waitgroup_read.Add(1)

		go func(i int) {

			defer waitgroup_read.Done()

			key   := fmt.Sprintf("user%d", i)
			entry := database.Read(key)

			if entry != nil {
				fmt.Println("Read %s: %s", key, entry.Name)
			}

		}(i)

	}

	waitgroup_read.Wait()

}
