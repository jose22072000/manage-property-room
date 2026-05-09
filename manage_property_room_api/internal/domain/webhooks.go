package domain

import "time"

// Webhook event constants. Mirror these in Flutter UI.
const (
	WebhookEventCardCompleted   = "card.completed"
	WebhookEventCardUncompleted = "card.uncompleted"
	WebhookEventCardCreated     = "card.created"
	WebhookEventCardArchived    = "card.archived"
	WebhookEventCardMoved       = "card.moved"
)

// AllWebhookEvents lists every event the API can dispatch.
var AllWebhookEvents = []string{
	WebhookEventCardCompleted,
	WebhookEventCardUncompleted,
	WebhookEventCardCreated,
	WebhookEventCardArchived,
	WebhookEventCardMoved,
}

// Webhook is an outbound HTTP callback registered by an admin/owner. The
// dispatcher signs the payload with HMAC-SHA256 using `Secret` and POSTs to
// `URL` whenever an event matching `Events` fires for `PropertyID` (or all
// properties when `PropertyID` is empty).
type Webhook struct {
	ID         string    `json:"id" db:"id"`
	Name       string    `json:"name" db:"name"`
	URL        string    `json:"url" db:"url"`
	Secret     string    `json:"secret" db:"secret"`
	Events     []string  `json:"events" db:"-"`
	PropertyID string    `json:"propertyId,omitempty" db:"property_id"`
	Active     bool      `json:"active" db:"active"`
	CreatedBy  string    `json:"createdBy" db:"created_by"`
	CreatedAt  time.Time `json:"createdAt" db:"created_at"`
	UpdatedAt  time.Time `json:"updatedAt" db:"updated_at"`
}

// WebhookDelivery records one dispatch attempt for debugging.
type WebhookDelivery struct {
	ID         string    `json:"id" db:"id"`
	WebhookID  string    `json:"webhookId" db:"webhook_id"`
	Event      string    `json:"event" db:"event"`
	Payload    string    `json:"payload" db:"payload"`
	Status     string    `json:"status" db:"status"`
	HTTPCode   int       `json:"httpCode" db:"http_code"`
	Attempts   int       `json:"attempts" db:"attempts"`
	LastError  string    `json:"lastError,omitempty" db:"last_error"`
	CreatedAt  time.Time `json:"createdAt" db:"created_at"`
	UpdatedAt  time.Time `json:"updatedAt" db:"updated_at"`
}

// InboundHook is a token-protected endpoint that lets external systems
// create cards in a specific column. The token is unique and acts as the
// secret for non-HMAC integrations; if `Secret` is non-empty the dispatcher
// requires an `X-PMR-Signature` header validated against it.
type InboundHook struct {
	ID         string    `json:"id" db:"id"`
	Name       string    `json:"name" db:"name"`
	Token      string    `json:"token" db:"token"`
	Secret     string    `json:"secret" db:"secret"`
	PropertyID string    `json:"propertyId" db:"property_id"`
	ColumnID   string    `json:"columnId" db:"column_id"`
	Active     bool      `json:"active" db:"active"`
	CreatedBy  string    `json:"createdBy" db:"created_by"`
	CreatedAt  time.Time `json:"createdAt" db:"created_at"`
	UpdatedAt  time.Time `json:"updatedAt" db:"updated_at"`
}
