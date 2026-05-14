package config

import (
	"fmt"
	"os"
	"time"

	"github.com/joho/godotenv"
)

type Config struct {
	Port              string
	GinMode           string
	DatabaseURL       string
	RedisURL          string
	JWTSecret         string
	JWTAccessExpiry   time.Duration
	JWTRefreshExpiry  time.Duration
	FirebaseCredsFile string
	OAuthCodeTTL      time.Duration
	// AlexaSkillURL is the upstream base URL of the locally running
	// Node/Express Alexa skill server. When set, the Go backend exposes
	// a reverse proxy at ``/alexa`` that forwards every request to this
	// URL, allowing a single ngrok tunnel to serve both the OAuth/REST
	// endpoints and the Alexa custom skill endpoint.
	AlexaSkillURL string
}

func Load() (*Config, error) {
	_ = godotenv.Load() // ignore error if .env doesn't exist

	cfg := &Config{
		Port:              getEnv("PORT", "8080"),
		GinMode:           getEnv("GIN_MODE", "debug"),
		DatabaseURL:       os.Getenv("DATABASE_URL"),
		RedisURL:          getEnv("REDIS_URL", "redis://localhost:6379/0"),
		JWTSecret:         os.Getenv("JWT_SECRET"),
		FirebaseCredsFile: getEnv("FIREBASE_CREDENTIALS_FILE", ""),
		AlexaSkillURL:     getEnv("ALEXA_SKILL_URL", "http://localhost:3000"),
	}

	if cfg.DatabaseURL == "" {
		return nil, fmt.Errorf("DATABASE_URL is required")
	}
	if cfg.JWTSecret == "" {
		return nil, fmt.Errorf("JWT_SECRET is required")
	}

	var err error
	cfg.JWTAccessExpiry, err = time.ParseDuration(getEnv("JWT_ACCESS_EXPIRY", "15m"))
	if err != nil {
		return nil, fmt.Errorf("invalid JWT_ACCESS_EXPIRY: %w", err)
	}

	cfg.JWTRefreshExpiry, err = time.ParseDuration(getEnv("JWT_REFRESH_EXPIRY", "168h"))
	if err != nil {
		return nil, fmt.Errorf("invalid JWT_REFRESH_EXPIRY: %w", err)
	}

	cfg.OAuthCodeTTL = 10 * time.Minute

	return cfg, nil
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
