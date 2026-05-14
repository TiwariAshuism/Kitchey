package postgres

import (
	"context"

	"github.com/ashutoshkumar/kitzz/internal/domain"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type DeviceRepo struct {
	pool *pgxpool.Pool
}

func NewDeviceRepo(pool *pgxpool.Pool) *DeviceRepo {
	return &DeviceRepo{pool: pool}
}

func (r *DeviceRepo) Create(ctx context.Context, pairing *domain.DevicePairing) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO device_pairings (id, alexa_device_id, user_id, device_nickname, created_at)
		 VALUES ($1, $2, $3, $4, $5)`,
		pairing.ID, pairing.AlexaDeviceID, pairing.UserID, pairing.DeviceNickname, pairing.CreatedAt,
	)
	return err
}

func (r *DeviceRepo) GetByID(ctx context.Context, id uuid.UUID) (*domain.DevicePairing, error) {
	p := &domain.DevicePairing{}
	err := r.pool.QueryRow(ctx,
		`SELECT id, alexa_device_id, user_id, device_nickname, created_at
		 FROM device_pairings WHERE id = $1`, id,
	).Scan(&p.ID, &p.AlexaDeviceID, &p.UserID, &p.DeviceNickname, &p.CreatedAt)
	if err != nil {
		return nil, err
	}
	return p, nil
}

func (r *DeviceRepo) GetByAlexaDeviceID(ctx context.Context, alexaDeviceID string) ([]domain.DevicePairing, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, alexa_device_id, user_id, device_nickname, created_at
		 FROM device_pairings WHERE alexa_device_id = $1`, alexaDeviceID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var pairings []domain.DevicePairing
	for rows.Next() {
		var p domain.DevicePairing
		if err := rows.Scan(&p.ID, &p.AlexaDeviceID, &p.UserID, &p.DeviceNickname, &p.CreatedAt); err != nil {
			return nil, err
		}
		pairings = append(pairings, p)
	}
	return pairings, rows.Err()
}

func (r *DeviceRepo) GetByUserID(ctx context.Context, userID uuid.UUID) ([]domain.DevicePairing, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, alexa_device_id, user_id, device_nickname, created_at
		 FROM device_pairings WHERE user_id = $1 ORDER BY created_at DESC`, userID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var pairings []domain.DevicePairing
	for rows.Next() {
		var p domain.DevicePairing
		if err := rows.Scan(&p.ID, &p.AlexaDeviceID, &p.UserID, &p.DeviceNickname, &p.CreatedAt); err != nil {
			return nil, err
		}
		pairings = append(pairings, p)
	}
	return pairings, rows.Err()
}

func (r *DeviceRepo) Delete(ctx context.Context, id uuid.UUID, userID uuid.UUID) error {
	_, err := r.pool.Exec(ctx,
		`DELETE FROM device_pairings WHERE id = $1 AND user_id = $2`, id, userID,
	)
	return err
}
