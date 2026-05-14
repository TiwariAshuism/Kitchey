package domain

import (
	"context"
	"time"

	"github.com/google/uuid"
)

type Message struct {
	ID              uuid.UUID  `json:"id"`
	SenderDeviceID  uuid.UUID  `json:"sender_device_id"`
	RecipientUserID uuid.UUID  `json:"recipient_user_id"`
	Transcript      string     `json:"transcript"`
	ReadAt          *time.Time `json:"read_at,omitempty"`
	DeletedAt       *time.Time `json:"-"`
	CreatedAt       time.Time  `json:"created_at"`
	// Joined fields (not stored directly)
	SenderNickname string `json:"sender_nickname,omitempty"`
}

type MessageRepository interface {
	Create(ctx context.Context, msg *Message) error
	GetByID(ctx context.Context, id uuid.UUID, userID uuid.UUID) (*Message, error)
	ListByRecipient(ctx context.Context, userID uuid.UUID, cursor *time.Time, limit int) ([]Message, error)
	MarkRead(ctx context.Context, id uuid.UUID, userID uuid.UUID) error
	SoftDelete(ctx context.Context, id uuid.UUID, userID uuid.UUID) error
	DeleteByUserID(ctx context.Context, userID uuid.UUID) error
}
