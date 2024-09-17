package structs

import "sort"
import "time"

type Feed struct {
	Date      string      `json:"date"`
	Documents []*Document `json:"documents"`
}

func NewFeed() Feed {

	var feed Feed

	feed.Date = "Sat, 01 Jan 2000 00:00:00 UTC"
	feed.Documents = make([]*Document, 0)

	return feed

}

func (feed *Feed) AddDocument(value Document) {

	var document = &value

	if document.IsValid() {

		if document.Meta.Date != "" {

			date, _ := time.Parse(time.DateOnly, document.Meta.Date)
			feed_date, _ := time.Parse(time.RFC1123, feed.Date)

			if date.After(feed_date) {
				feed.Date = date.Format(time.RFC1123)
			}

			document.Meta.Date = date.Format(time.RFC1123)

		}

		feed.Documents = append(feed.Documents, document)

	}

}

func (feed *Feed) Sort() {

	sort.Slice(feed.Documents, func(a int, b int) bool {

		date_a, _ := time.Parse(time.RFC1123, feed.Documents[a].Meta.Date)
		date_b, _ := time.Parse(time.RFC1123, feed.Documents[b].Meta.Date)

		return date_a.After(date_b)

	})

}
