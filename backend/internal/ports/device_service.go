package ports

import (
	"context"
	"errors"
	"time"

	"github.com/ashutoshkumar/kitzz/internal/domain"
	"github.com/google/uuid"
)

var (
	ErrDeviceAlreadyPaired = errors.New("device already paired to this user")
)

type DeviceService struct {
	deviceRepo domain.DeviceRepository
}

func NewDeviceService(deviceRepo domain.DeviceRepository) *DeviceService {
	return &DeviceService{deviceRepo: deviceRepo}
}

func (s *DeviceService) PairDevice(ctx context.Context, userID uuid.UUID, alexaDeviceID, nickname string) (*domain.DevicePairing, error) {
	// Check if already paired
	existing, _ := s.deviceRepo.GetByAlexaDeviceID(ctx, alexaDeviceID)
	for _, p := range existing {
		if p.UserID == userID {
			return nil, ErrDeviceAlreadyPaired
		}
	}

	pairing := &domain.DevicePairing{
		ID:             uuid.New(),
		AlexaDeviceID:  alexaDeviceID,
		UserID:         userID,
		DeviceNickname: nickname,
		CreatedAt:      time.Now(),
	}

	if err := s.deviceRepo.Create(ctx, pairing); err != nil {
		return nil, err
	}

	return pairing, nil
}

func (s *DeviceService) ListDevices(ctx context.Context, userID uuid.UUID) ([]domain.DevicePairing, error) {
	return s.deviceRepo.GetByUserID(ctx, userID)
}

func (s *DeviceService) UnpairDevice(ctx context.Context, id uuid.UUID, userID uuid.UUID) error {
	return s.deviceRepo.Delete(ctx, id, userID)
}
