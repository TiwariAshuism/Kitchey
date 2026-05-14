package domain

import (
	"context"
	"time"

	"github.com/google/uuid"
)

type Reply struct {
	ID             uuid.UUID  `json:"id"`
	SenderUserID   uuid.UUID  `json:"sender_user_id"`
	TargetDeviceID uuid.UUID  `json:"target_device_id"`
	TextContent    string     `json:"text_content"`
	DeliveredAt    *time.Time `json:"delivered_at,omitempty"`
	CreatedAt      time.Time  `json:"created_at"`
	// Joined fields
	SenderName string `json:"sender_name,omitempty"`
}

type ReplyRepository interface {
	Create(ctx context.Context, reply *Reply) error
	GetPendingByDeviceID(ctx context.Context, alexaDeviceID string) ([]Reply, error)
	MarkDelivered(ctx context.Context, ids []uuid.UUID) error
	ListBySender(ctx context.Context, userID uuid.UUID, limit int) ([]Reply, error)
}
