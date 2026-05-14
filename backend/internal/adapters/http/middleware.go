package http

import (
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/ashutoshkumar/kitzz/internal/ports"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
)

func AuthMiddleware(authService *ports.AuthService) gin.HandlerFunc {
	return func(c *gin.Context) {
		path := c.FullPath()
		if path == "" {
			path = c.Request.URL.Path
		}
		client := c.ClientIP()
		authDebug := os.Getenv("AUTH_DEBUG") == "1" || os.Getenv("AUTH_DEBUG") == "true"

		header := c.GetHeader("Authorization")
		if header == "" {
			log.Printf("[auth] %s %s client=%s: missing Authorization header",
				c.Request.Method, path, client)
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "missing authorization header"})
			return
		}

		if authDebug {
			log.Printf("[auth] %s %s client=%s: Authorization length=%d prefix=%q",
				c.Request.Method, path, client, len(header), authHeaderPrefix(header, 32))
		}

		parts := strings.SplitN(header, " ", 2)
		if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
			log.Printf("[auth] %s %s client=%s: invalid format (want \"Bearer <token>\", got prefix=%q)",
				c.Request.Method, path, client, authHeaderPrefix(header, 20))
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "invalid authorization format"})
			return
		}

		rawToken := parts[1]
		if authDebug {
			log.Printf("[auth] %s %s client=%s: bearer token len=%d prefix=%q",
				c.Request.Method, path, client, len(rawToken), authHeaderPrefix(rawToken, 24))
		}

		userID, err := authService.ValidateAccessToken(rawToken)
		if err != nil {
			hint := ""
			if !strings.HasPrefix(rawToken, "eyJ") && strings.Contains(rawToken, ":") {
				hint = " (token looks like pre-fix Alexa placeholder — disable skill link and link again after server update)"
			}
			log.Printf("[auth] %s %s client=%s: JWT invalid or expired: %v (bearer_len=%d prefix=%q)%s",
				c.Request.Method, path, client, err, len(rawToken), authHeaderPrefix(rawToken, 16), hint)
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "invalid or expired token"})
			return
		}

		if authDebug {
			log.Printf("[auth] %s %s client=%s: ok user_id=%s", c.Request.Method, path, client, userID)
		}

		c.Set("user_id", userID)
		c.Next()
	}
}

// authHeaderPrefix returns a short prefix for logs (never log full secrets).
func authHeaderPrefix(s string, max int) string {
	if max <= 0 || s == "" {
		return ""
	}
	if len(s) <= max {
		return s
	}
	return s[:max] + "…"
}

func RateLimitMiddleware(rdb *redis.Client, maxRequests int, window time.Duration) gin.HandlerFunc {
	return func(c *gin.Context) {
		if rdb == nil {
			c.Next()
			return
		}

		key := "rate:" + c.ClientIP()
		// Use device_id for message endpoints
		if deviceID := c.GetHeader("X-Device-ID"); deviceID != "" {
			key = "rate:device:" + deviceID
		}

		ctx := c.Request.Context()
		count, err := rdb.Incr(ctx, key).Result()
		if err != nil {
			c.Next()
			return
		}

		if count == 1 {
			rdb.Expire(ctx, key, window)
		}

		if count > int64(maxRequests) {
			c.AbortWithStatusJSON(http.StatusTooManyRequests, gin.H{"error": "rate limit exceeded"})
			return
		}

		c.Next()
	}
}

func CORSMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Origin, Content-Type, Authorization, X-Device-ID")
		c.Header("Access-Control-Max-Age", "86400")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}

		c.Next()
	}
}

func SecurityHeaders() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Header("X-Content-Type-Options", "nosniff")
		c.Header("X-Frame-Options", "DENY")
		c.Header("X-XSS-Protection", "1; mode=block")
		c.Header("Referrer-Policy", "strict-origin-when-cross-origin")
		c.Next()
	}
}

func GetUserID(c *gin.Context) uuid.UUID {
	val, exists := c.Get("user_id")
	if !exists {
		return uuid.Nil
	}
	uid, ok := val.(uuid.UUID)
	if !ok {
		return uuid.Nil
	}
	return uid
}
