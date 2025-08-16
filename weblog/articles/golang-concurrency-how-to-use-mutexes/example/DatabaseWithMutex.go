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
