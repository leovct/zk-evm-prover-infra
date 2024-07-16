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

	numMsgsRead, err := receive(ch, queueName, 20)
	if err != nil {
		log.Panic(err)
	}
	log.Printf("Messages read: %d", numMsgsRead)
}
