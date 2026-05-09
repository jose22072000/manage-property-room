package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/jose/manage_property_room_api/internal/domain"
	"github.com/jose/manage_property_room_api/internal/httpx"
	"github.com/jose/manage_property_room_api/internal/store"
)

type CommentsHandler struct {
	Store store.Store
}

type createCommentRequest struct {
	Text string `json:"text"`
}

func (h *CommentsHandler) List(w http.ResponseWriter, r *http.Request) {
	cardID := chi.URLParam(r, "id")
	items, err := h.Store.Comments().ListByCard(r.Context(), cardID)
	if err != nil { httpx.HandleError(w, err); return }
	httpx.WriteJSON(w, http.StatusOK, items)
}

func (h *CommentsHandler) Create(w http.ResponseWriter, r *http.Request) {
	cardID := chi.URLParam(r, "id")
	var req createCommentRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", err.Error()); return
	}
	if req.Text == "" {
		httpx.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "text required"); return
	}
	c := &domain.Comment{
		ID: uuid.NewString(), CardID: cardID,
		AuthorID: httpx.UserIDFrom(r.Context()),
		Text: req.Text,
	}
	if err := h.Store.Comments().Create(r.Context(), c); err != nil {
		httpx.HandleError(w, err); return
	}
	httpx.WriteJSON(w, http.StatusCreated, c)
}

type ActivityHandler struct {
	Store store.Store
}

func (h *ActivityHandler) List(w http.ResponseWriter, r *http.Request) {
	cardID := chi.URLParam(r, "id")
	items, err := h.Store.Activity().ListByCard(r.Context(), cardID)
	if err != nil { httpx.HandleError(w, err); return }
	httpx.WriteJSON(w, http.StatusOK, items)
}

type ArchiveHandler struct {
	Store store.Store
}

func (h *ArchiveHandler) List(w http.ResponseWriter, r *http.Request) {
	items, err := h.Store.Archive().List(r.Context())
	if err != nil { httpx.HandleError(w, err); return }
	role := httpx.RoleFrom(r.Context())
	userID := httpx.UserIDFrom(r.Context())
	allowed, all := accessiblePropertyIDs(r.Context(), h.Store, userID, role)
	if !all {
		filtered := make([]domain.ArchiveItem, 0, len(items))
		for _, it := range items {
			pid, _ := it.Payload["propertyId"].(string)
			if _, ok := allowed[pid]; ok {
				filtered = append(filtered, it)
			}
		}
		items = filtered
	}
	httpx.WriteJSON(w, http.StatusOK, items)
}

func (h *ArchiveHandler) Restore(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	item, err := h.Store.Archive().GetByID(r.Context(), id)
	if err != nil { httpx.HandleError(w, err); return }
	switch item.Kind {
	case domain.ArchiveKindCard:
		var c domain.Card
		raw, _ := json.Marshal(item.Payload)
		if err := json.Unmarshal(raw, &c); err != nil {
			httpx.HandleError(w, err); return
		}
		c.Archived = false
		if err := h.Store.Cards().Update(r.Context(), &c); err != nil {
			httpx.HandleError(w, err); return
		}
	case domain.ArchiveKindColumn:
		var col domain.BoardColumn
		raw, _ := json.Marshal(item.Payload)
		if err := json.Unmarshal(raw, &col); err != nil {
			httpx.HandleError(w, err); return
		}
		col.Archived = false
		if err := h.Store.Columns().Update(r.Context(), &col); err != nil {
			httpx.HandleError(w, err); return
		}
	}
	if err := h.Store.Archive().Delete(r.Context(), id); err != nil {
		httpx.HandleError(w, err); return
	}
	recordAudit(r.Context(), h.Store, "restore", "archive", id, "")
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"ok": true})
}

func (h *ArchiveHandler) Delete(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	item, err := h.Store.Archive().GetByID(r.Context(), id)
	if err != nil { httpx.HandleError(w, err); return }
	detail := ""
	if item.Kind == domain.ArchiveKindCard {
		if v, ok := item.Payload["title"].(string); ok { detail = v }
	}
	if err := h.Store.Archive().Delete(r.Context(), id); err != nil {
		httpx.HandleError(w, err); return
	}
	recordAudit(r.Context(), h.Store, "delete", "archive", id, detail)
	w.WriteHeader(http.StatusNoContent)
}
