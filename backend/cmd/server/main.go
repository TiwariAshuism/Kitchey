package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/ashutoshkumar/kitzz/internal/adapters/firebase"
	handler "github.com/ashutoshkumar/kitzz/internal/adapters/http"
	"github.com/ashutoshkumar/kitzz/internal/adapters/postgres"
	"github.com/ashutoshkumar/kitzz/internal/config"
	"github.com/ashutoshkumar/kitzz/internal/ports"
	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	gin.SetMode(cfg.GinMode)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Database
	pool, err := pgxpool.New(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer pool.Close()

	if err := pool.Ping(ctx); err != nil {
		log.Fatalf("Failed to ping database: %v", err)
	}
	log.Println("Connected to PostgreSQL")

	// Redis
	opts, err := redis.ParseURL(cfg.RedisURL)
	if err != nil {
		log.Fatalf("Failed to parse Redis URL: %v", err)
	}
	rdb := redis.NewClient(opts)
	defer rdb.Close()

	if err := rdb.Ping(ctx).Err(); err != nil {
		log.Printf("WARN: Redis not available, rate limiting disabled: %v", err)
		rdb = nil
	} else {
		log.Println("Connected to Redis")
	}

	// Firebase (FCM)
	fcmClient, err := firebase.NewFCMClient(ctx, cfg.FirebaseCredsFile)
	if err != nil {
		log.Printf("WARN: FCM not available: %v", err)
		fcmClient = &firebase.FCMClient{}
	}

	// Repositories
	userRepo := postgres.NewUserRepo(pool)
	deviceRepo := postgres.NewDeviceRepo(pool)
	messageRepo := postgres.NewMessageRepo(pool)
	subRepo := postgres.NewSubscriptionRepo(pool)

	// Services
	authService := ports.NewAuthService(userRepo, subRepo, cfg)
	messageService := ports.NewMessageService(messageRepo, deviceRepo, userRepo, subRepo, fcmClient)
	deviceService := ports.NewDeviceService(deviceRepo)
	replyRepo := postgres.NewReplyRepo(pool)
	replyService := ports.NewReplyService(replyRepo, deviceRepo)

	// HTTP Handlers
	authHandler := handler.NewAuthHandler(authService, userRepo)
	messageHandler := handler.NewMessageHandler(messageService)
	deviceHandler := handler.NewDeviceHandler(deviceService)
	oauthHandler := handler.NewOAuthHandler(authService, rdb, cfg)
	subHandler := handler.NewSubscriptionHandler(subRepo)
	replyHandler := handler.NewReplyHandler(replyService)

	// Router
	router := handler.NewRouter(
		authHandler,
		messageHandler,
		deviceHandler,
		oauthHandler,
		subHandler,
		replyHandler,
		authService,
		rdb,
		cfg.AlexaSkillURL,
	)

	// Server
	srv := &http.Server{
		Addr:         ":" + cfg.Port,
		Handler:      router,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 30 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Graceful shutdown
	go func() {
		sigCh := make(chan os.Signal, 1)
		signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
		<-sigCh

		log.Println("Shutting down server...")
		shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer shutdownCancel()

		if err := srv.Shutdown(shutdownCtx); err != nil {
			log.Fatalf("Server forced to shutdown: %v", err)
		}
	}()

	log.Printf("Server starting on :%s", cfg.Port)
	if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatalf("Server failed: %v", err)
	}

	log.Println("Server stopped")
}
