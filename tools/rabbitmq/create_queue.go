package main

import (
	"log"
)

func main() {
	conn, ch, err := connect()
	if err != nil {
		log.Panic(err)
	}
	defer conn.Close()
	defer ch.Close()

	q, err := createQueue(ch)
	if err != nil {
		log.Panic(err)
	}
	log.Printf("Queue created: %s", q.Name)
}
