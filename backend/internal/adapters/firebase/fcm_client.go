package firebase

import (
	"context"
	"log"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/messaging"
	"google.golang.org/api/option"
)

type FCMClient struct {
	client *messaging.Client
}

func NewFCMClient(ctx context.Context, credentialsFile string) (*FCMClient, error) {
	if credentialsFile == "" {
		log.Println("WARN: Firebase credentials file not set, FCM notifications disabled")
		return &FCMClient{}, nil
	}

	app, err := firebase.NewApp(ctx, nil, option.WithCredentialsFile(credentialsFile))
	if err != nil {
		return nil, err
	}

	client, err := app.Messaging(ctx)
	if err != nil {
		return nil, err
	}

	return &FCMClient{client: client}, nil
}

func (f *FCMClient) SendPush(ctx context.Context, fcmToken string, title string, body string, data map[string]string) error {
	if f.client == nil {
		log.Printf("FCM disabled, would send to %s: %s - %s", fcmToken, title, body)
		return nil
	}

	message := &messaging.Message{
		Token: fcmToken,
		Notification: &messaging.Notification{
			Title: title,
			Body:  body,
		},
		Data: data,
		Android: &messaging.AndroidConfig{
			Priority: "high",
		},
		APNS: &messaging.APNSConfig{
			Payload: &messaging.APNSPayload{
				Aps: &messaging.Aps{
					Sound: "default",
				},
			},
		},
	}

	_, err := f.client.Send(ctx, message)
	return err
}
