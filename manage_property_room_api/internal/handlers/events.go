package handlers

import (
	"fmt"
	"net/http"
	"time"

	"github.com/jose/manage_property_room_api/internal/events"
)

// EventsHandler streams Server-Sent Events to connected clients.
type EventsHandler struct{}

// Stream upgrades the HTTP connection to an SSE stream.
// Auth is enforced by the RequireAuth middleware on the route.
//
// Each connected client receives every mutation event in real time.
// The client is responsible for deciding which events are relevant
// (e.g. filter by propertyId) and refreshing the affected data.
func (h *EventsHandler) Stream(w http.ResponseWriter, r *http.Request) {
	flusher, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "streaming not supported", http.StatusInternalServerError)
		return
	}

	// SSE headers — disable nginx buffering for pass-through setups.
	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")
	w.Header().Set("X-Accel-Buffering", "no")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.WriteHeader(http.StatusOK)

	id, ch := events.Default.Subscribe()
	defer events.Default.Unsubscribe(id)

	// Initial keep-alive comment so the client knows the connection is live.
	fmt.Fprintf(w, ": connected\n\n")
	flusher.Flush()

	// Keep-alive ticker — prevents proxies from closing idle connections.
	ticker := time.NewTicker(25 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-r.Context().Done():
			return
		case data, ok := <-ch:
			if !ok {
				return
			}
			fmt.Fprintf(w, "data: %s\n\n", data)
			flusher.Flush()
		case <-ticker.C:
			fmt.Fprintf(w, ": ping\n\n")
			flusher.Flush()
		}
	}
}
