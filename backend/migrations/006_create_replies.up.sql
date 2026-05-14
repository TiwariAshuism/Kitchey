-- 006_create_replies.up.sql
CREATE TABLE replies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sender_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    target_device_id UUID NOT NULL REFERENCES device_pairings(id) ON DELETE CASCADE,
    text_content TEXT NOT NULL,
    delivered_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_replies_target_device ON replies(target_device_id, delivered_at);
CREATE INDEX idx_replies_sender ON replies(sender_user_id);
