// Package webhooks provides asynchronous outbound webhook dispatch with HMAC
// signing and bounded retries. The dispatcher is fire-and-forget from the
// perspective of HTTP handlers — they call Enqueue and return immediately;
// delivery happens in goroutines and is recorded in webhook_deliveries.
package webhooks

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"time"

	"github.com/google/uuid"

	"github.com/jose/manage_property_room_api/internal/domain"
	"github.com/jose/manage_property_room_api/internal/store"
)

// Event is a single outbound notification.
type Event struct {
	Event      string         `json:"event"`
	PropertyID string         `json:"propertyId,omitempty"`
	OccurredAt time.Time      `json:"occurredAt"`
	Data       map[string]any `json:"data"`
}

// Dispatcher fans out one Event to every matching webhook.
type Dispatcher struct {
	store  store.Store
	client *http.Client
}

func NewDispatcher(s store.Store) *Dispatcher {
	return &Dispatcher{
		store:  s,
		client: &http.Client{Timeout: 10 * time.Second},
	}
}

// Enqueue dispatches `evt` asynchronously. Safe to call from HTTP handlers.
func (d *Dispatcher) Enqueue(evt Event) {
	if evt.OccurredAt.IsZero() {
		evt.OccurredAt = time.Now().UTC()
	}
	go d.run(evt)
}

func (d *Dispatcher) run(evt Event) {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()
	hooks, err := d.store.Webhooks().ListActiveForEvent(ctx, evt.Event, evt.PropertyID)
	if err != nil {
		log.Printf("webhooks: list active for %s: %v", evt.Event, err)
		return
	}
	if len(hooks) == 0 {
		return
	}
	payload, err := json.Marshal(evt)
	if err != nil {
		log.Printf("webhooks: marshal event: %v", err)
		return
	}
	for _, h := range hooks {
		go d.deliver(ctx, h, evt.Event, payload)
	}
}

// retry schedule — bounded total elapsed ~36s.
var retryDelays = []time.Duration{0, time.Second, 5 * time.Second, 30 * time.Second}

func (d *Dispatcher) deliver(ctx context.Context, hook domain.Webhook, event string, payload []byte) {
	rec := &domain.WebhookDelivery{
		ID:        uuid.NewString(),
		WebhookID: hook.ID,
		Event:     event,
		Payload:   string(payload),
		Status:    "pending",
	}
	if err := d.store.WebhookDeliveries().Create(ctx, rec); err != nil {
		log.Printf("webhooks: record delivery: %v", err)
	}
	sig := signPayload(hook.Secret, payload)
	var lastErr string
	var lastCode int
	for i, delay := range retryDelays {
		if delay > 0 {
			select {
			case <-time.After(delay):
			case <-ctx.Done():
				rec.Status = "failed"
				rec.LastError = "ctx canceled"
				_ = d.store.WebhookDeliveries().Update(ctx, rec)
				return
			}
		}
		rec.Attempts = i + 1
		code, err := d.post(ctx, hook.URL, payload, sig, event)
		lastCode = code
		if err == nil && code >= 200 && code < 300 {
			rec.Status = "success"
			rec.HTTPCode = code
			rec.LastError = ""
			_ = d.store.WebhookDeliveries().Update(ctx, rec)
			return
		}
		if err != nil {
			lastErr = err.Error()
		} else {
			lastErr = fmt.Sprintf("http %d", code)
		}
	}
	rec.Status = "failed"
	rec.HTTPCode = lastCode
	rec.LastError = lastErr
	_ = d.store.WebhookDeliveries().Update(ctx, rec)
	log.Printf("webhooks: delivery to %s failed after retries: %s", hook.URL, lastErr)
}

func (d *Dispatcher) post(ctx context.Context, url string, payload []byte, sig, event string) (int, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(payload))
	if err != nil {
		return 0, err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("User-Agent", "PMR-Webhooks/1.0")
	req.Header.Set("X-PMR-Event", event)
	req.Header.Set("X-PMR-Signature", "sha256="+sig)
	resp, err := d.client.Do(req)
	if err != nil {
		return 0, err
	}
	defer resp.Body.Close()
	_, _ = io.Copy(io.Discard, resp.Body)
	return resp.StatusCode, nil
}

func signPayload(secret string, payload []byte) string {
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write(payload)
	return hex.EncodeToString(mac.Sum(nil))
}

// VerifySignature is exposed for inbound hook verification.
func VerifySignature(secret string, payload []byte, header string) bool {
	if secret == "" {
		return true
	}
	const prefix = "sha256="
	if len(header) <= len(prefix) || header[:len(prefix)] != prefix {
		return false
	}
	expected := signPayload(secret, payload)
	return hmac.Equal([]byte(expected), []byte(header[len(prefix):]))
}
