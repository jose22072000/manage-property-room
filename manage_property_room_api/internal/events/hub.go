// Package events provides an in-memory pub/sub hub for Server-Sent Events.
// Every authenticated client connects to GET /events and receives a stream of
// JSON-encoded Event objects in real time whenever a mutation occurs anywhere
// in the API.
//
// Redis upgrade path: replace Publish() with a Redis PUBLISH call and run a
// background goroutine that SUBSCRIBE's and forwards to the in-process clients.
// The Hub struct and Subscribe/Unsubscribe API stay identical.
package events

import (
	"encoding/json"
	"sync"

	"github.com/google/uuid"
)

// Event is the payload broadcast to all connected SSE clients.
type Event struct {
	Type       string `json:"type"`                // e.g. "card.updated"
	Entity     string `json:"entity"`              // "card" | "column" | "property" | ...
	EntityID   string `json:"entityId"`
	PropertyID string `json:"propertyId,omitempty"` // set for board-scoped events
	ActorID    string `json:"actorId,omitempty"`
}

// Hub manages all active SSE connections and broadcasts events to them.
type Hub struct {
	mu      sync.RWMutex
	clients map[string]chan []byte
}

// Default is the process-wide Hub singleton used by all handlers.
var Default = &Hub{
	clients: make(map[string]chan []byte),
}

// Subscribe registers a new client and returns a read-only channel that
// delivers serialised Event JSON. The caller must call Unsubscribe when done.
func (h *Hub) Subscribe() (id string, ch <-chan []byte) {
	id = uuid.NewString()
	c := make(chan []byte, 64)
	h.mu.Lock()
	h.clients[id] = c
	h.mu.Unlock()
	return id, c
}

// Unsubscribe removes the client and closes its channel.
func (h *Hub) Unsubscribe(id string) {
	h.mu.Lock()
	if c, ok := h.clients[id]; ok {
		close(c)
		delete(h.clients, id)
	}
	h.mu.Unlock()
}

// Publish serialises e and fans it out to every connected client.
// Slow clients that cannot keep up are skipped (non-blocking send).
func (h *Hub) Publish(e Event) {
	data, err := json.Marshal(e)
	if err != nil {
		return
	}
	h.mu.RLock()
	defer h.mu.RUnlock()
	for _, c := range h.clients {
		select {
		case c <- data:
		default: // drop for slow/overloaded client
		}
	}
}

// Publish is a package-level convenience that uses the Default hub.
func Publish(e Event) { Default.Publish(e) }
