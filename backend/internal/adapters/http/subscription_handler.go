package http

import (
	"net/http"

	"github.com/ashutoshkumar/kitzz/internal/domain"
	"github.com/gin-gonic/gin"
)

type SubscriptionHandler struct {
	subRepo domain.SubscriptionRepository
}

func NewSubscriptionHandler(subRepo domain.SubscriptionRepository) *SubscriptionHandler {
	return &SubscriptionHandler{subRepo: subRepo}
}

func (h *SubscriptionHandler) GetSubscription(c *gin.Context) {
	userID := GetUserID(c)

	sub, err := h.subRepo.GetByUserID(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "no subscription found"})
		return
	}

	c.JSON(http.StatusOK, sub)
}
