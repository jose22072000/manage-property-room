package handlers

import (
	"encoding/json"
	"errors"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/jose/manage_property_room_api/internal/domain"
	"github.com/jose/manage_property_room_api/internal/httpx"
	"github.com/jose/manage_property_room_api/internal/store"
)

type ColumnsHandler struct {
	Store store.Store
}

type createColumnRequest struct {
	Title       string             `json:"title"`
	Color       domain.ColumnColor `json:"color"`
	Position    int                `json:"position"`
	Description string             `json:"description"`
	FieldIDs    []string           `json:"fieldIds,omitempty"`
	Config      *domain.ColumnConfig `json:"columnConfig,omitempty"`
}

type updateColumnRequest struct {
	Title       *string               `json:"title,omitempty"`
	Color       *domain.ColumnColor   `json:"color,omitempty"`
	Position    *int                  `json:"position,omitempty"`
	Description *string               `json:"description,omitempty"`
	FieldIDs    *[]string             `json:"fieldIds,omitempty"`
	Config      *domain.ColumnConfig  `json:"columnConfig,omitempty"`
	Archived    *bool                 `json:"archived,omitempty"`
}

func (h *ColumnsHandler) Create(w http.ResponseWriter, r *http.Request) {
	propertyID := chi.URLParam(r, "id")
	var req createColumnRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", err.Error()); return
	}
	if req.Title == "" {
		httpx.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "title required"); return
	}
	if req.Color == "" { req.Color = domain.ColorBlue }
	c := &domain.BoardColumn{
		ID: uuid.NewString(), PropertyID: propertyID,
		Title: req.Title, Color: req.Color, Position: req.Position,
		Description: req.Description, FieldIDs: req.FieldIDs, Config: req.Config,
	}
	if err := h.Store.Columns().Create(r.Context(), c); err != nil {
		httpx.HandleError(w, err); return
	}
	httpx.WriteJSON(w, http.StatusCreated, c)
}

func (h *ColumnsHandler) Update(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	c, err := h.Store.Columns().GetByID(r.Context(), id)
	if err != nil { httpx.HandleError(w, err); return }
	var req updateColumnRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", err.Error()); return
	}
	if req.Title != nil { c.Title = *req.Title }
	if req.Color != nil { c.Color = *req.Color }
	if req.Position != nil { c.Position = *req.Position }
	if req.Description != nil { c.Description = *req.Description }
	if req.FieldIDs != nil { c.FieldIDs = *req.FieldIDs }
	if req.Config != nil { c.Config = req.Config }
	if req.Archived != nil { c.Archived = *req.Archived }
	if err := h.Store.Columns().Update(r.Context(), c); err != nil {
		httpx.HandleError(w, err); return
	}
	httpx.WriteJSON(w, http.StatusOK, c)
}

func (h *ColumnsHandler) Delete(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	if err := h.Store.Columns().Delete(r.Context(), id); err != nil {
		httpx.HandleError(w, err); return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *ColumnsHandler) Duplicate(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	src, err := h.Store.Columns().GetByID(r.Context(), id)
	if err != nil { httpx.HandleError(w, err); return }
	dup := *src
	dup.ID = uuid.NewString()
	dup.Title = src.Title + " (copia)"
	dup.Position = src.Position + 1
	dup.CreatedAt = time.Time{}
	if err := h.Store.Columns().Create(r.Context(), &dup); err != nil {
		httpx.HandleError(w, err); return
	}
	cards, err := h.Store.Cards().ListByColumn(r.Context(), id)
	if err != nil { httpx.HandleError(w, err); return }
	for _, c := range cards {
		c.ID = uuid.NewString()
		c.ColumnID = dup.ID
		c.CreatedAt = time.Time{}
		if err := h.Store.Cards().Create(r.Context(), &c); err != nil {
			httpx.HandleError(w, err); return
		}
	}
	httpx.WriteJSON(w, http.StatusCreated, dup)
}

func (h *ColumnsHandler) CopyTo(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	targetPropertyID := chi.URLParam(r, "propertyId")
	src, err := h.Store.Columns().GetByID(r.Context(), id)
	if err != nil { httpx.HandleError(w, err); return }
	dup := *src
	dup.ID = uuid.NewString()
	dup.PropertyID = targetPropertyID
	dup.CreatedAt = time.Time{}
	if err := h.Store.Columns().Create(r.Context(), &dup); err != nil {
		httpx.HandleError(w, err); return
	}
	cards, err := h.Store.Cards().ListByColumn(r.Context(), id)
	if err != nil { httpx.HandleError(w, err); return }
	for _, c := range cards {
		c.ID = uuid.NewString()
		c.ColumnID = dup.ID
		c.PropertyID = targetPropertyID
		c.CreatedAt = time.Time{}
		if err := h.Store.Cards().Create(r.Context(), &c); err != nil {
			httpx.HandleError(w, err); return
		}
	}
	httpx.WriteJSON(w, http.StatusCreated, dup)
}

type movePositionRequest struct {
	NewPosition int `json:"newPosition"`
}

func (h *ColumnsHandler) Move(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	var req movePositionRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", err.Error()); return
	}
	c, err := h.Store.Columns().GetByID(r.Context(), id)
	if err != nil { httpx.HandleError(w, err); return }
	c.Position = req.NewPosition
	if err := h.Store.Columns().Update(r.Context(), c); err != nil {
		httpx.HandleError(w, err); return
	}
	httpx.WriteJSON(w, http.StatusOK, c)
}

func (h *ColumnsHandler) MoveAllCards(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	targetID := chi.URLParam(r, "targetId")
	cards, err := h.Store.Cards().ListByColumn(r.Context(), id)
	if err != nil { httpx.HandleError(w, err); return }
	for i, c := range cards {
		if err := h.Store.Cards().MoveToColumn(r.Context(), c.ID, targetID, i); err != nil {
			httpx.HandleError(w, err); return
		}
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"moved": len(cards)})
}

func (h *ColumnsHandler) ArchiveAllCards(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	cards, err := h.Store.Cards().ListByColumn(r.Context(), id)
	if err != nil { httpx.HandleError(w, err); return }
	for _, c := range cards {
		if err := archiveCard(r, h.Store, &c); err != nil {
			httpx.HandleError(w, err); return
		}
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"archived": len(cards)})
}

func (h *ColumnsHandler) Archive(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	c, err := h.Store.Columns().GetByID(r.Context(), id)
	if err != nil { httpx.HandleError(w, err); return }
	c.Archived = true
	if err := h.Store.Columns().Update(r.Context(), c); err != nil {
		httpx.HandleError(w, err); return
	}
	payload, _ := json.Marshal(c)
	var pl map[string]any
	_ = json.Unmarshal(payload, &pl)
	if err := h.Store.Archive().Create(r.Context(), &domain.ArchiveItem{
		ID: uuid.NewString(), Kind: domain.ArchiveKindColumn, Payload: pl,
	}); err != nil {
		httpx.HandleError(w, err); return
	}
	httpx.WriteJSON(w, http.StatusOK, c)
}

func (h *ColumnsHandler) SetConfig(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	c, err := h.Store.Columns().GetByID(r.Context(), id)
	if err != nil { httpx.HandleError(w, err); return }
	var req struct {
		Config *domain.ColumnConfig `json:"columnConfig"`
	}
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", err.Error()); return
	}
	c.Config = req.Config
	if err := h.Store.Columns().Update(r.Context(), c); err != nil {
		httpx.HandleError(w, err); return
	}
	httpx.WriteJSON(w, http.StatusOK, c)
}

// archiveCard is reused by ColumnsHandler and CardsHandler.
func archiveCard(r *http.Request, s store.Store, c *domain.Card) error {
	if c == nil { return errors.New("nil card") }
	c.Archived = true
	if err := s.Cards().Update(r.Context(), c); err != nil {
		return err
	}
	payload, _ := json.Marshal(c)
	var pl map[string]any
	_ = json.Unmarshal(payload, &pl)
	return s.Archive().Create(r.Context(), &domain.ArchiveItem{
		ID: uuid.NewString(), Kind: domain.ArchiveKindCard, Payload: pl,
	})
}
