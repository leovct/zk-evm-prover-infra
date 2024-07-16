package main

import (
	"context"
	"errors"
	"fmt"
	"log"

	"github.com/rabbitmq/amqp091-go"
	amqp "github.com/rabbitmq/amqp091-go"
)

const (
	//username  = "default_user_gJ-UB0pu4PXapHTWdpW"
	username = "guest"
	// password  = "Ynumtrr4N8kLogVtGWSLsMJwxayCMcpb"
	password = "guest"
	hostname = "localhost"
	//hostname  = "test-rabbitmq-cluster.zero.svc.cluster.local"
	port      = 5672
	queueName = "hello"
	message   = "test-msg"
)

func connect() (*amqp.Connection, *amqp.Channel, error) {
	conn, err := amqp.Dial(fmt.Sprintf("amqp://%s:%s@%s:%d/", username, password, hostname, port))
	if err != nil {
		return nil, nil, fmt.Errorf("unable to connect to RabbitMQ", err)
	}
	log.Print("Connected to RabbitMQ")

	ch, err := conn.Channel()
	if err != nil {
		return nil, nil, fmt.Errorf("failed to open a channel", err)
	}
	log.Print("Channel opened")

	return conn, ch, nil
}

func createQueue(ch *amqp.Channel) (*amqp.Queue, error) {
	q, err := ch.QueueDeclare(
		queueName, // name
		false,     // durable
		false,     // delete when unused
		false,     // exclusive
		false,     // no-wait
		nil,       // arguments
	)
	if err != nil {
		return nil, fmt.Errorf("failed to declare a queue", err)
	}
	return &q, nil
}

func send(ctx context.Context, ch *amqp091.Channel, queueName string, n int) (int, error) {
	numMsgsSent := 0
	for i := 1; i <= n; i++ {
		if err := ch.PublishWithContext(ctx,
			"",        // exchange
			queueName, // routing key
			false,     // mandatory
			false,     // immediate
			amqp.Publishing{
				ContentType: "text/plain",
				Body:        []byte(message),
			}); err != nil {
			return numMsgsSent, fmt.Errorf("failed to publish a message", err)
		}
		numMsgsSent++
		//log.Printf("Message %d sent: %s", i+1, body)
	}
	return numMsgsSent, nil
}

func receive(ch *amqp091.Channel, queueName string, n int) (int, error) {
	numMsgsRead := 0
	for i := 1; i <= n; i++ {
		_, ok, err := ch.Get(queueName, true)
		if err != nil {
			return numMsgsRead, fmt.Errorf("failed to receive a delivery", err)
		}
		if !ok {
			return numMsgsRead, errors.New("the delivery went wrong")
		}
		numMsgsRead++
		//log.Printf("Message %d received: %s", i+1, d.Body)
	}
	return numMsgsRead, nil
}
