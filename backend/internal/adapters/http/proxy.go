// Package http hosts the HTTP adapter layer.
//
// This file implements a thin reverse-proxy that lets the Go backend act as
// the single public entry point for the whole Kitzz stack. The Alexa custom
// skill is implemented as a small Node/Express server that listens on a
// separate local port (default :3000). When the developer can only expose
// one local port through ngrok, the proxy lets every Alexa request reach
// the Node server via the same tunnel as the OAuth and REST APIs.
//
// Public URL mapping (assuming ngrok forwards to :8080):
//
//	https://<ngrok-host>/oauth/...   -> Go OAuth endpoints (account linking)
//	https://<ngrok-host>/api/...     -> Go REST API (used by Flutter app)
//	https://<ngrok-host>/alexa       -> Node Alexa skill (POST /)
package http

import (
	"bytes"
	"encoding/json"
	"io"
	"log"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"strings"

	"github.com/gin-gonic/gin"
)

// NewAlexaSkillProxy builds a Gin handler that reverse-proxies every
// incoming request under ``/alexa`` to the locally running Alexa skill
// server.
//
// The ``/alexa`` prefix is stripped before forwarding so the skill server
// still sees its native routes (it only exposes ``POST /`` and
// ``GET /health``).
//
// Args:
//
//	targetURL: Base URL of the upstream Alexa skill server, e.g.
//	    ``http://localhost:3000``. An empty string disables the proxy and
//	    the returned handler will respond with HTTP 503.
//
// Returns:
//
//	A ``gin.HandlerFunc`` ready to be mounted under any route group.
func NewAlexaSkillProxy(targetURL string) gin.HandlerFunc {
	if targetURL == "" {
		return func(c *gin.Context) {
			c.JSON(http.StatusServiceUnavailable, gin.H{
				"error": "alexa skill proxy disabled (ALEXA_SKILL_URL not set)",
			})
		}
	}

	upstream, err := url.Parse(targetURL)
	if err != nil {
		log.Printf("WARN: invalid ALEXA_SKILL_URL %q: %v", targetURL, err)
		return func(c *gin.Context) {
			c.JSON(http.StatusBadGateway, gin.H{
				"error": "alexa skill proxy misconfigured",
			})
		}
	}

	proxy := httputil.NewSingleHostReverseProxy(upstream)

	// Default Director sets URL.Host/Scheme correctly but keeps the
	// inbound Path verbatim. We strip the ``/alexa`` prefix so the
	// skill server sees its own routes.
	defaultDirector := proxy.Director
	proxy.Director = func(req *http.Request) {
		defaultDirector(req)
		req.Host = upstream.Host
		req.URL.Path = stripAlexaPrefix(req.URL.Path)
		req.URL.RawPath = "" // let net/http re-encode from Path
	}

	proxy.ErrorHandler = func(w http.ResponseWriter, r *http.Request, err error) {
		log.Printf("ERROR: alexa proxy upstream failure: %v", err)
		http.Error(w, "alexa skill upstream unavailable", http.StatusBadGateway)
	}

	return func(c *gin.Context) {
		logAlexaInboundSkillRequest(c)
		proxy.ServeHTTP(c.Writer, c.Request)
	}
}

// alexaSkillEnvelope is a minimal parse of the Alexa skill HTTPS request
// body for logging only (see Request and Response JSON reference).
type alexaSkillEnvelope struct {
	Context struct {
		System struct {
			User struct {
				AccessToken string `json:"accessToken"`
			} `json:"user"`
		} `json:"System"`
	} `json:"context"`
	Request struct {
		Type   string `json:"type"`
		Intent *struct {
			Name string `json:"name"`
		} `json:"intent"`
	} `json:"request"`
}

const maxAlexaBodyBytes = 10 << 20 // 10 MiB cap; skill payloads are small

// logAlexaInboundSkillRequest logs traffic from Amazon's servers to POST /alexa
// before the request is proxied to the Node skill. It does not log tokens.
func logAlexaInboundSkillRequest(c *gin.Context) {
	client := c.ClientIP()
	path := c.Request.URL.Path
	if path == "" {
		path = "/alexa"
	}

	if c.Request.Body == nil || c.Request.Method != http.MethodPost {
		log.Printf("[alexa-in] client=%s %s %s (no JSON body)", client, c.Request.Method, path)
		return
	}

	body, err := io.ReadAll(io.LimitReader(c.Request.Body, maxAlexaBodyBytes))
	_ = c.Request.Body.Close()
	if err != nil {
		log.Printf("[alexa-in] client=%s %s: read body error: %v", client, path, err)
		c.Request.Body = io.NopCloser(bytes.NewReader(nil))
		return
	}
	c.Request.Body = io.NopCloser(bytes.NewReader(body))

	var env alexaSkillEnvelope
	if err := json.Unmarshal(body, &env); err != nil {
		log.Printf("[alexa-in] client=%s %s body_len=%d (not JSON skill envelope: %v)",
			client, path, len(body), err)
		return
	}

	intent := ""
	if env.Request.Intent != nil {
		intent = env.Request.Intent.Name
	}
	linked := env.Context.System.User.AccessToken != ""

	if os.Getenv("ALEXA_REQUEST_DEBUG") == "1" {
		log.Printf("[alexa-in] client=%s %s type=%s intent=%q account_linked=%v body_len=%d",
			client, path, env.Request.Type, intent, linked, len(body))
	} else {
		log.Printf("[alexa-in] client=%s %s type=%s intent=%q account_linked=%v",
			client, path, env.Request.Type, intent, linked)
	}
}

// stripAlexaPrefix removes a leading ``/alexa`` segment from the request
// path. Both ``/alexa`` (exact match) and ``/alexa/...`` are normalised so
// the upstream server receives ``/`` and ``/<rest>`` respectively.
//
// Args:
//
//	p: Original request path, e.g. ``/alexa`` or ``/alexa/health``.
//
// Returns:
//
//	The rewritten path with a guaranteed leading slash.
func stripAlexaPrefix(p string) string {
	trimmed := strings.TrimPrefix(p, "/alexa")
	if trimmed == "" {
		return "/"
	}
	if !strings.HasPrefix(trimmed, "/") {
		return "/" + trimmed
	}
	return trimmed
}
