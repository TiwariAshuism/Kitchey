package postgres

import (
	"context"
	"time"

	"github.com/ashutoshkumar/kitzz/internal/domain"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type MessageRepo struct {
	pool *pgxpool.Pool
}

func NewMessageRepo(pool *pgxpool.Pool) *MessageRepo {
	return &MessageRepo{pool: pool}
}

func (r *MessageRepo) Create(ctx context.Context, msg *domain.Message) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO messages (id, sender_device_id, recipient_user_id, transcript, created_at)
		 VALUES ($1, $2, $3, $4, $5)`,
		msg.ID, msg.SenderDeviceID, msg.RecipientUserID, msg.Transcript, msg.CreatedAt,
	)
	return err
}

func (r *MessageRepo) GetByID(ctx context.Context, id uuid.UUID, userID uuid.UUID) (*domain.Message, error) {
	msg := &domain.Message{}
	err := r.pool.QueryRow(ctx,
		`SELECT m.id, m.sender_device_id, m.recipient_user_id, m.transcript, m.read_at, m.created_at,
		        COALESCE(d.device_nickname, 'Unknown')
		 FROM messages m
		 LEFT JOIN device_pairings d ON d.id = m.sender_device_id
		 WHERE m.id = $1 AND m.recipient_user_id = $2 AND m.deleted_at IS NULL`, id, userID,
	).Scan(&msg.ID, &msg.SenderDeviceID, &msg.RecipientUserID, &msg.Transcript, &msg.ReadAt, &msg.CreatedAt, &msg.SenderNickname)
	if err != nil {
		return nil, err
	}
	return msg, nil
}

func (r *MessageRepo) ListByRecipient(ctx context.Context, userID uuid.UUID, cursor *time.Time, limit int) ([]domain.Message, error) {
	if limit <= 0 || limit > 50 {
		limit = 20
	}

	var args []interface{}
	query := `SELECT m.id, m.sender_device_id, m.recipient_user_id, m.transcript, m.read_at, m.created_at,
	                 COALESCE(d.device_nickname, 'Unknown')
	          FROM messages m
	          LEFT JOIN device_pairings d ON d.id = m.sender_device_id
	          WHERE m.recipient_user_id = $1 AND m.deleted_at IS NULL`
	args = append(args, userID)

	if cursor != nil {
		query += ` AND m.created_at < $2 ORDER BY m.created_at DESC LIMIT $3`
		args = append(args, *cursor, limit)
	} else {
		query += ` ORDER BY m.created_at DESC LIMIT $2`
		args = append(args, limit)
	}

	rows, err := r.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var messages []domain.Message
	for rows.Next() {
		var msg domain.Message
		if err := rows.Scan(&msg.ID, &msg.SenderDeviceID, &msg.RecipientUserID, &msg.Transcript, &msg.ReadAt, &msg.CreatedAt, &msg.SenderNickname); err != nil {
			return nil, err
		}
		messages = append(messages, msg)
	}
	return messages, rows.Err()
}

func (r *MessageRepo) MarkRead(ctx context.Context, id uuid.UUID, userID uuid.UUID) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE messages SET read_at = NOW() WHERE id = $1 AND recipient_user_id = $2 AND read_at IS NULL`,
		id, userID,
	)
	return err
}

func (r *MessageRepo) SoftDelete(ctx context.Context, id uuid.UUID, userID uuid.UUID) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE messages SET deleted_at = NOW() WHERE id = $1 AND recipient_user_id = $2`,
		id, userID,
	)
	return err
}

func (r *MessageRepo) DeleteByUserID(ctx context.Context, userID uuid.UUID) error {
	_, err := r.pool.Exec(ctx, `DELETE FROM messages WHERE recipient_user_id = $1`, userID)
	return err
}
