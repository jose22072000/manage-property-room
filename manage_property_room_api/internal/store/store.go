// Package store defines persistence interfaces. Implementations live in
// driver-specific subpackages (e.g. store/sqlite, store/postgres).
package store

import (
	"context"

	"github.com/jose/manage_property_room_api/internal/domain"
)

// Store aggregates all repositories used by handlers.
type Store interface {
	Users() UserRepo
	Properties() PropertyRepo
	Columns() ColumnRepo
	Cards() CardRepo
	Fields() FieldRepo
	Comments() CommentRepo
	Activity() ActivityRepo
	Archive() ArchiveRepo
	Audit() AuditRepo
	Groups() GroupRepo
	PropertySupervisors() PropertySupervisorRepo
	Webhooks() WebhookRepo
	InboundHooks() InboundHookRepo
	WebhookDeliveries() WebhookDeliveryRepo
	Close() error
}

type UserRepo interface {
	Create(ctx context.Context, u *domain.User) error
	GetByID(ctx context.Context, id string) (*domain.User, error)
	GetByEmail(ctx context.Context, email string) (*domain.User, error)
	List(ctx context.Context) ([]domain.User, error)
	ListCreatedBy(ctx context.Context, creatorID string, roles []domain.UserRole) ([]domain.User, error)
	Update(ctx context.Context, u *domain.User) error
	Delete(ctx context.Context, id string) error
	SetAssignedProperties(ctx context.Context, userID string, propertyIDs []string) error
	SetPasswordHash(ctx context.Context, userID, hash string, mustChange bool) error
	ListByProperty(ctx context.Context, propertyID string) ([]domain.User, error)
}

type PropertyRepo interface {
	Create(ctx context.Context, p *domain.Property) error
	GetByID(ctx context.Context, id string) (*domain.Property, error)
	List(ctx context.Context) ([]domain.Property, error)
	ListByOwner(ctx context.Context, ownerID string) ([]domain.Property, error)
	ListBySupervisor(ctx context.Context, supervisorID string) ([]domain.Property, error)
	Update(ctx context.Context, p *domain.Property) error
	Delete(ctx context.Context, id string) error
}

type ColumnRepo interface {
	Create(ctx context.Context, c *domain.BoardColumn) error
	GetByID(ctx context.Context, id string) (*domain.BoardColumn, error)
	ListByProperty(ctx context.Context, propertyID string) ([]domain.BoardColumn, error)
	Update(ctx context.Context, c *domain.BoardColumn) error
	Delete(ctx context.Context, id string) error
	Reorder(ctx context.Context, propertyID string, orderedIDs []string) error
}

type CardRepo interface {
	Create(ctx context.Context, c *domain.Card) error
	GetByID(ctx context.Context, id string) (*domain.Card, error)
	ListByColumn(ctx context.Context, columnID string) ([]domain.Card, error)
	ListByProperty(ctx context.Context, propertyID string) ([]domain.Card, error)
	Update(ctx context.Context, c *domain.Card) error
	Delete(ctx context.Context, id string) error
	MoveToColumn(ctx context.Context, cardID, targetColumnID string, position int) error
	Reorder(ctx context.Context, columnID string, orderedIDs []string) error
}

type FieldRepo interface {
	Create(ctx context.Context, f *domain.FieldDef) error
	GetByID(ctx context.Context, id string) (*domain.FieldDef, error)
	List(ctx context.Context) ([]domain.FieldDef, error)
	ListByOwner(ctx context.Context, ownerID string) ([]domain.FieldDef, error)
	Update(ctx context.Context, f *domain.FieldDef) error
	Delete(ctx context.Context, id string) error
	Reorder(ctx context.Context, orderedIDs []string) error
}

type CommentRepo interface {
	Create(ctx context.Context, c *domain.Comment) error
	ListByCard(ctx context.Context, cardID string) ([]domain.Comment, error)
	Delete(ctx context.Context, id string) error
}

type ActivityRepo interface {
	Create(ctx context.Context, e *domain.ActivityEvent) error
	ListByCard(ctx context.Context, cardID string) ([]domain.ActivityEvent, error)
}

type ArchiveRepo interface {
	Create(ctx context.Context, item *domain.ArchiveItem) error
	List(ctx context.Context) ([]domain.ArchiveItem, error)
	GetByID(ctx context.Context, id string) (*domain.ArchiveItem, error)
	Delete(ctx context.Context, id string) error
}

type AuditRepo interface {
	Create(ctx context.Context, e *domain.AuditEvent) error
	List(ctx context.Context, limit int) ([]domain.AuditEvent, error)
	ListByPropertyIDs(ctx context.Context, propertyIDs []string, limit int) ([]domain.AuditEvent, error)
	Delete(ctx context.Context, id string) error
}

type GroupRepo interface {
	Create(ctx context.Context, g *domain.Group) error
	GetByID(ctx context.Context, id string) (*domain.Group, error)
	List(ctx context.Context) ([]domain.Group, error)
	Update(ctx context.Context, g *domain.Group) error
	Delete(ctx context.Context, id string) error
	SetUsers(ctx context.Context, groupID string, userIDs []string) error
	SetProperties(ctx context.Context, groupID string, propertyIDs []string) error
	ListPropertiesForUser(ctx context.Context, userID string) ([]string, error)
	ListForSupervisor(ctx context.Context, supervisorID string) ([]domain.Group, error)
	ListByCreators(ctx context.Context, creatorIDs []string) ([]domain.Group, error)
}

type PropertySupervisorRepo interface {
	SetSupervisors(ctx context.Context, propertyID string, supervisorIDs []string) error
	ListForProperty(ctx context.Context, propertyID string) ([]string, error)
	ListPropertiesForSupervisor(ctx context.Context, supervisorID string) ([]string, error)
}

type WebhookRepo interface {
	Create(ctx context.Context, w *domain.Webhook) error
	GetByID(ctx context.Context, id string) (*domain.Webhook, error)
	List(ctx context.Context) ([]domain.Webhook, error)
	ListActiveForEvent(ctx context.Context, event, propertyID string) ([]domain.Webhook, error)
	Update(ctx context.Context, w *domain.Webhook) error
	Delete(ctx context.Context, id string) error
}

type InboundHookRepo interface {
	Create(ctx context.Context, h *domain.InboundHook) error
	GetByID(ctx context.Context, id string) (*domain.InboundHook, error)
	GetByToken(ctx context.Context, token string) (*domain.InboundHook, error)
	List(ctx context.Context) ([]domain.InboundHook, error)
	Update(ctx context.Context, h *domain.InboundHook) error
	Delete(ctx context.Context, id string) error
}

type WebhookDeliveryRepo interface {
	Create(ctx context.Context, d *domain.WebhookDelivery) error
	Update(ctx context.Context, d *domain.WebhookDelivery) error
	ListByWebhook(ctx context.Context, webhookID string, limit int) ([]domain.WebhookDelivery, error)
}
