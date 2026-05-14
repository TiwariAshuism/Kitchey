package ports

import (
	"context"
	"errors"
	"log"
	"time"

	"github.com/ashutoshkumar/kitzz/internal/domain"
	"github.com/google/uuid"
)

var (
	ErrSubscriptionExpired = errors.New("subscription expired")
	ErrDeviceNotPaired     = errors.New("device not paired to any user")
)

type NotificationSender interface {
	SendPush(ctx context.Context, fcmToken string, title string, body string, data map[string]string) error
}

type MessageService struct {
	messageRepo domain.MessageRepository
	deviceRepo  domain.DeviceRepository
	userRepo    domain.UserRepository
	subRepo     domain.SubscriptionRepository
	notifier    NotificationSender
}

func NewMessageService(
	messageRepo domain.MessageRepository,
	deviceRepo domain.DeviceRepository,
	userRepo domain.UserRepository,
	subRepo domain.SubscriptionRepository,
	notifier NotificationSender,
) *MessageService {
	return &MessageService{
		messageRepo: messageRepo,
		deviceRepo:  deviceRepo,
		userRepo:    userRepo,
		subRepo:     subRepo,
		notifier:    notifier,
	}
}

func (s *MessageService) HandleIncoming(ctx context.Context, alexaDeviceID string, transcript string, senderUserID uuid.UUID) ([]uuid.UUID, error) {
	// Check sender's subscription
	sub, err := s.subRepo.GetByUserID(ctx, senderUserID)
	if err != nil {
		return nil, ErrSubscriptionExpired
	}
	if !sub.IsValid() {
		return nil, ErrSubscriptionExpired
	}

	// Find all recipients paired to this device
	pairings, err := s.deviceRepo.GetByAlexaDeviceID(ctx, alexaDeviceID)
	if err != nil {
		log.Printf("[incoming] GetByAlexaDeviceID error: %v (alexa_device_id_len=%d)", err, len(alexaDeviceID))
		// Don't fail — treat as empty list and auto-pair below
		pairings = nil
	}

	// Find the sender's pairing for this device
	var senderPairing *domain.DevicePairing
	for i, p := range pairings {
		if p.UserID == senderUserID {
			senderPairing = &pairings[i]
			break
		}
	}

	// Auto-pair: if the authenticated user has no pairing for this Alexa device,
	// create one automatically. This eliminates the manual copy-paste-device-id
	// step that was the #1 user friction point.
	if senderPairing == nil {
		log.Printf("[incoming] auto-pairing: user_id=%s alexa_device_id_len=%d", senderUserID, len(alexaDeviceID))
		newPairing := &domain.DevicePairing{
			ID:             uuid.New(),
			AlexaDeviceID:  alexaDeviceID,
			UserID:         senderUserID,
			DeviceNickname: "Kitchen Echo",
			CreatedAt:      time.Now(),
		}
		if err := s.deviceRepo.Create(ctx, newPairing); err != nil {
			log.Printf("[incoming] auto-pair Create failed: %v", err)
			return nil, ErrDeviceNotPaired
		}
		senderPairing = newPairing
		pairings = append(pairings, *newPairing)
		log.Printf("[incoming] auto-paired device_pairing_id=%s for user_id=%s", newPairing.ID, senderUserID)
	}

	var messageIDs []uuid.UUID

	othersPaired := 0
	for _, p := range pairings {
		if p.UserID != senderUserID {
			othersPaired++
		}
	}

	for _, pairing := range pairings {
		// Don't send to self when other family members share this Echo.
		if pairing.UserID == senderUserID {
			continue
		}

		msg := &domain.Message{
			ID:              uuid.New(),
			SenderDeviceID:  senderPairing.ID,
			RecipientUserID: pairing.UserID,
			Transcript:      transcript,
			CreatedAt:       time.Now(),
		}

		if err := s.messageRepo.Create(ctx, msg); err != nil {
			continue
		}
		messageIDs = append(messageIDs, msg.ID)

		// Send push notification
		recipient, err := s.userRepo.GetByID(ctx, pairing.UserID)
		if err != nil || recipient.FCMToken == nil {
			continue
		}

		preview := transcript
		if len(preview) > 100 {
			preview = preview[:100] + "..."
		}

		if err := s.notifier.SendPush(ctx, *recipient.FCMToken,
			"New message from "+senderPairing.DeviceNickname,
			preview,
			map[string]string{"message_id": msg.ID.String()},
		); err != nil {
			log.Printf("FCM SendPush failed for user %s: %v", pairing.UserID, err)
		}
	}

	// Solo household: only the speaker is paired to this Echo. The loop above
	// skips the sender, so no rows would be created — still save one message and
	// push FCM to the same user (Alexa → backend → phone, per MVP testing).
	if len(messageIDs) == 0 && othersPaired == 0 && senderPairing != nil {
		log.Printf("[incoming] solo household: inbox + FCM for user_id=%s", senderUserID)
		msg := &domain.Message{
			ID:              uuid.New(),
			SenderDeviceID:  senderPairing.ID,
			RecipientUserID: senderUserID,
			Transcript:      transcript,
			CreatedAt:       time.Now(),
		}
		if err := s.messageRepo.Create(ctx, msg); err != nil {
			log.Printf("[incoming] solo Create failed: %v", err)
			return messageIDs, nil
		}
		messageIDs = append(messageIDs, msg.ID)

		recipient, err := s.userRepo.GetByID(ctx, senderUserID)
		if err != nil || recipient.FCMToken == nil {
			return messageIDs, nil
		}
		preview := transcript
		if len(preview) > 100 {
			preview = preview[:100] + "..."
		}
		if err := s.notifier.SendPush(ctx, *recipient.FCMToken,
			"Message from your "+senderPairing.DeviceNickname,
			preview,
			map[string]string{"message_id": msg.ID.String()},
		); err != nil {
			log.Printf("FCM SendPush failed (solo) for user %s: %v", senderUserID, err)
		}
	}

	return messageIDs, nil
}

func (s *MessageService) ListMessages(ctx context.Context, userID uuid.UUID, cursor *time.Time, limit int) ([]domain.Message, error) {
	return s.messageRepo.ListByRecipient(ctx, userID, cursor, limit)
}

func (s *MessageService) GetMessage(ctx context.Context, msgID uuid.UUID, userID uuid.UUID) (*domain.Message, error) {
	return s.messageRepo.GetByID(ctx, msgID, userID)
}

func (s *MessageService) MarkRead(ctx context.Context, msgID uuid.UUID, userID uuid.UUID) error {
	return s.messageRepo.MarkRead(ctx, msgID, userID)
}

func (s *MessageService) SoftDelete(ctx context.Context, msgID uuid.UUID, userID uuid.UUID) error {
	return s.messageRepo.SoftDelete(ctx, msgID, userID)
}
