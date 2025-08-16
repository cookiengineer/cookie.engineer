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
