package handlers

import (
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/jose/manage_property_room_api/internal/domain"
	"github.com/jose/manage_property_room_api/internal/events"
	"github.com/jose/manage_property_room_api/internal/httpx"
	"github.com/jose/manage_property_room_api/internal/store"
	"github.com/jose/manage_property_room_api/internal/webhooks"
)

type CardsHandler struct {
	Store      store.Store
	Dispatcher *webhooks.Dispatcher
}

type createCardRequest struct {
	Title        string                 `json:"title"`
	Description  string                 `json:"description"`
	Position     int                    `json:"position"`
	RoomCode     string                 `json:"roomCode"`
	Priority     domain.CardPriority    `json:"priority"`
	CheckinDate  *time.Time             `json:"checkinDate,omitempty"`
	AssignedToID *string                `json:"assignedToId,omitempty"`
	Kind         domain.CardKind        `json:"kind"`
	CustomFields map[string]any         `json:"customFields"`
}

type updateCardRequest struct {
	ColumnID     *string                 `json:"columnId,omitempty"`
	Title        *string                 `json:"title,omitempty"`
	Description  *string                 `json:"description,omitempty"`
	Position     *int                    `json:"position,omitempty"`
	IsDone       *bool                   `json:"isDone,omitempty"`
	RoomCode     *string                 `json:"roomCode,omitempty"`
	Priority     *domain.CardPriority    `json:"priority,omitempty"`
	CheckinDate  *time.Time              `json:"checkinDate,omitempty"`
	ClearCheckin bool                    `json:"clearCheckin,omitempty"`
	AssignedToID *string                 `json:"assignedToId,omitempty"`
	ClearAssign  bool                    `json:"clearAssign,omitempty"`
	Kind         *domain.CardKind        `json:"kind,omitempty"`
	CustomFields *map[string]any         `json:"customFields,omitempty"`
	CleanedBy    *string                 `json:"cleanedBy,omitempty"`
	DoneAt       *time.Time              `json:"doneAt,omitempty"`
	ClearDoneAt  bool                    `json:"clearDoneAt,omitempty"`
}

func (h *CardsHandler) CreateForColumn(w http.ResponseWriter, r *http.Request) {
	columnID := chi.URLParam(r, "id")
	col, err := h.Store.Columns().GetByID(r.Context(), columnID)
	if err != nil { httpx.HandleError(w, err); return }
	var req createCardRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", err.Error()); return
	}
	if req.Title == "" {
		httpx.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "title required"); return
	}
	if req.Priority == "" { req.Priority = domain.PriorityNormal }
	if req.Kind == "" { req.Kind = domain.CardKindRoom }
	if req.CustomFields == nil { req.CustomFields = map[string]any{} }
	c := &domain.Card{
		ID: uuid.NewString(),
		PropertyID: col.PropertyID, ColumnID: columnID,
		Title: req.Title, Description: req.Description, Position: req.Position,
		RoomCode: req.RoomCode, Priority: req.Priority, Kind: req.Kind,
		CheckinDate: req.CheckinDate, AssignedToID: req.AssignedToID,
		CustomFields: req.CustomFields,
	}
	if err := h.Store.Cards().Create(r.Context(), c); err != nil {
		httpx.HandleError(w, err); return
	}
	recordAudit(r.Context(), h.Store, "create", "card", c.ID, c.Title, c.PropertyID)
	events.Publish(events.Event{Type: "card.created", Entity: "card", EntityID: c.ID, PropertyID: c.PropertyID, ActorID: httpx.UserIDFrom(r.Context())})
	h.fire(domain.WebhookEventCardCreated, c, nil)
	httpx.WriteJSON(w, http.StatusCreated, c)
}

func (h *CardsHandler) Get(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	c, err := h.Store.Cards().GetByID(r.Context(), id)
	if err != nil { httpx.HandleError(w, err); return }
	httpx.WriteJSON(w, http.StatusOK, c)
}

func (h *CardsHandler) Update(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	c, err := h.Store.Cards().GetByID(r.Context(), id)
	if err != nil { httpx.HandleError(w, err); return }
	var req updateCardRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", err.Error()); return
	}
	if req.ColumnID != nil { c.ColumnID = *req.ColumnID }
	if req.Title != nil { c.Title = *req.Title }
	if req.Description != nil { c.Description = *req.Description }
	if req.Position != nil { c.Position = *req.Position }
	if req.IsDone != nil { c.IsDone = *req.IsDone }
	if req.RoomCode != nil { c.RoomCode = *req.RoomCode }
	if req.Priority != nil { c.Priority = *req.Priority }
	if req.ClearCheckin { c.CheckinDate = nil } else if req.CheckinDate != nil { c.CheckinDate = req.CheckinDate }
	if req.ClearAssign { c.AssignedToID = nil } else if req.AssignedToID != nil { c.AssignedToID = req.AssignedToID }
	if req.Kind != nil { c.Kind = *req.Kind }
	if req.CustomFields != nil { c.CustomFields = *req.CustomFields }
	if req.CleanedBy != nil { c.CleanedBy = *req.CleanedBy }
	if req.ClearDoneAt { c.DoneAt = nil } else if req.DoneAt != nil { c.DoneAt = req.DoneAt }
	if err := h.Store.Cards().Update(r.Context(), c); err != nil {
		httpx.HandleError(w, err); return
	}
	recordAudit(r.Context(), h.Store, "update", "card", c.ID, c.Title, c.PropertyID)
	events.Publish(events.Event{Type: "card.updated", Entity: "card", EntityID: c.ID, PropertyID: c.PropertyID, ActorID: httpx.UserIDFrom(r.Context())})
	httpx.WriteJSON(w, http.StatusOK, c)
}

func (h *CardsHandler) Delete(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	if err := h.Store.Cards().Delete(r.Context(), id); err != nil {
		httpx.HandleError(w, err); return
	}
	recordAudit(r.Context(), h.Store, "delete", "card", id, "")
	events.Publish(events.Event{Type: "card.deleted", Entity: "card", EntityID: id, ActorID: httpx.UserIDFrom(r.Context())})
	w.WriteHeader(http.StatusNoContent)
}

type moveCardRequest struct {
	TargetColumnID string `json:"targetColumnId"`
	Position       int    `json:"position"`
}

func (h *CardsHandler) Move(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	var req moveCardRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", err.Error()); return
	}
	if err := h.Store.Cards().MoveToColumn(r.Context(), id, req.TargetColumnID, req.Position); err != nil {
		httpx.HandleError(w, err); return
	}
	c, err := h.Store.Cards().GetByID(r.Context(), id)
	if err != nil { httpx.HandleError(w, err); return }
	recordAudit(r.Context(), h.Store, "move", "card", id, c.Title, c.PropertyID)
	events.Publish(events.Event{Type: "card.moved", Entity: "card", EntityID: c.ID, PropertyID: c.PropertyID, ActorID: httpx.UserIDFrom(r.Context())})
	h.fire(domain.WebhookEventCardMoved, c, map[string]any{"targetColumnId": req.TargetColumnID, "position": req.Position})
	httpx.WriteJSON(w, http.StatusOK, c)
}

type toggleDoneRequest struct {
	CleanedBy string `json:"cleanedBy"`
}

func (h *CardsHandler) ToggleDone(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	c, err := h.Store.Cards().GetByID(r.Context(), id)
	if err != nil { httpx.HandleError(w, err); return }
	var req toggleDoneRequest
	_ = httpx.DecodeJSON(r, &req) // optional body — ignore parse error
	c.IsDone = !c.IsDone
	if c.IsDone && req.CleanedBy != "" {
		c.CleanedBy = req.CleanedBy
	} else if !c.IsDone {
		c.CleanedBy = ""
	}
	if err := h.Store.Cards().Update(r.Context(), c); err != nil {
		httpx.HandleError(w, err); return
	}
	status := "pendiente"
	if c.IsDone { status = "completada" }
	recordAudit(r.Context(), h.Store, "update", "card", c.ID, c.Title+" → "+status, c.PropertyID)
	evt := domain.WebhookEventCardUncompleted
	if c.IsDone { evt = domain.WebhookEventCardCompleted }
	events.Publish(events.Event{Type: "card.updated", Entity: "card", EntityID: c.ID, PropertyID: c.PropertyID, ActorID: httpx.UserIDFrom(r.Context())})
	h.fire(evt, c, nil)
	httpx.WriteJSON(w, http.StatusOK, c)
}

func (h *CardsHandler) Archive(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	c, err := h.Store.Cards().GetByID(r.Context(), id)
	if err != nil { httpx.HandleError(w, err); return }
	if err := archiveCard(r, h.Store, c); err != nil {
		httpx.HandleError(w, err); return
	}
	recordAudit(r.Context(), h.Store, "archive", "card", c.ID, c.Title, c.PropertyID)
	events.Publish(events.Event{Type: "card.archived", Entity: "card", EntityID: c.ID, PropertyID: c.PropertyID, ActorID: httpx.UserIDFrom(r.Context())})
	h.fire(domain.WebhookEventCardArchived, c, nil)
	httpx.WriteJSON(w, http.StatusOK, c)
}

type assignRequest struct {
	UserID *string `json:"userId"` // nil → unassign
}

func (h *CardsHandler) Assign(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	var req assignRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", err.Error()); return
	}
	c, err := h.Store.Cards().GetByID(r.Context(), id)
	if err != nil { httpx.HandleError(w, err); return }
	c.AssignedToID = req.UserID
	if err := h.Store.Cards().Update(r.Context(), c); err != nil {
		httpx.HandleError(w, err); return
	}
	httpx.WriteJSON(w, http.StatusOK, c)
}

type reorderCardsRequest struct {
	ColumnID string   `json:"columnId"`
	IDs      []string `json:"ids"`
}

func (h *CardsHandler) Reorder(w http.ResponseWriter, r *http.Request) {
	var req reorderCardsRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", err.Error()); return
	}
	if req.ColumnID == "" {
		httpx.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "columnId required"); return
	}
	if err := h.Store.Cards().Reorder(r.Context(), req.ColumnID, req.IDs); err != nil {
		httpx.HandleError(w, err); return
	}
	w.WriteHeader(http.StatusNoContent)
}

// fire dispatches a webhook event for `c`. Safe with a nil dispatcher.
func (h *CardsHandler) fire(event string, c *domain.Card, extra map[string]any) {
	if h.Dispatcher == nil || c == nil {
		return
	}
	data := map[string]any{
		"cardId":     c.ID,
		"propertyId": c.PropertyID,
		"columnId":   c.ColumnID,
		"title":      c.Title,
		"isDone":     c.IsDone,
		"priority":   c.Priority,
		"kind":       c.Kind,
	}
	for k, v := range extra {
		data[k] = v
	}
	h.Dispatcher.Enqueue(webhooks.Event{
		Event:      event,
		PropertyID: c.PropertyID,
		OccurredAt: time.Now().UTC(),
		Data:       data,
	})
}
