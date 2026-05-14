package postgres

import (
	"context"

	"github.com/ashutoshkumar/kitzz/internal/domain"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type SubscriptionRepo struct {
	pool *pgxpool.Pool
}

func NewSubscriptionRepo(pool *pgxpool.Pool) *SubscriptionRepo {
	return &SubscriptionRepo{pool: pool}
}

func (r *SubscriptionRepo) Create(ctx context.Context, sub *domain.Subscription) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO subscriptions (id, user_id, plan, status, expires_at, created_at, updated_at)
		 VALUES ($1, $2, $3, $4, $5, $6, $7)`,
		sub.ID, sub.UserID, sub.Plan, sub.Status, sub.ExpiresAt, sub.CreatedAt, sub.UpdatedAt,
	)
	return err
}

func (r *SubscriptionRepo) GetByUserID(ctx context.Context, userID uuid.UUID) (*domain.Subscription, error) {
	sub := &domain.Subscription{}
	err := r.pool.QueryRow(ctx,
		`SELECT id, user_id, plan, status, expires_at, created_at, updated_at
		 FROM subscriptions WHERE user_id = $1`, userID,
	).Scan(&sub.ID, &sub.UserID, &sub.Plan, &sub.Status, &sub.ExpiresAt, &sub.CreatedAt, &sub.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return sub, nil
}

func (r *SubscriptionRepo) Update(ctx context.Context, sub *domain.Subscription) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE subscriptions SET plan = $1, status = $2, expires_at = $3, updated_at = NOW()
		 WHERE id = $4`,
		sub.Plan, sub.Status, sub.ExpiresAt, sub.ID,
	)
	return err
}
