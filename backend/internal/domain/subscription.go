package domain

import (
	"context"
	"time"

	"github.com/google/uuid"
)

type SubscriptionStatus string

const (
	StatusTrial   SubscriptionStatus = "trial"
	StatusActive  SubscriptionStatus = "active"
	StatusExpired SubscriptionStatus = "expired"
)

type Subscription struct {
	ID        uuid.UUID          `json:"id"`
	UserID    uuid.UUID          `json:"user_id"`
	Plan      string             `json:"plan"`
	Status    SubscriptionStatus `json:"status"`
	ExpiresAt time.Time          `json:"expires_at"`
	CreatedAt time.Time          `json:"created_at"`
	UpdatedAt time.Time          `json:"updated_at"`
}

func (s *Subscription) IsValid() bool {
	return (s.Status == StatusTrial || s.Status == StatusActive) && s.ExpiresAt.After(time.Now())
}

type SubscriptionRepository interface {
	Create(ctx context.Context, sub *Subscription) error
	GetByUserID(ctx context.Context, userID uuid.UUID) (*Subscription, error)
	Update(ctx context.Context, sub *Subscription) error
}
