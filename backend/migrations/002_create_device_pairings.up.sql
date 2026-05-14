-- 002_create_device_pairings.up.sql
CREATE TABLE device_pairings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    alexa_device_id VARCHAR(255) NOT NULL,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_nickname VARCHAR(255) NOT NULL DEFAULT 'Kitchen',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(alexa_device_id, user_id)
);

CREATE INDEX idx_device_pairings_alexa_device_id ON device_pairings(alexa_device_id);
CREATE INDEX idx_device_pairings_user_id ON device_pairings(user_id);
