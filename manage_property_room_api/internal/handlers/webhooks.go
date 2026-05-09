package handlers

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"io"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/jose/manage_property_room_api/internal/domain"
	"github.com/jose/manage_property_room_api/internal/httpx"
	"github.com/jose/manage_property_room_api/internal/store"
	"github.com/jose/manage_property_room_api/internal/webhooks"
)

type WebhooksHandler struct {
	Store      store.Store
	Dispatcher *webhooks.Dispatcher
}

type webhookRequest struct {
	Name       string   `json:"name"`
	URL        string   `json:"url"`
	Secret     string   `json:"secret,omitempty"`
	Events     []string `json:"events"`
	PropertyID string   `json:"propertyId,omitempty"`
	Active     *bool    `json:"active,omitempty"`
}

func (h *WebhooksHandler) List(w http.ResponseWriter, r *http.Request) {
	items, err := h.Store.Webhooks().List(r.Context())
	if err != nil {
		httpx.HandleError(w, err)
		return
	}
	if items == nil {
		items = []domain.Webhook{}
	}
	httpx.WriteJSON(w, http.StatusOK, items)
}

func (h *WebhooksHandler) Get(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	wh, err := h.Store.Webhooks().GetByID(r.Context(), id)
	if err != nil {
		httpx.HandleError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, wh)
}

func (h *WebhooksHandler) Create(w http.ResponseWriter, r *http.Request) {
	var req webhookRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", err.Error())
		return
	}
	if strings.TrimSpace(req.Name) == "" || strings.TrimSpace(req.URL) == "" {
		httpx.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "name and url are required")
		return
	}
	if !strings.HasPrefix(req.URL, "http://") && !strings.HasPrefix(req.URL, "https://") {
		httpx.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "url must be http(s)")
		return
	}
	if len(req.Events) == 0 {
		httpx.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "events required")
		return
	}
	if !validEvents(req.Events) {
		httpx.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "unknown event name")
		return
	}
	secret := req.Secret
	if secret == "" {
		secret = randomSecret()
	}
	active := true
	if req.Active != nil {
		active = *req.Active
	}
	wh := &domain.Webhook{
		ID: uuid.NewString(), Name: req.Name, URL: req.URL, Secret: secret,
		Events: req.Events, PropertyID: req.PropertyID, Active: active,
		CreatedBy: httpx.UserIDFrom(r.Context()),
		CreatedAt: time.Now().UTC(), UpdatedAt: time.Now().UTC(),
	}
	if err := h.Store.Webhooks().Create(r.Context(), wh); err != nil {
		httpx.HandleError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusCreated, wh)
}

func (h *WebhooksHandler) Update(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	wh, err := h.Store.Webhooks().GetByID(r.Context(), id)
	if err != nil {
		httpx.HandleError(w, err)
		return
	}
	var req webhookRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", err.Error())
		return
	}
	if req.Name != "" {
		wh.Name = req.Name
	}
	if req.URL != "" {
		wh.URL = req.URL
	}
	if req.Secret != "" {
		wh.Secret = req.Secret
	}
	if len(req.Events) > 0 {
		if !validEvents(req.Events) {
			httpx.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "unknown event name")
			return
		}
		wh.Events = req.Events
	}
	wh.PropertyID = req.PropertyID
	if req.Active != nil {
		wh.Active = *req.Active
	}
	if err := h.Store.Webhooks().Update(r.Context(), wh); err != nil {
		httpx.HandleError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, wh)
}

func (h *WebhooksHandler) Delete(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	if err := h.Store.Webhooks().Delete(r.Context(), id); err != nil {
		httpx.HandleError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *WebhooksHandler) Deliveries(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	limit := 50
	if v := r.URL.Query().Get("limit"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 && n <= 200 {
			limit = n
		}
	}
	items, err := h.Store.WebhookDeliveries().ListByWebhook(r.Context(), id, limit)
	if err != nil {
		httpx.HandleError(w, err)
		return
	}
	if items == nil {
		items = []domain.WebhookDelivery{}
	}
	httpx.WriteJSON(w, http.StatusOK, items)
}

// TestFire sends a synthetic ping event to the webhook (admin/owner only).
func (h *WebhooksHandler) TestFire(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	wh, err := h.Store.Webhooks().GetByID(r.Context(), id)
	if err != nil {
		httpx.HandleError(w, err)
		return
	}
	h.Dispatcher.Enqueue(webhooks.Event{
		Event:      "webhook.test",
		PropertyID: wh.PropertyID,
		OccurredAt: time.Now().UTC(),
		Data:       map[string]any{"webhookId": wh.ID, "message": "ping"},
	})
	w.WriteHeader(http.StatusAccepted)
}

// ── inbound hooks ───────────────────────────────────────────────────────────

type inboundHookRequest struct {
	Name       string `json:"name"`
	PropertyID string `json:"propertyId"`
	ColumnID   string `json:"columnId"`
	Secret     string `json:"secret,omitempty"`
	Active     *bool  `json:"active,omitempty"`
}

func (h *WebhooksHandler) ListInbound(w http.ResponseWriter, r *http.Request) {
	items, err := h.Store.InboundHooks().List(r.Context())
	if err != nil {
		httpx.HandleError(w, err)
		return
	}
	if items == nil {
		items = []domain.InboundHook{}
	}
	httpx.WriteJSON(w, http.StatusOK, items)
}

func (h *WebhooksHandler) CreateInbound(w http.ResponseWriter, r *http.Request) {
	var req inboundHookRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", err.Error())
		return
	}
	if req.PropertyID == "" || req.ColumnID == "" || req.Name == "" {
		httpx.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "name, propertyId and columnId are required")
		return
	}
	active := true
	if req.Active != nil {
		active = *req.Active
	}
	hook := &domain.InboundHook{
		ID: uuid.NewString(), Name: req.Name, Token: randomSecret(),
		Secret: req.Secret, PropertyID: req.PropertyID, ColumnID: req.ColumnID,
		Active: active, CreatedBy: httpx.UserIDFrom(r.Context()),
		CreatedAt: time.Now().UTC(), UpdatedAt: time.Now().UTC(),
	}
	if err := h.Store.InboundHooks().Create(r.Context(), hook); err != nil {
		httpx.HandleError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusCreated, hook)
}

func (h *WebhooksHandler) UpdateInbound(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	hook, err := h.Store.InboundHooks().GetByID(r.Context(), id)
	if err != nil {
		httpx.HandleError(w, err)
		return
	}
	var req inboundHookRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", err.Error())
		return
	}
	if req.Name != "" {
		hook.Name = req.Name
	}
	if req.PropertyID != "" {
		hook.PropertyID = req.PropertyID
	}
	if req.ColumnID != "" {
		hook.ColumnID = req.ColumnID
	}
	hook.Secret = req.Secret
	if req.Active != nil {
		hook.Active = *req.Active
	}
	if err := h.Store.InboundHooks().Update(r.Context(), hook); err != nil {
		httpx.HandleError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, hook)
}

func (h *WebhooksHandler) DeleteInbound(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	if err := h.Store.InboundHooks().Delete(r.Context(), id); err != nil {
		httpx.HandleError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

type inboundPayload struct {
	Title       string              `json:"title"`
	Description string              `json:"description,omitempty"`
	RoomCode    string              `json:"roomCode,omitempty"`
	Priority    domain.CardPriority `json:"priority,omitempty"`
}

// ReceiveInbound is the public endpoint hit by external systems. Auth is via
// the path token; optional HMAC signature in `X-PMR-Signature` header.
func (h *WebhooksHandler) ReceiveInbound(w http.ResponseWriter, r *http.Request) {
	token := chi.URLParam(r, "token")
	hook, err := h.Store.InboundHooks().GetByToken(r.Context(), token)
	if err != nil {
		http.Error(w, "not found", http.StatusNotFound)
		return
	}
	if !hook.Active {
		http.Error(w, "disabled", http.StatusGone)
		return
	}
	body, err := io.ReadAll(io.LimitReader(r.Body, 1<<20))
	if err != nil {
		http.Error(w, "read body", http.StatusBadRequest)
		return
	}
	if hook.Secret != "" {
		if !webhooks.VerifySignature(hook.Secret, body, r.Header.Get("X-PMR-Signature")) {
			http.Error(w, "bad signature", http.StatusUnauthorized)
			return
		}
	}
	var p inboundPayload
	if len(body) > 0 {
		if err := json.Unmarshal(body, &p); err != nil {
			http.Error(w, "invalid json", http.StatusBadRequest)
			return
		}
	}
	if strings.TrimSpace(p.Title) == "" {
		http.Error(w, "title required", http.StatusBadRequest)
		return
	}
	if p.Priority == "" {
		p.Priority = domain.PriorityNormal
	}
	card := &domain.Card{
		ID:           uuid.NewString(),
		PropertyID:   hook.PropertyID,
		ColumnID:     hook.ColumnID,
		Title:        p.Title,
		Description:  p.Description,
		RoomCode:     p.RoomCode,
		Priority:     p.Priority,
		Kind:         domain.CardKindTask,
		CustomFields: map[string]any{},
	}
	if err := h.Store.Cards().Create(r.Context(), card); err != nil {
		httpx.HandleError(w, err)
		return
	}
	// Fire outbound card.created for parity with internal flow.
	if h.Dispatcher != nil {
		h.Dispatcher.Enqueue(webhooks.Event{
			Event:      domain.WebhookEventCardCreated,
			PropertyID: card.PropertyID,
			OccurredAt: time.Now().UTC(),
			Data: map[string]any{
				"cardId": card.ID, "columnId": card.ColumnID, "title": card.Title,
				"source": "inbound", "inboundHookId": hook.ID,
			},
		})
	}
	httpx.WriteJSON(w, http.StatusCreated, card)
}

// ── helpers ────────────────────────────────────────────────────────────────

func validEvents(events []string) bool {
	for _, e := range events {
		ok := false
		for _, k := range domain.AllWebhookEvents {
			if e == k {
				ok = true
				break
			}
		}
		if !ok {
			return false
		}
	}
	return true
}

func randomSecret() string {
	b := make([]byte, 24)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}
