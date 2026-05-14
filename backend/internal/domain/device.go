package domain

import (
	"context"
	"time"

	"github.com/google/uuid"
)

type DevicePairing struct {
	ID             uuid.UUID `json:"id"`
	AlexaDeviceID  string    `json:"alexa_device_id"`
	UserID         uuid.UUID `json:"user_id"`
	DeviceNickname string    `json:"device_nickname"`
	CreatedAt      time.Time `json:"created_at"`
}

type DeviceRepository interface {
	Create(ctx context.Context, pairing *DevicePairing) error
	GetByID(ctx context.Context, id uuid.UUID) (*DevicePairing, error)
	GetByAlexaDeviceID(ctx context.Context, alexaDeviceID string) ([]DevicePairing, error)
	GetByUserID(ctx context.Context, userID uuid.UUID) ([]DevicePairing, error)
	Delete(ctx context.Context, id uuid.UUID, userID uuid.UUID) error
}
