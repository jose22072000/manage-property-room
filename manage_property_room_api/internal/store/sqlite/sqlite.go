package sqlite

import (
	"database/sql"
	"embed"
	"errors"
	"fmt"
	"os"
	"path/filepath"

	"github.com/golang-migrate/migrate/v4"
	migsqlite "github.com/golang-migrate/migrate/v4/database/sqlite3"
	"github.com/golang-migrate/migrate/v4/source/iofs"
	"github.com/jmoiron/sqlx"
	_ "github.com/mattn/go-sqlite3"

	"github.com/jose/manage_property_room_api/internal/store"
)

//go:embed migrations/*.sql
var migrationsFS embed.FS

type Store struct {
	db *sqlx.DB

	users      *userRepo
	properties *propertyRepo
	columns    *columnRepo
	cards      *cardRepo
	fields     *fieldRepo
	comments   *commentRepo
	activity   *activityRepo
	archive    *archiveRepo
	audit      *auditRepo
}

// Open opens a SQLite DB at dsn (file path or ":memory:"), applies pragmas,
// runs migrations, and returns a ready Store.
func Open(dsn string) (*Store, error) {
	if dsn != ":memory:" {
		if dir := filepath.Dir(dsn); dir != "" && dir != "." {
			if err := os.MkdirAll(dir, 0o755); err != nil {
				return nil, fmt.Errorf("mkdir %s: %w", dir, err)
			}
		}
	}
	connStr := dsn + "?_journal_mode=WAL&_foreign_keys=on&_busy_timeout=5000"
	db, err := sqlx.Open("sqlite3", connStr)
	if err != nil {
		return nil, fmt.Errorf("open sqlite: %w", err)
	}
	if err := db.Ping(); err != nil {
		return nil, fmt.Errorf("ping sqlite: %w", err)
	}
	if err := migrateUp(db.DB); err != nil {
		return nil, fmt.Errorf("migrate: %w", err)
	}
	s := &Store{db: db}
	s.users = &userRepo{db: db}
	s.properties = &propertyRepo{db: db}
	s.columns = &columnRepo{db: db}
	s.cards = &cardRepo{db: db}
	s.fields = &fieldRepo{db: db}
	s.comments = &commentRepo{db: db}
	s.activity = &activityRepo{db: db}
	s.archive = &archiveRepo{db: db}
	s.audit = &auditRepo{db: db}
	return s, nil
}

func migrateUp(db *sql.DB) error {
	src, err := iofs.New(migrationsFS, "migrations")
	if err != nil {
		return err
	}
	driver, err := migsqlite.WithInstance(db, &migsqlite.Config{})
	if err != nil {
		return err
	}
	m, err := migrate.NewWithInstance("iofs", src, "sqlite3", driver)
	if err != nil {
		return err
	}
	if err := m.Up(); err != nil && !errors.Is(err, migrate.ErrNoChange) {
		return err
	}
	return nil
}

func (s *Store) Close() error                   { return s.db.Close() }
func (s *Store) Users() store.UserRepo          { return s.users }
func (s *Store) Properties() store.PropertyRepo { return s.properties }
func (s *Store) Columns() store.ColumnRepo      { return s.columns }
func (s *Store) Cards() store.CardRepo          { return s.cards }
func (s *Store) Fields() store.FieldRepo        { return s.fields }
func (s *Store) Comments() store.CommentRepo    { return s.comments }
func (s *Store) Activity() store.ActivityRepo   { return s.activity }
func (s *Store) Archive() store.ArchiveRepo     { return s.archive }
func (s *Store) Audit() store.AuditRepo         { return s.audit }
