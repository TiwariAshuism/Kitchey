package http

import (
	"time"

	"github.com/ashutoshkumar/kitzz/internal/ports"
	"github.com/gin-gonic/gin"
	"github.com/redis/go-redis/v9"
)

func NewRouter(
	authHandler *AuthHandler,
	messageHandler *MessageHandler,
	deviceHandler *DeviceHandler,
	oauthHandler *OAuthHandler,
	subHandler *SubscriptionHandler,
	replyHandler *ReplyHandler,
	authService *ports.AuthService,
	rdb *redis.Client,
	alexaSkillURL string,
) *gin.Engine {
	r := gin.New()
	r.Use(gin.Logger())
	r.Use(gin.Recovery())
	r.Use(CORSMiddleware())
	r.Use(SecurityHeaders())

	// Load HTML templates for OAuth
	r.LoadHTMLGlob("templates/*")

	// Root (browser default); API lives under /api and /oauth
	r.GET("/", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"service": "kitzz-api",
			"health":  "/health",
		})
	})

	// Health check
	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok"})
	})

	// OAuth2 endpoints (for Alexa account linking)
	oauth := r.Group("/oauth")
	{
		oauth.GET("/authorize", oauthHandler.Authorize)
		oauth.POST("/authorize", oauthHandler.AuthorizePost)
		oauth.POST("/token", oauthHandler.Token)
	}

	// Alexa skill reverse proxy. Lets a single ngrok tunnel expose both
	// the Go backend and the Node/Express Alexa skill server. Mount the
	// public Alexa skill endpoint as ``https://<ngrok-host>/alexa``.
	alexaProxy := NewAlexaSkillProxy(alexaSkillURL)
	r.Any("/alexa", alexaProxy)
	r.Any("/alexa/*path", alexaProxy)

	// Public auth endpoints
	auth := r.Group("/api/auth")
	auth.Use(RateLimitMiddleware(rdb, 10, time.Minute))
	{
		auth.POST("/register", authHandler.Register)
		auth.POST("/login", authHandler.Login)
		auth.POST("/refresh", authHandler.RefreshToken)
	}

	// Protected routes
	protected := r.Group("/api")
	protected.Use(AuthMiddleware(authService))
	{
		// Auth
		protected.PUT("/auth/fcm-token", authHandler.UpdateFCMToken)
		protected.DELETE("/auth/account", authHandler.DeleteAccount)

		// Messages
		protected.POST("/message/incoming", RateLimitMiddleware(rdb, 5, time.Minute), messageHandler.HandleIncoming)
		protected.GET("/messages", messageHandler.ListMessages)
		protected.GET("/messages/:id", messageHandler.GetMessage)
		protected.PUT("/messages/:id/read", messageHandler.MarkRead)
		protected.DELETE("/messages/:id", messageHandler.DeleteMessage)

		// Devices
		protected.POST("/devices/pair", deviceHandler.PairDevice)
		protected.GET("/devices", deviceHandler.ListDevices)
		protected.DELETE("/devices/:id", deviceHandler.UnpairDevice)

		// Subscription
		protected.GET("/subscription", subHandler.GetSubscription)

		// Replies (app → Alexa)
		protected.POST("/replies", replyHandler.SendReply)
		protected.GET("/replies", replyHandler.ListSentReplies)
		protected.GET("/replies/pending", replyHandler.GetPendingReplies)
		protected.PUT("/replies/delivered", replyHandler.MarkDelivered)
	}

	return r
}
