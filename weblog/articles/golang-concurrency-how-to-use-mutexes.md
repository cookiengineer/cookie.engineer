===
- date: 2025-08-01
- name: Golang Concurrency: How to use Mutexes
- tags: go, software, development
- type: software, legacy
- crux: Understanding the concurrency model behind Go's runtime and how to use Go's goroutines, and mutexes without read/write errors.
===

After refactoring some of my old codebases to account for usage
within goroutines, I decided it's probably best to manifest this
inside a thorough article about Go's concurrency model.

At first I got a little confused by the obscure error messages,
and it took a while how to use go's `map` data type safely. This
article aims to provide examples that break, so that you can
understand _why_ and _when_ to use the `sync.Mutex` or `sync.RWMutex`
abstractions.


## Simple Database Struct

Let's begin with a simple abstraction of an in-memory key-value store,
a `Database struct` that stores uniquely identifiable `Entry struct`
instances in a map.

```go
// Database.go
package example

type Entry struct {
	Name string `json:"name"`
	// ... additional properties
}

type Database struct {
	data map[string]*Entry `json:"-"`
}

func NewDatabase() *Database {
	return &Database{
		data: make(map[string]*Entry),
	}
}

func (database *Database) Read(key string) *Entry {

	var result *Entry = nil

	tmp, ok := database.data[key]

	if ok == true {
		result = tmp
	}

	return result

}

func (database *Database) Write(key string, entry Entry) bool {

	database.data[key] = &entry

	return true

}
```


## Single Thread, Zero Problems

If we use our Database implementation in a single thread, we won't have a problem
and everything works as expected.

```go
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
```


## Multiple Threads, Multiple Problems

If we however start to use goroutines for accessing the map entries, we'll get a
read/write access error when the same map entry is accessed by two different go
routines at the same time.

```go
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
```

The error typically looks like this, highlighting that a map was concurrently
being written from multiple goroutines at the same time. The stacktrace of the
error also includes the parent goroutines, which in our case is the main thread,
also known as `goroutine 1`.

```text
fatal error: concurrent map writes

goroutine 74 [running]:
internal/runtime/maps.fatal({0x4b9274?, 0x47178a?})
	/usr/lib/go/src/runtime/panic.go:1058 +0x18
example.(*Database).Write(...)
	/weblog/articles/golang-concurrency-how-to-use-mutexes/example/Database.go:35
main.main.func1(0x44)
	/weblog/articles/golang-concurrency-how-to-use-mutexes/example/cmds/multi-thread/main.go:24 +0x149
created by main.main in goroutine 1
	/weblog/articles/golang-concurrency-how-to-use-mutexes/example/cmds/multi-thread/main.go:17 +0x75

goroutine 1 [sync.WaitGroup.Wait]:
sync.runtime_SemacquireWaitGroup(0xc0000fc600?)
	/usr/lib/go/src/runtime/sema.go:110 +0x25
sync.(*WaitGroup).Wait(0x0?)
	/usr/lib/go/src/sync/waitgroup.go:118 +0x48
main.main()
	/weblog/articles/golang-concurrency-how-to-use-mutexes/example/cmds/multi-thread/main.go:52 +0x1f7
```


## Database with a Single Mutex

The easiest way to fix this is by using a `sync.Mutex` for the Database. This will
make goroutines wait when the `mutex.Lock()` method is being called, and they'll wait
until the blocking goroutine called the `mutex.Unlock()` method.

The problem with this, however, is that it's better to use a `sync.RWMutex` instead
to reflect read/write access separately. Read access can be parallelized much better
than Write access, meaning that only Write access will effectively block other goroutines
then. The methods on `sync.Mutex` and `sync.RWMutex` are a little confusing though.

| Method                   | Description                  |
|:-------------------------|:-----------------------------|
| `sync.Mutex.Lock()`      | Lock read and write access   |
| `sync.Mutex.Unlock()`    | Unlock read and write access |
| `sync.RWMutex.Lock()`    | Lock write access            |
| `sync.RWMutex.Unlock()`  | Unlock write access          |
| `sync.RWMutex.RLock()`   | Lock read access             |
| `sync.RWMutex.RUnlock()` | Unlock read access           |

Now we have to add the mutex usage to our new `DatabaseWithMutex` implementation.

```go
// DatabaseWithMutex.go
package example

import "sync"

type DatabaseWithMutex struct {
	data  map[string]*Entry `json:"-"`
	mutex *sync.RWMutex     `json:"-"`
}

func NewDatabaseWithMutex() *DatabaseWithMutex {
	return &DatabaseWithMutex{
		data: make(map[string]*Entry),
		mutex: &sync.RWMutex{},
	}
}

func (database *DatabaseWithMutex) Read(key string) *Entry {

	database.mutex.RLock()

	var result *Entry = nil

	tmp, ok := database.data[key]

	if ok == true {
		result = tmp
	}

	database.mutex.RUnlock()

	return result

}

func (database *DatabaseWithMutex) Write(key string, entry Entry) bool {

	database.mutex.Lock()

	database.data[key] = &entry

	database.mutex.Unlock()

	return true

}
```

Now we can use the different database in our `main.go` and we won't get race conditions
or pointer errors. We'll also change the code to use two different waitgroups, one for
writing all content to the Database and one for reading all content.

That's not really necessary, but it's a cleaner example code.

```go
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
```


## Database with Multiple Mutexes per Resource

The next step in the process is related to concurrent access of separated entities.

If you write code that uses multiple goroutines that can read/access separate entities
in parallel, it's best to have a structure where your Database actually uses separate
mutexes for each unique entity.

If you e.g. have a Database that serializes its data directly on-disk via `os.WriteFile()`,
you can protect the deserialized entities by using a separate `RWMutex` for each entity.
But we keep the `Database.mutex` to lock it when the map of mutexes changes.

```go
type Database struct {
	// mutexes per-entity
	mutexes map[string]*sync.Mutex
}

func toEntityMutex(database *Database, name string) *sync.Mutex {

	database.mutex.RLock()
	mutex, ok := database.mutexes[name]
	database.mutex.RUnlock()

	if ok == false {

		database.mutex.Lock()
		database.mutexes[name] = &sync.Mutex{}
		mutex = database.mutexes[name]
		database.mutex.Unlock()

	}

	return mutex

}
```

The little helper function above it makes things much easier and convenient to
use inside the publicly available methods. We can implement a borrowing memory
ownership model right into it, where the resource-specific mutex is locked on
`ReadEntity()` and unlocked again on `WriteEntity()`, so that all goroutines
can work in parallel on only one entity each, preventing corruption from
modifications through other goroutines.

```go
func (database *Database) ReadEntity(name string) *Entity {

	mutex := toEntityMutex(database, name)
	mutex.Lock()

	result := readEntity(database, name)

	return result

}

func (database *database) WriteEntity(name string, entity *Entity) bool {

	var result bool

	if entity != nil {

		result = writeEntity(database, name, entity)

		mutex := toEntityMutex(database, name)
		mutex.Unlock()

	}

	return result

}
```


## Further Optimizations with Atomics

If you want to optimize your code further and avoid cache misses when goroutines
are started on separate CPU cores, you can use the [sync/atomic](https://pkg.go.dev/sync/atomic)
package.

In a nutshell, atomics are the idea of using data structures in a guaranteed bitlength
manner. In the case of a hash map, the idea is to use hashed keys and data structures
that don't exceed the QuadWord (QW) length, so that cache misses can be avoided.

In JIT-optimized VMs, usually those kind of hashed map implementations actually don't
reference to the `struct` instances directly in memory, and rather are hashed maps of
the unique identifiers of object instances that point to the references to references.

This way, the GC can reoptimize unused memory and trace the node graph much easier
without having to worry about changing memory usage partitions, because the size of
the cells doesn't change over time.

In Go, there's also [xxhash](https://github.com/cespare/xxhash) which generates a `64bit`
long good-enough hash for the keys, with hopefully no collisions happening as that is
always a tradeoff of bit length vs uniqueness.

The [haxmap](https://github.com/alphadose/haxmap) implementation uses `xxhash` in
order to implement most data types as predefined maps using the generics syntax of
Go, in case you want to try it out. But, because of the bit length I mentioned earlier,
the `hashable` interface that haxmap relies on is pretty limited in terms of what
kind of data types can be hashed.


## Reference Implementation

The above implementations are available as a complete [project zip file](./golang-concurrency-how-to-use-mutexes/example.zip)
but all files are also available as separate downloads.

- [Database.go](./golang-concurrency-how-to-use-mutexes/example/Database.go)
- [DatabaseWithMutex.go](./golang-concurrency-how-to-use-mutexes/example/DatabaseWithMutex.go)
- [cmds/single-thread/main.go](./golang-concurrency-how-to-use-mutexes/example/cmds/single-thread/main.go)
- [cmds/multi-thread/main.go](./golang-concurrency-how-to-use-mutexes/example/cmds/multi-thread/main.go)
- [cmds/multi-thread-with-mutex/main.go](./golang-concurrency-how-to-use-mutexes/example/cmds/multi-thread-with-mutex/main.go)

