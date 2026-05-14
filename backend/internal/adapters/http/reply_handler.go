package http

import (
	"errors"
	"log"
	"net/http"

	"github.com/ashutoshkumar/kitzz/internal/ports"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type ReplyHandler struct {
	replyService *ports.ReplyService
}

func NewReplyHandler(replyService *ports.ReplyService) *ReplyHandler {
	return &ReplyHandler{replyService: replyService}
}

type sendReplyRequest struct {
	DeviceID string `json:"device_id"`
	Text     string `json:"text" binding:"required,max=500"`
}

// SendReply - POST /api/replies (from Flutter app)
// If device_id is provided, sends to that device. Otherwise sends to all paired devices.
func (h *ReplyHandler) SendReply(c *gin.Context) {
	var req sendReplyRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	userID := GetUserID(c)

	if req.DeviceID != "" {
		deviceID, err := uuid.Parse(req.DeviceID)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid device_id"})
			return
		}

		reply, err := h.replyService.SendReply(c.Request.Context(), userID, deviceID, req.Text)
		if err != nil {
			if errors.Is(err, ports.ErrNoDevicesToReply) {
				log.Printf("[replies] POST 404: device_id=%s not found or not owned by user_id=%s", req.DeviceID, userID)
				c.JSON(http.StatusNotFound, gin.H{"error": "device not found or not yours"})
				return
			}
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to send reply"})
			return
		}

		c.JSON(http.StatusCreated, reply)
		return
	}

	// Send to all devices
	replies, err := h.replyService.SendReplyToAllDevices(c.Request.Context(), userID, req.Text)
	if err != nil {
		if errors.Is(err, ports.ErrNoDevicesToReply) {
			log.Printf("[replies] POST 404: no device_pairings for user_id=%s (pair an Echo in the app first)", userID)
			c.JSON(http.StatusNotFound, gin.H{"error": "no paired devices found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to send reply"})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"replies": replies,
		"count":   len(replies),
	})
}

// ListSentReplies - GET /api/replies (from Flutter app)
func (h *ReplyHandler) ListSentReplies(c *gin.Context) {
	userID := GetUserID(c)

	replies, err := h.replyService.ListSentReplies(c.Request.Context(), userID, 20)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to list replies"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"replies": replies,
		"count":   len(replies),
	})
}

type markDeliveredRequest struct {
	IDs []string `json:"ids" binding:"required"`
}

// GetPendingReplies - GET /api/replies/pending?device_id=X (called by Alexa skill)
func (h *ReplyHandler) GetPendingReplies(c *gin.Context) {
	alexaDeviceID := c.Query("device_id")
	if alexaDeviceID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "device_id is required"})
		return
	}

	userID := GetUserID(c)
	replies, err := h.replyService.GetPendingReplies(c.Request.Context(), alexaDeviceID, userID)
	if err != nil {
		if errors.Is(err, ports.ErrNotYourDevice) {
			c.JSON(http.StatusForbidden, gin.H{"error": "device not paired to your account"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to get replies"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"replies": replies,
		"count":   len(replies),
	})
}

// MarkDelivered - PUT /api/replies/delivered (called by Alexa skill after reading)
func (h *ReplyHandler) MarkDelivered(c *gin.Context) {
	var req markDeliveredRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var ids []uuid.UUID
	for _, idStr := range req.IDs {
		id, err := uuid.Parse(idStr)
		if err != nil {
			continue
		}
		ids = append(ids, id)
	}

	if len(ids) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "no valid IDs provided"})
		return
	}

	if err := h.replyService.MarkDelivered(c.Request.Context(), ids); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to mark delivered"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "marked as delivered", "count": len(ids)})
}
