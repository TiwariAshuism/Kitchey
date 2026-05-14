package http

import (
	"errors"
	"log"
	"net/http"
	"strconv"
	"time"

	"github.com/ashutoshkumar/kitzz/internal/ports"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type MessageHandler struct {
	messageService *ports.MessageService
}

func NewMessageHandler(messageService *ports.MessageService) *MessageHandler {
	return &MessageHandler{messageService: messageService}
}

type incomingMessageRequest struct {
	DeviceID   string `json:"device_id" binding:"required"`
	Transcript string `json:"transcript" binding:"required,max=5000"`
}

func (h *MessageHandler) HandleIncoming(c *gin.Context) {
	var req incomingMessageRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		log.Printf("[incoming] JSON bind failed client=%s: %v", c.ClientIP(), err)
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	userID := GetUserID(c)
	log.Printf("[incoming] user_id=%s client=%s alexa_device_id=%q transcript_len=%d transcript_preview=%q",
		userID.String(),
		c.ClientIP(),
		req.DeviceID,
		len(req.Transcript),
		previewString(req.Transcript, 160),
	)

	messageIDs, err := h.messageService.HandleIncoming(c.Request.Context(), req.DeviceID, req.Transcript, userID)
	if err != nil {
		if errors.Is(err, ports.ErrSubscriptionExpired) {
			c.JSON(http.StatusPaymentRequired, gin.H{"error": "subscription expired"})
			return
		}
		if errors.Is(err, ports.ErrDeviceNotPaired) {
			c.JSON(http.StatusNotFound, gin.H{"error": "device not paired"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to process message"})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"message_ids": messageIDs,
		"count":       len(messageIDs),
	})
}

func (h *MessageHandler) ListMessages(c *gin.Context) {
	userID := GetUserID(c)

	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	var cursor *time.Time
	if cursorStr := c.Query("cursor"); cursorStr != "" {
		t, err := time.Parse(time.RFC3339Nano, cursorStr)
		if err == nil {
			cursor = &t
		}
	}

	messages, err := h.messageService.ListMessages(c.Request.Context(), userID, cursor, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to list messages"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"messages": messages,
		"count":    len(messages),
	})
}

func (h *MessageHandler) GetMessage(c *gin.Context) {
	userID := GetUserID(c)
	msgID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid message ID"})
		return
	}

	msg, err := h.messageService.GetMessage(c.Request.Context(), msgID, userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "message not found"})
		return
	}

	c.JSON(http.StatusOK, msg)
}

func (h *MessageHandler) MarkRead(c *gin.Context) {
	userID := GetUserID(c)
	msgID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid message ID"})
		return
	}

	if err := h.messageService.MarkRead(c.Request.Context(), msgID, userID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to mark as read"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "marked as read"})
}

func (h *MessageHandler) DeleteMessage(c *gin.Context) {
	userID := GetUserID(c)
	msgID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid message ID"})
		return
	}

	if err := h.messageService.SoftDelete(c.Request.Context(), msgID, userID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to delete message"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "deleted"})
}

func previewString(s string, max int) string {
	if max <= 0 {
		return ""
	}
	if len(s) <= max {
		return s
	}
	return s[:max] + "…"
}
