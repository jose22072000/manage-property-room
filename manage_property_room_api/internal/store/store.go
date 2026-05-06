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
	Close() error
}

type UserRepo interface {
	Create(ctx context.Context, u *domain.User) error
	GetByID(ctx context.Context, id string) (*domain.User, error)
	GetByEmail(ctx context.Context, email string) (*domain.User, error)
	List(ctx context.Context) ([]domain.User, error)
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
}

type FieldRepo interface {
	Create(ctx context.Context, f *domain.FieldDef) error
	GetByID(ctx context.Context, id string) (*domain.FieldDef, error)
	List(ctx context.Context) ([]domain.FieldDef, error)
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
