package ports

import (
	"context"
	"errors"
	"time"

	"github.com/ashutoshkumar/kitzz/internal/config"
	"github.com/ashutoshkumar/kitzz/internal/domain"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
)

var (
	ErrInvalidCredentials = errors.New("invalid credentials")
	ErrEmailTaken         = errors.New("email already registered")
	ErrUserNotFound       = errors.New("user not found")
	ErrInvalidToken       = errors.New("invalid token")
)

type TokenPair struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	ExpiresIn    int64  `json:"expires_in"`
}

type AuthService struct {
	userRepo domain.UserRepository
	subRepo  domain.SubscriptionRepository
	cfg      *config.Config
}

func NewAuthService(userRepo domain.UserRepository, subRepo domain.SubscriptionRepository, cfg *config.Config) *AuthService {
	return &AuthService{userRepo: userRepo, subRepo: subRepo, cfg: cfg}
}

func (s *AuthService) Register(ctx context.Context, name, email, password string) (*domain.User, *TokenPair, error) {
	existing, _ := s.userRepo.GetByEmail(ctx, email)
	if existing != nil {
		return nil, nil, ErrEmailTaken
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return nil, nil, err
	}

	user := &domain.User{
		ID:           uuid.New(),
		Email:        email,
		PasswordHash: string(hash),
		Name:         name,
		CreatedAt:    time.Now(),
		UpdatedAt:    time.Now(),
	}

	if err := s.userRepo.Create(ctx, user); err != nil {
		return nil, nil, err
	}

	// Create trial subscription (14 days)
	sub := &domain.Subscription{
		ID:        uuid.New(),
		UserID:    user.ID,
		Plan:      "free",
		Status:    domain.StatusTrial,
		ExpiresAt: time.Now().Add(14 * 24 * time.Hour),
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}
	if err := s.subRepo.Create(ctx, sub); err != nil {
		return nil, nil, err
	}

	tokens, err := s.generateTokens(user.ID)
	if err != nil {
		return nil, nil, err
	}

	return user, tokens, nil
}

func (s *AuthService) Login(ctx context.Context, email, password string) (*domain.User, *TokenPair, error) {
	user, err := s.userRepo.GetByEmail(ctx, email)
	if err != nil {
		return nil, nil, ErrInvalidCredentials
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(password)); err != nil {
		return nil, nil, ErrInvalidCredentials
	}

	tokens, err := s.generateTokens(user.ID)
	if err != nil {
		return nil, nil, err
	}

	return user, tokens, nil
}

func (s *AuthService) RefreshToken(ctx context.Context, refreshToken string) (*TokenPair, error) {
	claims, err := s.validateToken(refreshToken, "refresh")
	if err != nil {
		return nil, ErrInvalidToken
	}

	userID, err := uuid.Parse(claims.Subject)
	if err != nil {
		return nil, ErrInvalidToken
	}

	// Verify user still exists
	if _, err := s.userRepo.GetByID(ctx, userID); err != nil {
		return nil, ErrUserNotFound
	}

	return s.generateTokens(userID)
}

func (s *AuthService) ValidateAccessToken(tokenStr string) (uuid.UUID, error) {
	claims, err := s.validateToken(tokenStr, "access")
	if err != nil {
		return uuid.Nil, err
	}

	return uuid.Parse(claims.Subject)
}

// alexaLinkedTokenTTL is how long Alexa keeps the OAuth access token before
// the user must disable/re-enable the skill or re-link the account.
const alexaLinkedTokenTTL = 365 * 24 * time.Hour

// IssueAlexaAccountLinkingTokens returns JWTs after successful OAuth code
// exchange. Same validation as app login (audience kitzz-api / kitzz-refresh)
// but long-lived so Echo requests keep working.
func (s *AuthService) IssueAlexaAccountLinkingTokens(userID uuid.UUID) (*TokenPair, error) {
	now := time.Now()
	exp := now.Add(alexaLinkedTokenTTL)

	accessClaims := jwt.RegisteredClaims{
		Subject:   userID.String(),
		IssuedAt:  jwt.NewNumericDate(now),
		ExpiresAt: jwt.NewNumericDate(exp),
		Issuer:    "kitzz",
		Audience:  jwt.ClaimStrings{"kitzz-api"},
	}
	accessToken := jwt.NewWithClaims(jwt.SigningMethodHS256, accessClaims)
	accessStr, err := accessToken.SignedString([]byte(s.cfg.JWTSecret))
	if err != nil {
		return nil, err
	}

	refreshClaims := jwt.RegisteredClaims{
		Subject:   userID.String(),
		IssuedAt:  jwt.NewNumericDate(now),
		ExpiresAt: jwt.NewNumericDate(exp),
		Issuer:    "kitzz",
		Audience:  jwt.ClaimStrings{"kitzz-refresh"},
	}
	refreshToken := jwt.NewWithClaims(jwt.SigningMethodHS256, refreshClaims)
	refreshStr, err := refreshToken.SignedString([]byte(s.cfg.JWTSecret))
	if err != nil {
		return nil, err
	}

	return &TokenPair{
		AccessToken:  accessStr,
		RefreshToken: refreshStr,
		ExpiresIn:    int64(alexaLinkedTokenTTL.Seconds()),
	}, nil
}

func (s *AuthService) generateTokens(userID uuid.UUID) (*TokenPair, error) {
	now := time.Now()

	accessClaims := jwt.RegisteredClaims{
		Subject:   userID.String(),
		IssuedAt:  jwt.NewNumericDate(now),
		ExpiresAt: jwt.NewNumericDate(now.Add(s.cfg.JWTAccessExpiry)),
		Issuer:    "kitzz",
		Audience:  jwt.ClaimStrings{"kitzz-api"},
	}
	accessToken := jwt.NewWithClaims(jwt.SigningMethodHS256, accessClaims)
	accessStr, err := accessToken.SignedString([]byte(s.cfg.JWTSecret))
	if err != nil {
		return nil, err
	}

	refreshClaims := jwt.RegisteredClaims{
		Subject:   userID.String(),
		IssuedAt:  jwt.NewNumericDate(now),
		ExpiresAt: jwt.NewNumericDate(now.Add(s.cfg.JWTRefreshExpiry)),
		Issuer:    "kitzz",
		Audience:  jwt.ClaimStrings{"kitzz-refresh"},
	}
	refreshToken := jwt.NewWithClaims(jwt.SigningMethodHS256, refreshClaims)
	refreshStr, err := refreshToken.SignedString([]byte(s.cfg.JWTSecret))
	if err != nil {
		return nil, err
	}

	return &TokenPair{
		AccessToken:  accessStr,
		RefreshToken: refreshStr,
		ExpiresIn:    int64(s.cfg.JWTAccessExpiry.Seconds()),
	}, nil
}

func (s *AuthService) validateToken(tokenStr, audience string) (*jwt.RegisteredClaims, error) {
	token, err := jwt.ParseWithClaims(tokenStr, &jwt.RegisteredClaims{}, func(t *jwt.Token) (interface{}, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, ErrInvalidToken
		}
		return []byte(s.cfg.JWTSecret), nil
	})
	if err != nil {
		return nil, ErrInvalidToken
	}

	claims, ok := token.Claims.(*jwt.RegisteredClaims)
	if !ok || !token.Valid {
		return nil, ErrInvalidToken
	}

	expectedAud := "kitzz-api"
	if audience == "refresh" {
		expectedAud = "kitzz-refresh"
	}

	found := false
	for _, aud := range claims.Audience {
		if aud == expectedAud {
			found = true
			break
		}
	}
	if !found {
		return nil, ErrInvalidToken
	}

	return claims, nil
}
