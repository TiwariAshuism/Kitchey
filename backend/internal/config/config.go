package config

import (
	"fmt"
	"os"
	"path/filepath"
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
	loadRepoRootDotenv()

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

// loadRepoRootDotenv loads a single .env next to docker-compose.yml (repo root),
// no matter whether the process cwd is backend/ or the repository root.
func loadRepoRootDotenv() {
	wd, err := os.Getwd()
	if err != nil {
		_ = godotenv.Load(".env")
		return
	}
	dir := wd
	for {
		compose := filepath.Join(dir, "docker-compose.yml")
		if fi, statErr := os.Stat(compose); statErr == nil && !fi.IsDir() {
			_ = godotenv.Load(filepath.Join(dir, ".env"))
			return
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			break
		}
		dir = parent
	}
	_ = godotenv.Load(".env")
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
