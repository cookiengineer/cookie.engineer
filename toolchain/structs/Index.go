package structs

import "sort"
import "time"

type Index struct {
	Documents []*Document `json:"documents"`
}

func NewIndex() Index {

	var index Index

	index.Documents = make([]*Document, 0)

	return index

}

func (index *Index) AddDocument(value Document) {

	var document = &value

	if document.IsValid() {
		document.Count()
		index.Documents = append(index.Documents, document)
	}

}

func (index *Index) Sort() {

	sort.Slice(index.Documents, func(a int, b int) bool {

		date_a, _ := time.Parse(time.DateOnly, index.Documents[a].Meta.Date)
		date_b, _ := time.Parse(time.DateOnly, index.Documents[b].Meta.Date)

		return date_a.After(date_b)

	})

}
