package http

import (
	"errors"
	"net/http"

	"github.com/ashutoshkumar/kitzz/internal/ports"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type DeviceHandler struct {
	deviceService *ports.DeviceService
}

func NewDeviceHandler(deviceService *ports.DeviceService) *DeviceHandler {
	return &DeviceHandler{deviceService: deviceService}
}

type pairDeviceRequest struct {
	AlexaDeviceID string `json:"alexa_device_id" binding:"required"`
	Nickname      string `json:"nickname" binding:"required,max=255"`
}

func (h *DeviceHandler) PairDevice(c *gin.Context) {
	var req pairDeviceRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	userID := GetUserID(c)
	pairing, err := h.deviceService.PairDevice(c.Request.Context(), userID, req.AlexaDeviceID, req.Nickname)
	if err != nil {
		if errors.Is(err, ports.ErrDeviceAlreadyPaired) {
			c.JSON(http.StatusConflict, gin.H{"error": "device already paired to this user"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to pair device"})
		return
	}

	c.JSON(http.StatusCreated, pairing)
}

func (h *DeviceHandler) ListDevices(c *gin.Context) {
	userID := GetUserID(c)
	devices, err := h.deviceService.ListDevices(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to list devices"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"devices": devices,
		"count":   len(devices),
	})
}

func (h *DeviceHandler) UnpairDevice(c *gin.Context) {
	userID := GetUserID(c)
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid device ID"})
		return
	}

	if err := h.deviceService.UnpairDevice(c.Request.Context(), id, userID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to unpair device"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "device unpaired"})
}
