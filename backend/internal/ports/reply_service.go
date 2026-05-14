package ports

import (
	"context"
	"errors"
	"time"

	"github.com/ashutoshkumar/kitzz/internal/domain"
	"github.com/google/uuid"
)

var (
	ErrNoDevicesToReply = errors.New("no paired devices to reply to")
	ErrReplyTooLong     = errors.New("reply text too long")
)

type ReplyService struct {
	replyRepo  domain.ReplyRepository
	deviceRepo domain.DeviceRepository
}

func NewReplyService(replyRepo domain.ReplyRepository, deviceRepo domain.DeviceRepository) *ReplyService {
	return &ReplyService{replyRepo: replyRepo, deviceRepo: deviceRepo}
}

// SendReply sends a text reply from a user to a specific paired device (played on Alexa next time)
func (s *ReplyService) SendReply(ctx context.Context, senderUserID uuid.UUID, targetDeviceID uuid.UUID, text string) (*domain.Reply, error) {
	if len(text) > 500 {
		return nil, ErrReplyTooLong
	}

	// Verify the device belongs to this user
	device, err := s.deviceRepo.GetByID(ctx, targetDeviceID)
	if err != nil {
		return nil, ErrNoDevicesToReply
	}
	if device.UserID != senderUserID {
		return nil, ErrNoDevicesToReply
	}

	reply := &domain.Reply{
		ID:             uuid.New(),
		SenderUserID:   senderUserID,
		TargetDeviceID: targetDeviceID,
		TextContent:    text,
		CreatedAt:      time.Now(),
	}

	if err := s.replyRepo.Create(ctx, reply); err != nil {
		return nil, err
	}

	return reply, nil
}

// SendReplyToAllDevices sends a reply to all devices paired to the user
func (s *ReplyService) SendReplyToAllDevices(ctx context.Context, senderUserID uuid.UUID, text string) ([]domain.Reply, error) {
	if len(text) > 500 {
		return nil, ErrReplyTooLong
	}

	devices, err := s.deviceRepo.GetByUserID(ctx, senderUserID)
	if err != nil || len(devices) == 0 {
		return nil, ErrNoDevicesToReply
	}

	var replies []domain.Reply
	for _, device := range devices {
		reply := &domain.Reply{
			ID:             uuid.New(),
			SenderUserID:   senderUserID,
			TargetDeviceID: device.ID,
			TextContent:    text,
			CreatedAt:      time.Now(),
		}
		if err := s.replyRepo.Create(ctx, reply); err != nil {
			continue
		}
		replies = append(replies, *reply)
	}

	return replies, nil
}

// GetPendingReplies returns undelivered replies for a given Alexa device (called by the skill)
func (s *ReplyService) GetPendingReplies(ctx context.Context, alexaDeviceID string) ([]domain.Reply, error) {
	return s.replyRepo.GetPendingByDeviceID(ctx, alexaDeviceID)
}

// MarkDelivered marks replies as read/played on Alexa
func (s *ReplyService) MarkDelivered(ctx context.Context, ids []uuid.UUID) error {
	return s.replyRepo.MarkDelivered(ctx, ids)
}

// ListSentReplies returns the user's sent replies
func (s *ReplyService) ListSentReplies(ctx context.Context, userID uuid.UUID, limit int) ([]domain.Reply, error) {
	return s.replyRepo.ListBySender(ctx, userID, limit)
}
