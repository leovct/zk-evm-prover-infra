package main

import (
	"context"
	"log"
	"time"
)

func main() {
	conn, ch, err := connect()
	if err != nil {
		log.Panic(err)
	}
	defer conn.Close()
	defer ch.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	numMsgsSent, err := send(ctx, ch, queueName, 100)
	if err != nil {
		log.Panic(err)
	}
	log.Printf("Messages sent: %d", numMsgsSent)
}
