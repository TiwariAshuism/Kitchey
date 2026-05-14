package postgres

import (
	"context"

	"github.com/ashutoshkumar/kitzz/internal/domain"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type ReplyRepo struct {
	pool *pgxpool.Pool
}

func NewReplyRepo(pool *pgxpool.Pool) *ReplyRepo {
	return &ReplyRepo{pool: pool}
}

func (r *ReplyRepo) Create(ctx context.Context, reply *domain.Reply) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO replies (id, sender_user_id, target_device_id, text_content, created_at)
		 VALUES ($1, $2, $3, $4, $5)`,
		reply.ID, reply.SenderUserID, reply.TargetDeviceID, reply.TextContent, reply.CreatedAt,
	)
	return err
}

func (r *ReplyRepo) GetPendingByDeviceID(ctx context.Context, alexaDeviceID string) ([]domain.Reply, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT r.id, r.sender_user_id, r.target_device_id, r.text_content, r.created_at,
		        COALESCE(u.name, 'Someone')
		 FROM replies r
		 JOIN device_pairings d ON d.id = r.target_device_id
		 JOIN users u ON u.id = r.sender_user_id
		 WHERE d.alexa_device_id = $1 AND r.delivered_at IS NULL
		 ORDER BY r.created_at ASC`, alexaDeviceID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var replies []domain.Reply
	for rows.Next() {
		var rpl domain.Reply
		if err := rows.Scan(&rpl.ID, &rpl.SenderUserID, &rpl.TargetDeviceID, &rpl.TextContent, &rpl.CreatedAt, &rpl.SenderName); err != nil {
			return nil, err
		}
		replies = append(replies, rpl)
	}
	return replies, rows.Err()
}

func (r *ReplyRepo) MarkDelivered(ctx context.Context, ids []uuid.UUID) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE replies SET delivered_at = NOW() WHERE id = ANY($1)`, ids,
	)
	return err
}

func (r *ReplyRepo) ListBySender(ctx context.Context, userID uuid.UUID, limit int) ([]domain.Reply, error) {
	if limit <= 0 || limit > 50 {
		limit = 20
	}
	rows, err := r.pool.Query(ctx,
		`SELECT r.id, r.sender_user_id, r.target_device_id, r.text_content, r.delivered_at, r.created_at,
		        COALESCE(d.device_nickname, 'Unknown')
		 FROM replies r
		 JOIN device_pairings d ON d.id = r.target_device_id
		 WHERE r.sender_user_id = $1
		 ORDER BY r.created_at DESC LIMIT $2`, userID, limit,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var replies []domain.Reply
	for rows.Next() {
		var rpl domain.Reply
		if err := rows.Scan(&rpl.ID, &rpl.SenderUserID, &rpl.TargetDeviceID, &rpl.TextContent, &rpl.DeliveredAt, &rpl.CreatedAt, &rpl.SenderName); err != nil {
			return nil, err
		}
		replies = append(replies, rpl)
	}
	return replies, rows.Err()
}
