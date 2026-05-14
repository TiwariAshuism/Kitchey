package http

import (
	"crypto/rand"
	"encoding/hex"
	"net/http"

	"github.com/ashutoshkumar/kitzz/internal/config"
	"github.com/ashutoshkumar/kitzz/internal/ports"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
)

type OAuthHandler struct {
	authService *ports.AuthService
	rdb         *redis.Client
	cfg         *config.Config
}

func NewOAuthHandler(authService *ports.AuthService, rdb *redis.Client, cfg *config.Config) *OAuthHandler {
	return &OAuthHandler{authService: authService, rdb: rdb, cfg: cfg}
}

func (h *OAuthHandler) Authorize(c *gin.Context) {
	clientID := c.Query("client_id")
	redirectURI := c.Query("redirect_uri")
	state := c.Query("state")
	responseType := c.Query("response_type")

	if responseType != "code" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "unsupported response_type"})
		return
	}

	if clientID == "" || redirectURI == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "missing required parameters"})
		return
	}

	// For now, serve a simple login form. In production, this would be a proper web page.
	c.HTML(http.StatusOK, "oauth_login.html", gin.H{
		"client_id":    clientID,
		"redirect_uri": redirectURI,
		"state":        state,
	})
}

type oauthLoginRequest struct {
	Email       string `form:"email" binding:"required,email"`
	Password    string `form:"password" binding:"required"`
	ClientID    string `form:"client_id" binding:"required"`
	RedirectURI string `form:"redirect_uri" binding:"required"`
	State       string `form:"state"`
}

func (h *OAuthHandler) AuthorizePost(c *gin.Context) {
	var req oauthLoginRequest
	if err := c.ShouldBind(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	user, _, err := h.authService.Login(c.Request.Context(), req.Email, req.Password)
	if err != nil {
		c.HTML(http.StatusUnauthorized, "oauth_login.html", gin.H{
			"error":        "Invalid email or password",
			"client_id":    req.ClientID,
			"redirect_uri": req.RedirectURI,
			"state":        req.State,
		})
		return
	}

	// Generate auth code
	codeBytes := make([]byte, 32)
	if _, err := rand.Read(codeBytes); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to generate auth code"})
		return
	}
	code := hex.EncodeToString(codeBytes)

	// Store code → user_id mapping in Redis
	ctx := c.Request.Context()
	h.rdb.Set(ctx, "oauth:code:"+code, user.ID.String(), h.cfg.OAuthCodeTTL)
	h.rdb.Set(ctx, "oauth:redirect:"+code, req.RedirectURI, h.cfg.OAuthCodeTTL)

	// Redirect back to Alexa with auth code
	redirectURL := req.RedirectURI + "?code=" + code
	if req.State != "" {
		redirectURL += "&state=" + req.State
	}

	c.Redirect(http.StatusFound, redirectURL)
}

type tokenRequest struct {
	GrantType   string `form:"grant_type" binding:"required"`
	Code        string `form:"code"`
	RedirectURI string `form:"redirect_uri"`
}

func (h *OAuthHandler) Token(c *gin.Context) {
	var req tokenRequest
	if err := c.ShouldBind(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid_request"})
		return
	}

	if req.GrantType != "authorization_code" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "unsupported_grant_type"})
		return
	}

	ctx := c.Request.Context()

	// Look up auth code in Redis
	userIDStr, err := h.rdb.Get(ctx, "oauth:code:"+req.Code).Result()
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid_grant"})
		return
	}

	// Verify redirect URI matches
	storedRedirect, err := h.rdb.Get(ctx, "oauth:redirect:"+req.Code).Result()
	if err != nil || storedRedirect != req.RedirectURI {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid_grant"})
		return
	}

	// Delete the code (one-time use)
	h.rdb.Del(ctx, "oauth:code:"+req.Code, "oauth:redirect:"+req.Code)

	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid_grant"})
		return
	}

	pair, err := h.authService.IssueAlexaAccountLinkingTokens(userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to issue token"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"access_token":  pair.AccessToken,
		"token_type":    "Bearer",
		"expires_in":    pair.ExpiresIn,
		"refresh_token": pair.RefreshToken,
	})
}
