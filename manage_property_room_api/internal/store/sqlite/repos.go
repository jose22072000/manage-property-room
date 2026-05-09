package sqlite

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/jmoiron/sqlx"

	"github.com/jose/manage_property_room_api/internal/domain"
	"github.com/jose/manage_property_room_api/internal/store"
)

// ── helpers ──────────────────────────────────────────────────────────────────

func wrapNotFound(err error) error {
	if errors.Is(err, sql.ErrNoRows) {
		return store.ErrNotFound
	}
	return err
}

func nowUTC() time.Time { return time.Now().UTC() }

func boolToInt(b bool) int { if b { return 1 }; return 0 }

func ptrStr(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}

func marshalJSON(v any) (string, error) {
	if v == nil {
		return "", nil
	}
	b, err := json.Marshal(v)
	return string(b), err
}

// ── users ────────────────────────────────────────────────────────────────────

type userRepo struct{ db *sqlx.DB }

type userRow struct {
	ID                 string `db:"id"`
	Email              string `db:"email"`
	PasswordHash       string `db:"password_hash"`
	Name               string `db:"name"`
	Initials           string `db:"initials"`
	Role               string `db:"role"`
	MustChangePassword int     `db:"must_change_password"`
	CreatedBy          *string `db:"created_by"`
	CreatedAt          string  `db:"created_at"`
	UpdatedAt          string `db:"updated_at"`
}

func (r userRow) toDomain(assigned []string) *domain.User {
	created, _ := time.Parse(time.RFC3339Nano, r.CreatedAt)
	updated, _ := time.Parse(time.RFC3339Nano, r.UpdatedAt)
	return &domain.User{
		ID: r.ID, Email: r.Email, PasswordHash: r.PasswordHash,
		Name: r.Name, Initials: r.Initials, Role: domain.UserRole(r.Role),
		MustChangePassword: r.MustChangePassword == 1,
		CreatedBy: ptrStr(r.CreatedBy),
		AssignedPropertyIDs: assigned,
		CreatedAt: created, UpdatedAt: updated,
	}
}

func (r *userRepo) Create(ctx context.Context, u *domain.User) error {
	if u.CreatedAt.IsZero() {
		u.CreatedAt = nowUTC()
	}
	u.UpdatedAt = nowUTC()
	_, err := r.db.ExecContext(ctx,
		`INSERT INTO users(id,email,password_hash,name,initials,role,must_change_password,created_by,created_at,updated_at)
		 VALUES(?,?,?,?,?,?,?,?,?,?)`,
		u.ID, u.Email, u.PasswordHash, u.Name, u.Initials, string(u.Role),
		boolToInt(u.MustChangePassword), u.CreatedBy,
		u.CreatedAt.Format(time.RFC3339Nano), u.UpdatedAt.Format(time.RFC3339Nano))
	if err != nil {
		if strings.Contains(err.Error(), "UNIQUE") {
			return store.ErrConflict
		}
		return err
	}
	return r.SetAssignedProperties(ctx, u.ID, u.AssignedPropertyIDs)
}

func (r *userRepo) GetByID(ctx context.Context, id string) (*domain.User, error) {
	var row userRow
	if err := r.db.GetContext(ctx, &row, `SELECT * FROM users WHERE id=?`, id); err != nil {
		return nil, wrapNotFound(err)
	}
	assigned, err := r.assignedFor(ctx, id)
	if err != nil { return nil, err }
	return row.toDomain(assigned), nil
}

func (r *userRepo) GetByEmail(ctx context.Context, email string) (*domain.User, error) {
	var row userRow
	if err := r.db.GetContext(ctx, &row, `SELECT * FROM users WHERE email=?`, strings.ToLower(email)); err != nil {
		return nil, wrapNotFound(err)
	}
	assigned, err := r.assignedFor(ctx, row.ID)
	if err != nil { return nil, err }
	return row.toDomain(assigned), nil
}

func (r *userRepo) List(ctx context.Context) ([]domain.User, error) {
	var rows []userRow
	if err := r.db.SelectContext(ctx, &rows, `SELECT * FROM users ORDER BY created_at`); err != nil {
		return nil, err
	}
	out := make([]domain.User, 0, len(rows))
	for _, row := range rows {
		assigned, err := r.assignedFor(ctx, row.ID)
		if err != nil { return nil, err }
		out = append(out, *row.toDomain(assigned))
	}
	return out, nil
}

func (r *userRepo) Update(ctx context.Context, u *domain.User) error {
	u.UpdatedAt = nowUTC()
	res, err := r.db.ExecContext(ctx,
		`UPDATE users SET email=?,name=?,initials=?,role=?,must_change_password=?,updated_at=? WHERE id=?`,
		u.Email, u.Name, u.Initials, string(u.Role), boolToInt(u.MustChangePassword),
		u.UpdatedAt.Format(time.RFC3339Nano), u.ID)
	if err != nil { return err }
	n, _ := res.RowsAffected()
	if n == 0 { return store.ErrNotFound }
	return r.SetAssignedProperties(ctx, u.ID, u.AssignedPropertyIDs)
}

func (r *userRepo) Delete(ctx context.Context, id string) error {
	res, err := r.db.ExecContext(ctx, `DELETE FROM users WHERE id=?`, id)
	if err != nil { return err }
	if n, _ := res.RowsAffected(); n == 0 { return store.ErrNotFound }
	return nil
}

func (r *userRepo) SetAssignedProperties(ctx context.Context, userID string, propertyIDs []string) error {
	tx, err := r.db.BeginTxx(ctx, nil)
	if err != nil { return err }
	defer tx.Rollback() //nolint:errcheck
	if _, err := tx.ExecContext(ctx, `DELETE FROM user_property_assignments WHERE user_id=?`, userID); err != nil {
		return err
	}
	for _, pid := range propertyIDs {
		if _, err := tx.ExecContext(ctx,
			`INSERT INTO user_property_assignments(user_id,property_id) VALUES(?,?)`, userID, pid); err != nil {
			return err
		}
	}
	return tx.Commit()
}

func (r *userRepo) SetPasswordHash(ctx context.Context, userID, hash string, mustChange bool) error {
	res, err := r.db.ExecContext(ctx,
		`UPDATE users SET password_hash=?, must_change_password=?, updated_at=? WHERE id=?`,
		hash, boolToInt(mustChange), nowUTC().Format(time.RFC3339Nano), userID)
	if err != nil { return err }
	if n, _ := res.RowsAffected(); n == 0 { return store.ErrNotFound }
	return nil
}

func (r *userRepo) assignedFor(ctx context.Context, userID string) ([]string, error) {
	var ids []string
	err := r.db.SelectContext(ctx, &ids,
		`SELECT property_id FROM user_property_assignments WHERE user_id=? ORDER BY property_id`, userID)
	return ids, err
}

func (r *userRepo) ListByProperty(ctx context.Context, propertyID string) ([]domain.User, error) {
	var rows []userRow
	if err := r.db.SelectContext(ctx, &rows,
		`SELECT u.* FROM users u
		 INNER JOIN user_property_assignments a ON a.user_id = u.id
		 WHERE a.property_id = ?
		 ORDER BY u.name`, propertyID); err != nil {
		return nil, err
	}
	out := make([]domain.User, 0, len(rows))
	for _, row := range rows {
		assigned, err := r.assignedFor(ctx, row.ID)
		if err != nil { return nil, err }
		out = append(out, *row.toDomain(assigned))
	}
	return out, nil
}

func (r *userRepo) ListCreatedBy(ctx context.Context, creatorID string, roles []domain.UserRole) ([]domain.User, error) {
	if len(roles) == 0 {
		return nil, nil
	}
	placeholders := make([]string, len(roles))
	args := []any{creatorID}
	for i, role := range roles {
		placeholders[i] = "?"
		args = append(args, string(role))
	}
	q := fmt.Sprintf(
		`SELECT * FROM users WHERE created_by=? AND role IN (%s) ORDER BY created_at`,
		strings.Join(placeholders, ","))
	var rows []userRow
	if err := r.db.SelectContext(ctx, &rows, q, args...); err != nil {
		return nil, err
	}
	out := make([]domain.User, 0, len(rows))
	for _, row := range rows {
		assigned, err := r.assignedFor(ctx, row.ID)
		if err != nil { return nil, err }
		out = append(out, *row.toDomain(assigned))
	}
	return out, nil
}

// ── properties ───────────────────────────────────────────────────────────────

type propertyRepo struct{ db *sqlx.DB }

type propertyRow struct {
	ID          string  `db:"id"`
	Code        string  `db:"code"`
	Name        string  `db:"name"`
	TotalRooms  int     `db:"total_rooms"`
	ColorSeed   int     `db:"color_seed"`
	Position    int     `db:"position"`
	Archived    int     `db:"archived"`
	OwnerUserID *string `db:"owner_user_id"`
	ImageURL    string  `db:"image_url"`
	CreatedAt   string  `db:"created_at"`
	UpdatedAt   string  `db:"updated_at"`
}

func (r propertyRow) toDomain() *domain.Property {
	created, _ := time.Parse(time.RFC3339Nano, r.CreatedAt)
	updated, _ := time.Parse(time.RFC3339Nano, r.UpdatedAt)
	return &domain.Property{
		ID: r.ID, Code: r.Code, Name: r.Name, TotalRooms: r.TotalRooms,
		ColorSeed: r.ColorSeed, Position: r.Position, Archived: r.Archived == 1,
		OwnerUserID: ptrStr(r.OwnerUserID), ImageURL: r.ImageURL,
		CreatedAt: created, UpdatedAt: updated,
	}
}

func (r *propertyRepo) Create(ctx context.Context, p *domain.Property) error {
	if p.CreatedAt.IsZero() { p.CreatedAt = nowUTC() }
	p.UpdatedAt = nowUTC()
	_, err := r.db.ExecContext(ctx,
		`INSERT INTO properties(id,code,name,total_rooms,color_seed,position,archived,owner_user_id,image_url,created_at,updated_at)
		 VALUES(?,?,?,?,?,?,?,?,?,?,?)`,
		p.ID, p.Code, p.Name, p.TotalRooms, p.ColorSeed, p.Position, boolToInt(p.Archived),
		p.OwnerUserID, p.ImageURL,
		p.CreatedAt.Format(time.RFC3339Nano), p.UpdatedAt.Format(time.RFC3339Nano))
	return err
}

func (r *propertyRepo) GetByID(ctx context.Context, id string) (*domain.Property, error) {
	var row propertyRow
	if err := r.db.GetContext(ctx, &row, `SELECT * FROM properties WHERE id=?`, id); err != nil {
		return nil, wrapNotFound(err)
	}
	return row.toDomain(), nil
}

func (r *propertyRepo) List(ctx context.Context) ([]domain.Property, error) {
	var rows []propertyRow
	if err := r.db.SelectContext(ctx, &rows, `SELECT * FROM properties ORDER BY position, created_at`); err != nil {
		return nil, err
	}
	out := make([]domain.Property, 0, len(rows))
	for _, row := range rows { out = append(out, *row.toDomain()) }
	return enrichSupervisorIDs(ctx, r.db, out)
}

func (r *propertyRepo) Update(ctx context.Context, p *domain.Property) error {
	p.UpdatedAt = nowUTC()
	res, err := r.db.ExecContext(ctx,
		`UPDATE properties SET code=?,name=?,total_rooms=?,color_seed=?,position=?,archived=?,owner_user_id=?,image_url=?,updated_at=? WHERE id=?`,
		p.Code, p.Name, p.TotalRooms, p.ColorSeed, p.Position, boolToInt(p.Archived),
		p.OwnerUserID, p.ImageURL,
		p.UpdatedAt.Format(time.RFC3339Nano), p.ID)
	if err != nil { return err }
	if n, _ := res.RowsAffected(); n == 0 { return store.ErrNotFound }
	return nil
}

func (r *propertyRepo) ListByOwner(ctx context.Context, ownerID string) ([]domain.Property, error) {
	var rows []propertyRow
	if err := r.db.SelectContext(ctx, &rows,
		`SELECT * FROM properties WHERE owner_user_id=? ORDER BY position, created_at`, ownerID); err != nil {
		return nil, err
	}
	out := make([]domain.Property, 0, len(rows))
	for _, row := range rows { out = append(out, *row.toDomain()) }
	return enrichSupervisorIDs(ctx, r.db, out)
}

func (r *propertyRepo) ListBySupervisor(ctx context.Context, supervisorID string) ([]domain.Property, error) {
	var ids []string
	if err := r.db.SelectContext(ctx, &ids,
		`SELECT property_id FROM property_supervisors WHERE supervisor_id=?`, supervisorID); err != nil {
		return nil, err
	}
	if len(ids) == 0 {
		return nil, nil
	}
	placeholders := make([]string, len(ids))
	args := make([]any, len(ids))
	for i, id := range ids { placeholders[i] = "?"; args[i] = id }
	q := fmt.Sprintf(`SELECT * FROM properties WHERE id IN (%s) ORDER BY position, created_at`,
		strings.Join(placeholders, ","))
	var propRows []propertyRow
	if err := r.db.SelectContext(ctx, &propRows, q, args...); err != nil {
		return nil, err
	}
	out := make([]domain.Property, 0, len(propRows))
	for _, row := range propRows { out = append(out, *row.toDomain()) }
	return enrichSupervisorIDs(ctx, r.db, out)
}

func (r *propertyRepo) Delete(ctx context.Context, id string) error {
	res, err := r.db.ExecContext(ctx, `DELETE FROM properties WHERE id=?`, id)
	if err != nil { return err }
	if n, _ := res.RowsAffected(); n == 0 { return store.ErrNotFound }
	return nil
}

// ── columns ──────────────────────────────────────────────────────────────────

// enrichSupervisorIDs loads supervisor IDs for a slice of properties in a
// single query and sets SupervisorIDs on each property.
func enrichSupervisorIDs(ctx context.Context, db *sqlx.DB, props []domain.Property) ([]domain.Property, error) {
	if len(props) == 0 {
		return props, nil
	}
	type psRow struct {
		PropertyID   string `db:"property_id"`
		SupervisorID string `db:"supervisor_id"`
	}
	ids := make([]any, len(props))
	for i, p := range props { ids[i] = p.ID }
	placeholders := make([]string, len(ids))
	for i := range ids { placeholders[i] = "?" }
	q := fmt.Sprintf(`SELECT property_id, supervisor_id FROM property_supervisors WHERE property_id IN (%s)`,
		strings.Join(placeholders, ","))
	var psRows []psRow
	if err := db.SelectContext(ctx, &psRows, q, ids...); err != nil {
		return nil, err
	}
	m := make(map[string][]string, len(props))
	for _, r := range psRows {
		m[r.PropertyID] = append(m[r.PropertyID], r.SupervisorID)
	}
	for i := range props {
		props[i].SupervisorIDs = m[props[i].ID]
		if props[i].SupervisorIDs == nil { props[i].SupervisorIDs = []string{} }
	}
	return props, nil
}

type columnRepo struct{ db *sqlx.DB }

type columnRow struct {
	ID           string         `db:"id"`
	PropertyID   string         `db:"property_id"`
	Title        string         `db:"title"`
	Color        string         `db:"color"`
	Position     int            `db:"position"`
	Description  string         `db:"description"`
	Archived     int            `db:"archived"`
	FieldIDsJSON sql.NullString `db:"field_ids_json"`
	ConfigJSON   sql.NullString `db:"config_json"`
	CreatedAt    string         `db:"created_at"`
	UpdatedAt    string         `db:"updated_at"`
}

func (r columnRow) toDomain() (*domain.BoardColumn, error) {
	created, _ := time.Parse(time.RFC3339Nano, r.CreatedAt)
	updated, _ := time.Parse(time.RFC3339Nano, r.UpdatedAt)
	c := &domain.BoardColumn{
		ID: r.ID, PropertyID: r.PropertyID, Title: r.Title,
		Color: domain.ColumnColor(r.Color), Position: r.Position,
		Description: r.Description, Archived: r.Archived == 1,
		CreatedAt: created, UpdatedAt: updated,
	}
	if r.FieldIDsJSON.Valid && r.FieldIDsJSON.String != "" {
		if err := json.Unmarshal([]byte(r.FieldIDsJSON.String), &c.FieldIDs); err != nil {
			return nil, fmt.Errorf("decode field_ids: %w", err)
		}
	}
	if r.ConfigJSON.Valid && r.ConfigJSON.String != "" {
		var cfg domain.ColumnConfig
		if err := json.Unmarshal([]byte(r.ConfigJSON.String), &cfg); err != nil {
			return nil, fmt.Errorf("decode column_config: %w", err)
		}
		c.Config = &cfg
	}
	return c, nil
}

func (r *columnRepo) Create(ctx context.Context, c *domain.BoardColumn) error {
	if c.CreatedAt.IsZero() { c.CreatedAt = nowUTC() }
	c.UpdatedAt = nowUTC()
	fieldIDsJSON, _ := marshalJSON(c.FieldIDs)
	configJSON, _ := marshalJSON(c.Config)
	_, err := r.db.ExecContext(ctx,
		`INSERT INTO columns(id,property_id,title,color,position,description,archived,field_ids_json,config_json,created_at,updated_at)
		 VALUES(?,?,?,?,?,?,?,?,?,?,?)`,
		c.ID, c.PropertyID, c.Title, string(c.Color), c.Position, c.Description, boolToInt(c.Archived),
		nullStr(fieldIDsJSON), nullStr(configJSON),
		c.CreatedAt.Format(time.RFC3339Nano), c.UpdatedAt.Format(time.RFC3339Nano))
	return err
}

func (r *columnRepo) GetByID(ctx context.Context, id string) (*domain.BoardColumn, error) {
	var row columnRow
	if err := r.db.GetContext(ctx, &row, `SELECT * FROM columns WHERE id=?`, id); err != nil {
		return nil, wrapNotFound(err)
	}
	return row.toDomain()
}

func (r *columnRepo) ListByProperty(ctx context.Context, propertyID string) ([]domain.BoardColumn, error) {
	var rows []columnRow
	if err := r.db.SelectContext(ctx, &rows,
		`SELECT * FROM columns WHERE property_id=? AND archived=0 ORDER BY position`, propertyID); err != nil {
		return nil, err
	}
	out := make([]domain.BoardColumn, 0, len(rows))
	for _, row := range rows {
		c, err := row.toDomain()
		if err != nil { return nil, err }
		out = append(out, *c)
	}
	return out, nil
}

func (r *columnRepo) Update(ctx context.Context, c *domain.BoardColumn) error {
	c.UpdatedAt = nowUTC()
	fieldIDsJSON, _ := marshalJSON(c.FieldIDs)
	configJSON, _ := marshalJSON(c.Config)
	res, err := r.db.ExecContext(ctx,
		`UPDATE columns SET title=?,color=?,position=?,description=?,archived=?,field_ids_json=?,config_json=?,updated_at=? WHERE id=?`,
		c.Title, string(c.Color), c.Position, c.Description, boolToInt(c.Archived),
		nullStr(fieldIDsJSON), nullStr(configJSON),
		c.UpdatedAt.Format(time.RFC3339Nano), c.ID)
	if err != nil { return err }
	if n, _ := res.RowsAffected(); n == 0 { return store.ErrNotFound }
	return nil
}

func (r *columnRepo) Delete(ctx context.Context, id string) error {
	res, err := r.db.ExecContext(ctx, `DELETE FROM columns WHERE id=?`, id)
	if err != nil { return err }
	if n, _ := res.RowsAffected(); n == 0 { return store.ErrNotFound }
	return nil
}

func (r *columnRepo) Reorder(ctx context.Context, propertyID string, orderedIDs []string) error {
	tx, err := r.db.BeginTxx(ctx, nil)
	if err != nil { return err }
	defer tx.Rollback() //nolint:errcheck
	for i, id := range orderedIDs {
		if _, err := tx.ExecContext(ctx,
			`UPDATE columns SET position=?, updated_at=? WHERE id=? AND property_id=?`,
			i, nowUTC().Format(time.RFC3339Nano), id, propertyID); err != nil {
			return err
		}
	}
	return tx.Commit()
}

// ── cards ────────────────────────────────────────────────────────────────────

type cardRepo struct{ db *sqlx.DB }

type cardRow struct {
	ID               string         `db:"id"`
	PropertyID       string         `db:"property_id"`
	ColumnID         string         `db:"column_id"`
	Title            string         `db:"title"`
	Description      string         `db:"description"`
	Position         int            `db:"position"`
	IsDone           int            `db:"is_done"`
	Archived         int            `db:"archived"`
	RoomCode         string         `db:"room_code"`
	Priority         string         `db:"priority"`
	CheckinDate      sql.NullString `db:"checkin_date"`
	AssignedToID     sql.NullString `db:"assigned_to_id"`
	Kind             string         `db:"kind"`
	CustomFieldsJSON string         `db:"custom_fields_json"`
	CreatedAt        string         `db:"created_at"`
	UpdatedAt        string         `db:"updated_at"`
	CleanedBy        string         `db:"cleaned_by"`
	DoneAt           sql.NullString `db:"done_at"`
}

func (r cardRow) toDomain() (*domain.Card, error) {
	created, _ := time.Parse(time.RFC3339Nano, r.CreatedAt)
	updated, _ := time.Parse(time.RFC3339Nano, r.UpdatedAt)
	c := &domain.Card{
		ID: r.ID, PropertyID: r.PropertyID, ColumnID: r.ColumnID,
		Title: r.Title, Description: r.Description, Position: r.Position,
		IsDone: r.IsDone == 1, Archived: r.Archived == 1,
		RoomCode: r.RoomCode, Priority: domain.CardPriority(r.Priority),
		Kind: domain.CardKind(r.Kind),
		CreatedAt: created, UpdatedAt: updated,
		CleanedBy: r.CleanedBy,
	}
	if r.CheckinDate.Valid && r.CheckinDate.String != "" {
		t, _ := time.Parse(time.RFC3339Nano, r.CheckinDate.String)
		c.CheckinDate = &t
	}
	if r.AssignedToID.Valid && r.AssignedToID.String != "" {
		s := r.AssignedToID.String
		c.AssignedToID = &s
	}
	if r.DoneAt.Valid && r.DoneAt.String != "" {
		t, _ := time.Parse(time.RFC3339Nano, r.DoneAt.String)
		c.DoneAt = &t
	}
	if r.CustomFieldsJSON != "" {
		if err := json.Unmarshal([]byte(r.CustomFieldsJSON), &c.CustomFields); err != nil {
			return nil, fmt.Errorf("decode custom_fields: %w", err)
		}
	} else {
		c.CustomFields = map[string]any{}
	}
	return c, nil
}

func (r *cardRepo) Create(ctx context.Context, c *domain.Card) error {
	if c.CreatedAt.IsZero() { c.CreatedAt = nowUTC() }
	c.UpdatedAt = nowUTC()
	if c.CustomFields == nil { c.CustomFields = map[string]any{} }
	customJSON, _ := marshalJSON(c.CustomFields)
	var checkin, assigned, doneAt sql.NullString
	if c.CheckinDate != nil { checkin = sql.NullString{String: c.CheckinDate.Format(time.RFC3339Nano), Valid: true} }
	if c.AssignedToID != nil { assigned = sql.NullString{String: *c.AssignedToID, Valid: true} }
	if c.DoneAt != nil { doneAt = sql.NullString{String: c.DoneAt.Format(time.RFC3339Nano), Valid: true} }
	_, err := r.db.ExecContext(ctx,
		`INSERT INTO cards(id,property_id,column_id,title,description,position,is_done,archived,room_code,priority,checkin_date,assigned_to_id,kind,custom_fields_json,created_at,updated_at,cleaned_by,done_at)
		 VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
		c.ID, c.PropertyID, c.ColumnID, c.Title, c.Description, c.Position,
		boolToInt(c.IsDone), boolToInt(c.Archived), c.RoomCode, string(c.Priority),
		checkin, assigned, string(c.Kind), customJSON,
		c.CreatedAt.Format(time.RFC3339Nano), c.UpdatedAt.Format(time.RFC3339Nano),
		c.CleanedBy, doneAt)
	return err
}

func (r *cardRepo) GetByID(ctx context.Context, id string) (*domain.Card, error) {
	var row cardRow
	if err := r.db.GetContext(ctx, &row, `SELECT * FROM cards WHERE id=?`, id); err != nil {
		return nil, wrapNotFound(err)
	}
	return row.toDomain()
}

func (r *cardRepo) ListByColumn(ctx context.Context, columnID string) ([]domain.Card, error) {
	var rows []cardRow
	if err := r.db.SelectContext(ctx, &rows,
		`SELECT * FROM cards WHERE column_id=? AND archived=0 ORDER BY position`, columnID); err != nil {
		return nil, err
	}
	return cardRowsToDomain(rows)
}

func (r *cardRepo) ListByProperty(ctx context.Context, propertyID string) ([]domain.Card, error) {
	var rows []cardRow
	if err := r.db.SelectContext(ctx, &rows,
		`SELECT * FROM cards WHERE property_id=? AND archived=0 ORDER BY column_id, position`, propertyID); err != nil {
		return nil, err
	}
	return cardRowsToDomain(rows)
}

func cardRowsToDomain(rows []cardRow) ([]domain.Card, error) {
	out := make([]domain.Card, 0, len(rows))
	for _, row := range rows {
		c, err := row.toDomain()
		if err != nil { return nil, err }
		out = append(out, *c)
	}
	return out, nil
}

func (r *cardRepo) Update(ctx context.Context, c *domain.Card) error {
	c.UpdatedAt = nowUTC()
	if c.CustomFields == nil { c.CustomFields = map[string]any{} }
	customJSON, _ := marshalJSON(c.CustomFields)
	var checkin, assigned, doneAt sql.NullString
	if c.CheckinDate != nil { checkin = sql.NullString{String: c.CheckinDate.Format(time.RFC3339Nano), Valid: true} }
	if c.AssignedToID != nil { assigned = sql.NullString{String: *c.AssignedToID, Valid: true} }
	if c.DoneAt != nil { doneAt = sql.NullString{String: c.DoneAt.Format(time.RFC3339Nano), Valid: true} }
	res, err := r.db.ExecContext(ctx,
		`UPDATE cards SET column_id=?,title=?,description=?,position=?,is_done=?,archived=?,room_code=?,priority=?,checkin_date=?,assigned_to_id=?,kind=?,custom_fields_json=?,updated_at=?,cleaned_by=?,done_at=? WHERE id=?`,
		c.ColumnID, c.Title, c.Description, c.Position,
		boolToInt(c.IsDone), boolToInt(c.Archived), c.RoomCode, string(c.Priority),
		checkin, assigned, string(c.Kind), customJSON,
		c.UpdatedAt.Format(time.RFC3339Nano), c.CleanedBy, doneAt, c.ID)
	if err != nil { return err }
	if n, _ := res.RowsAffected(); n == 0 { return store.ErrNotFound }
	return nil
}

func (r *cardRepo) Delete(ctx context.Context, id string) error {
	res, err := r.db.ExecContext(ctx, `DELETE FROM cards WHERE id=?`, id)
	if err != nil { return err }
	if n, _ := res.RowsAffected(); n == 0 { return store.ErrNotFound }
	return nil
}

func (r *cardRepo) MoveToColumn(ctx context.Context, cardID, targetColumnID string, position int) error {
	tx, err := r.db.BeginTxx(ctx, nil)
	if err != nil { return err }
	defer tx.Rollback() //nolint:errcheck

	// Determine the card's current column so we can compact it after the move.
	var sourceColID string
	if err := tx.QueryRowContext(ctx, `SELECT column_id FROM cards WHERE id=?`, cardID).Scan(&sourceColID); err != nil {
		return wrapNotFound(err)
	}

	// Shift destination cards down to make space at the target position.
	if _, err := tx.ExecContext(ctx,
		`UPDATE cards SET position = position + 1 WHERE column_id = ? AND position >= ? AND archived = 0 AND id != ?`,
		targetColumnID, position, cardID); err != nil {
		return err
	}

	// Move the card.
	now := nowUTC().Format(time.RFC3339Nano)
	res, err := tx.ExecContext(ctx,
		`UPDATE cards SET column_id=?, position=?, updated_at=? WHERE id=?`,
		targetColumnID, position, now, cardID)
	if err != nil { return err }
	if n, _ := res.RowsAffected(); n == 0 { return store.ErrNotFound }

	// Compact source column (fill gap left by the moved card).
	if sourceColID != targetColumnID {
		if err := compactColumnPositions(ctx, tx, sourceColID); err != nil { return err }
	}
	// Compact destination column (normalize any accumulated position drift).
	if err := compactColumnPositions(ctx, tx, targetColumnID); err != nil { return err }

	return tx.Commit()
}

// compactColumnPositions rewrites positions 0,1,2,… in order for active cards in a column.
func compactColumnPositions(ctx context.Context, tx *sqlx.Tx, columnID string) error {
	var ids []string
	if err := tx.SelectContext(ctx, &ids,
		`SELECT id FROM cards WHERE column_id=? AND archived=0 ORDER BY position, created_at`, columnID); err != nil {
		return err
	}
	for i, id := range ids {
		if _, err := tx.ExecContext(ctx, `UPDATE cards SET position=? WHERE id=?`, i, id); err != nil {
			return err
		}
	}
	return nil
}

func (r *cardRepo) Reorder(ctx context.Context, columnID string, orderedIDs []string) error {
	if len(orderedIDs) == 0 { return nil }
	tx, err := r.db.BeginTxx(ctx, nil)
	if err != nil { return err }
	now := nowUTC().Format(time.RFC3339Nano)
	for i, id := range orderedIDs {
		if _, err := tx.ExecContext(ctx,
			`UPDATE cards SET position=?, updated_at=? WHERE id=? AND column_id=?`,
			i, now, id, columnID); err != nil {
			_ = tx.Rollback()
			return err
		}
	}
	return tx.Commit()
}

// ── fields ───────────────────────────────────────────────────────────────────

type fieldRepo struct{ db *sqlx.DB }

type fieldRow struct {
	ID          string         `db:"id"`
	Label       string         `db:"label"`
	Type        string         `db:"type"`
	OptionsJSON sql.NullString `db:"options_json"`
	Enabled     int            `db:"enabled"`
	ShowOnCard  int            `db:"show_on_card"`
	Icon        string         `db:"icon"`
	OffLabel    string         `db:"off_label"`
	Position    int            `db:"position"`
	OwnerID     sql.NullString `db:"owner_id"`
}

func (r fieldRow) toDomain() (*domain.FieldDef, error) {
	f := &domain.FieldDef{
		ID: r.ID, Label: r.Label, Type: domain.FieldType(r.Type),
		Enabled: r.Enabled == 1, ShowOnCard: r.ShowOnCard == 1,
		Icon: r.Icon, OffLabel: r.OffLabel, Position: r.Position,
	}
	if r.OwnerID.Valid { f.OwnerID = r.OwnerID.String }
	if r.OptionsJSON.Valid && r.OptionsJSON.String != "" {
		if err := json.Unmarshal([]byte(r.OptionsJSON.String), &f.Options); err != nil {
			return nil, fmt.Errorf("decode options: %w", err)
		}
	}
	return f, nil
}

func (r *fieldRepo) Create(ctx context.Context, f *domain.FieldDef) error {
	optsJSON, _ := marshalJSON(f.Options)
	var ownerID interface{}
	if f.OwnerID != "" { ownerID = f.OwnerID }
	_, err := r.db.ExecContext(ctx,
		`INSERT INTO fields(id,label,type,options_json,enabled,show_on_card,icon,off_label,position,owner_id)
		 VALUES(?,?,?,?,?,?,?,?,?,?)`,
		f.ID, f.Label, string(f.Type), nullStr(optsJSON),
		boolToInt(f.Enabled), boolToInt(f.ShowOnCard), f.Icon, f.OffLabel, f.Position, ownerID)
	return err
}

func (r *fieldRepo) GetByID(ctx context.Context, id string) (*domain.FieldDef, error) {
	var row fieldRow
	if err := r.db.GetContext(ctx, &row, `SELECT * FROM fields WHERE id=?`, id); err != nil {
		return nil, wrapNotFound(err)
	}
	return row.toDomain()
}

func (r *fieldRepo) List(ctx context.Context) ([]domain.FieldDef, error) {
	var rows []fieldRow
	if err := r.db.SelectContext(ctx, &rows, `SELECT * FROM fields ORDER BY position`); err != nil {
		return nil, err
	}
	out := make([]domain.FieldDef, 0, len(rows))
	for _, row := range rows {
		f, err := row.toDomain()
		if err != nil { return nil, err }
		out = append(out, *f)
	}
	return out, nil
}

// ListByOwner returns the field defs belonging to [ownerID]. When ownerID is
// empty it returns the legacy/global ones (owner_id IS NULL).
func (r *fieldRepo) ListByOwner(ctx context.Context, ownerID string) ([]domain.FieldDef, error) {
	var rows []fieldRow
	var err error
	if ownerID == "" {
		err = r.db.SelectContext(ctx, &rows, `SELECT * FROM fields WHERE owner_id IS NULL ORDER BY position`)
	} else {
		err = r.db.SelectContext(ctx, &rows, `SELECT * FROM fields WHERE owner_id=? ORDER BY position`, ownerID)
	}
	if err != nil { return nil, err }
	out := make([]domain.FieldDef, 0, len(rows))
	for _, row := range rows {
		f, err := row.toDomain()
		if err != nil { return nil, err }
		out = append(out, *f)
	}
	return out, nil
}

func (r *fieldRepo) Update(ctx context.Context, f *domain.FieldDef) error {
	optsJSON, _ := marshalJSON(f.Options)
	res, err := r.db.ExecContext(ctx,
		`UPDATE fields SET label=?,type=?,options_json=?,enabled=?,show_on_card=?,icon=?,off_label=?,position=? WHERE id=?`,
		f.Label, string(f.Type), nullStr(optsJSON),
		boolToInt(f.Enabled), boolToInt(f.ShowOnCard), f.Icon, f.OffLabel, f.Position, f.ID)
	if err != nil { return err }
	if n, _ := res.RowsAffected(); n == 0 { return store.ErrNotFound }
	return nil
}

func (r *fieldRepo) Delete(ctx context.Context, id string) error {
	res, err := r.db.ExecContext(ctx, `DELETE FROM fields WHERE id=?`, id)
	if err != nil { return err }
	if n, _ := res.RowsAffected(); n == 0 { return store.ErrNotFound }
	return nil
}

func (r *fieldRepo) Reorder(ctx context.Context, orderedIDs []string) error {
	tx, err := r.db.BeginTxx(ctx, nil)
	if err != nil { return err }
	defer tx.Rollback() //nolint:errcheck
	for i, id := range orderedIDs {
		if _, err := tx.ExecContext(ctx, `UPDATE fields SET position=? WHERE id=?`, i, id); err != nil {
			return err
		}
	}
	return tx.Commit()
}

// ── comments ─────────────────────────────────────────────────────────────────

type commentRepo struct{ db *sqlx.DB }

type commentRow struct {
	ID        string `db:"id"`
	CardID    string `db:"card_id"`
	AuthorID  string `db:"author_id"`
	Text      string `db:"text"`
	CreatedAt string `db:"created_at"`
}

func (r commentRow) toDomain() *domain.Comment {
	created, _ := time.Parse(time.RFC3339Nano, r.CreatedAt)
	return &domain.Comment{ID: r.ID, CardID: r.CardID, AuthorID: r.AuthorID, Text: r.Text, CreatedAt: created}
}

func (r *commentRepo) Create(ctx context.Context, c *domain.Comment) error {
	if c.CreatedAt.IsZero() { c.CreatedAt = nowUTC() }
	_, err := r.db.ExecContext(ctx,
		`INSERT INTO comments(id,card_id,author_id,text,created_at) VALUES(?,?,?,?,?)`,
		c.ID, c.CardID, c.AuthorID, c.Text, c.CreatedAt.Format(time.RFC3339Nano))
	return err
}

func (r *commentRepo) ListByCard(ctx context.Context, cardID string) ([]domain.Comment, error) {
	var rows []commentRow
	if err := r.db.SelectContext(ctx, &rows,
		`SELECT * FROM comments WHERE card_id=? ORDER BY created_at`, cardID); err != nil {
		return nil, err
	}
	out := make([]domain.Comment, 0, len(rows))
	for _, row := range rows { out = append(out, *row.toDomain()) }
	return out, nil
}

func (r *commentRepo) Delete(ctx context.Context, id string) error {
	res, err := r.db.ExecContext(ctx, `DELETE FROM comments WHERE id=?`, id)
	if err != nil { return err }
	if n, _ := res.RowsAffected(); n == 0 { return store.ErrNotFound }
	return nil
}

// ── activity ─────────────────────────────────────────────────────────────────

type activityRepo struct{ db *sqlx.DB }

type activityRow struct {
	ID          string `db:"id"`
	CardID      string `db:"card_id"`
	UserID      string `db:"user_id"`
	Type        string `db:"type"`
	PayloadJSON string `db:"payload_json"`
	CreatedAt   string `db:"created_at"`
}

func (r activityRow) toDomain() (*domain.ActivityEvent, error) {
	created, _ := time.Parse(time.RFC3339Nano, r.CreatedAt)
	e := &domain.ActivityEvent{
		ID: r.ID, CardID: r.CardID, UserID: r.UserID,
		Type: domain.ActivityType(r.Type), CreatedAt: created,
	}
	if r.PayloadJSON != "" {
		if err := json.Unmarshal([]byte(r.PayloadJSON), &e.Payload); err != nil {
			return nil, fmt.Errorf("decode activity payload: %w", err)
		}
	}
	return e, nil
}

func (r *activityRepo) Create(ctx context.Context, e *domain.ActivityEvent) error {
	if e.CreatedAt.IsZero() { e.CreatedAt = nowUTC() }
	if e.Payload == nil { e.Payload = map[string]any{} }
	payloadJSON, _ := marshalJSON(e.Payload)
	_, err := r.db.ExecContext(ctx,
		`INSERT INTO activity_events(id,card_id,user_id,type,payload_json,created_at) VALUES(?,?,?,?,?,?)`,
		e.ID, e.CardID, e.UserID, string(e.Type), payloadJSON, e.CreatedAt.Format(time.RFC3339Nano))
	return err
}

func (r *activityRepo) ListByCard(ctx context.Context, cardID string) ([]domain.ActivityEvent, error) {
	var rows []activityRow
	if err := r.db.SelectContext(ctx, &rows,
		`SELECT * FROM activity_events WHERE card_id=? ORDER BY created_at`, cardID); err != nil {
		return nil, err
	}
	out := make([]domain.ActivityEvent, 0, len(rows))
	for _, row := range rows {
		e, err := row.toDomain()
		if err != nil { return nil, err }
		out = append(out, *e)
	}
	return out, nil
}

// ── archive ──────────────────────────────────────────────────────────────────

type archiveRepo struct{ db *sqlx.DB }

type archiveRow struct {
	ID          string `db:"id"`
	Kind        string `db:"kind"`
	PayloadJSON string `db:"payload_json"`
	ArchivedAt  string `db:"archived_at"`
}

func (r archiveRow) toDomain() (*domain.ArchiveItem, error) {
	archived, _ := time.Parse(time.RFC3339Nano, r.ArchivedAt)
	a := &domain.ArchiveItem{
		ID: r.ID, Kind: domain.ArchiveKind(r.Kind), ArchivedAt: archived,
	}
	if r.PayloadJSON != "" {
		if err := json.Unmarshal([]byte(r.PayloadJSON), &a.Payload); err != nil {
			return nil, fmt.Errorf("decode archive payload: %w", err)
		}
	}
	return a, nil
}

func (r *archiveRepo) Create(ctx context.Context, item *domain.ArchiveItem) error {
	if item.ArchivedAt.IsZero() { item.ArchivedAt = nowUTC() }
	if item.Payload == nil { item.Payload = map[string]any{} }
	payloadJSON, _ := marshalJSON(item.Payload)
	_, err := r.db.ExecContext(ctx,
		`INSERT INTO archive(id,kind,payload_json,archived_at) VALUES(?,?,?,?)`,
		item.ID, string(item.Kind), payloadJSON, item.ArchivedAt.Format(time.RFC3339Nano))
	return err
}

func (r *archiveRepo) List(ctx context.Context) ([]domain.ArchiveItem, error) {
	var rows []archiveRow
	if err := r.db.SelectContext(ctx, &rows, `SELECT * FROM archive ORDER BY archived_at DESC`); err != nil {
		return nil, err
	}
	out := make([]domain.ArchiveItem, 0, len(rows))
	for _, row := range rows {
		a, err := row.toDomain()
		if err != nil { return nil, err }
		out = append(out, *a)
	}
	return out, nil
}

func (r *archiveRepo) GetByID(ctx context.Context, id string) (*domain.ArchiveItem, error) {
	var row archiveRow
	if err := r.db.GetContext(ctx, &row, `SELECT * FROM archive WHERE id=?`, id); err != nil {
		return nil, wrapNotFound(err)
	}
	return row.toDomain()
}

func (r *archiveRepo) Delete(ctx context.Context, id string) error {
	res, err := r.db.ExecContext(ctx, `DELETE FROM archive WHERE id=?`, id)
	if err != nil { return err }
	if n, _ := res.RowsAffected(); n == 0 { return store.ErrNotFound }
	return nil
}

// ── shared helpers ───────────────────────────────────────────────────────────

func nullStr(s string) sql.NullString {
	if s == "" { return sql.NullString{} }
	return sql.NullString{String: s, Valid: true}
}

// ─────────────────────────────────────────
//  auditRepo
// ─────────────────────────────────────────

type auditRepo struct{ db *sqlx.DB }

func (r *auditRepo) Create(ctx context.Context, e *domain.AuditEvent) error {
	_, err := r.db.ExecContext(ctx,
		`INSERT INTO audit_events(id,actor_id,actor_name,actor_ip,action,entity,entity_id,detail,property_id,created_at)
                 VALUES(?,?,?,?,?,?,?,?,?,?)`,
		e.ID, e.ActorID, e.ActorName, e.ActorIP, e.Action, e.Entity, e.EntityID, e.Detail,
		e.PropertyID, e.CreatedAt.UTC().Format(time.RFC3339Nano))
	return err
}

func (r *auditRepo) scanAuditRows(rows *sql.Rows) ([]domain.AuditEvent, error) {
	defer rows.Close()
	out := make([]domain.AuditEvent, 0)
	for rows.Next() {
		var e domain.AuditEvent
		var ts string
		var pid *string
		if err := rows.Scan(&e.ID, &e.ActorID, &e.ActorName, &e.ActorIP, &e.Action, &e.Entity, &e.EntityID, &e.Detail, &pid, &ts); err != nil {
			return nil, err
		}
		if pid != nil { e.PropertyID = *pid }
		if t, err := time.Parse(time.RFC3339Nano, ts); err == nil { e.CreatedAt = t }
		out = append(out, e)
	}
	return out, rows.Err()
}

func (r *auditRepo) List(ctx context.Context, limit int) ([]domain.AuditEvent, error) {
	if limit <= 0 { limit = 200 }
	rows, err := r.db.QueryContext(ctx,
		`SELECT id,actor_id,actor_name,actor_ip,action,entity,entity_id,detail,property_id,created_at
                 FROM audit_events ORDER BY created_at DESC LIMIT ?`, limit)
	if err != nil { return nil, err }
	return r.scanAuditRows(rows)
}

func (r *auditRepo) ListByPropertyIDs(ctx context.Context, propertyIDs []string, limit int) ([]domain.AuditEvent, error) {
	if len(propertyIDs) == 0 { return []domain.AuditEvent{}, nil }
	if limit <= 0 { limit = 200 }
	placeholders := strings.Repeat("?,", len(propertyIDs))
	placeholders = placeholders[:len(placeholders)-1]
	args := make([]any, 0, len(propertyIDs)+1)
	for _, id := range propertyIDs { args = append(args, id) }
	args = append(args, limit)
	rows, err := r.db.QueryContext(ctx,
		`SELECT id,actor_id,actor_name,actor_ip,action,entity,entity_id,detail,property_id,created_at
                 FROM audit_events WHERE property_id IN (`+placeholders+`)
                 ORDER BY created_at DESC LIMIT ?`, args...)
	if err != nil { return nil, err }
	return r.scanAuditRows(rows)
}

func (r *auditRepo) Delete(ctx context.Context, id string) error {
	res, err := r.db.ExecContext(ctx, `DELETE FROM audit_events WHERE id=?`, id)
	if err != nil { return err }
	n, _ := res.RowsAffected()
	if n == 0 { return store.ErrNotFound }
	return nil
}

// ─────────────────────────────────────────
//  groupRepo
// ─────────────────────────────────────────

type groupRepo struct{ db *sqlx.DB }

func (r *groupRepo) Create(ctx context.Context, g *domain.Group) error {
	now := nowUTC()
	if g.CreatedAt.IsZero() { g.CreatedAt = now }
	g.UpdatedAt = now
	var createdBy interface{}
	if g.CreatedBy != "" { createdBy = g.CreatedBy }
	_, err := r.db.ExecContext(ctx,
		`INSERT INTO groups(id,name,created_by,created_at,updated_at) VALUES(?,?,?,?,?)`,
		g.ID, g.Name, createdBy, g.CreatedAt.Format(time.RFC3339Nano), g.UpdatedAt.Format(time.RFC3339Nano))
	return err
}

func (r *groupRepo) GetByID(ctx context.Context, id string) (*domain.Group, error) {
	var row struct {
		ID        string  `db:"id"`
		Name      string  `db:"name"`
		CreatedBy *string `db:"created_by"`
		CreatedAt string  `db:"created_at"`
		UpdatedAt string  `db:"updated_at"`
	}
	if err := r.db.GetContext(ctx, &row, `SELECT * FROM groups WHERE id=?`, id); err != nil {
		return nil, wrapNotFound(err)
	}
	g := &domain.Group{ID: row.ID, Name: row.Name}
	if row.CreatedBy != nil { g.CreatedBy = *row.CreatedBy }
	g.CreatedAt, _ = time.Parse(time.RFC3339Nano, row.CreatedAt)
	g.UpdatedAt, _ = time.Parse(time.RFC3339Nano, row.UpdatedAt)
	userIDs, _ := r.usersFor(ctx, id)
	g.UserIDs = userIDs
	propIDs, _ := r.propertiesFor(ctx, id)
	g.PropertyIDs = propIDs
	return g, nil
}

func (r *groupRepo) List(ctx context.Context) ([]domain.Group, error) {
	var rows []struct {
		ID        string  `db:"id"`
		Name      string  `db:"name"`
		CreatedBy *string `db:"created_by"`
		CreatedAt string  `db:"created_at"`
		UpdatedAt string  `db:"updated_at"`
	}
	if err := r.db.SelectContext(ctx, &rows, `SELECT * FROM groups ORDER BY created_at`); err != nil {
		return nil, err
	}
	out := make([]domain.Group, 0, len(rows))
	for _, row := range rows {
		g := domain.Group{ID: row.ID, Name: row.Name}
		if row.CreatedBy != nil { g.CreatedBy = *row.CreatedBy }
		g.CreatedAt, _ = time.Parse(time.RFC3339Nano, row.CreatedAt)
		g.UpdatedAt, _ = time.Parse(time.RFC3339Nano, row.UpdatedAt)
		g.UserIDs, _ = r.usersFor(ctx, row.ID)
		g.PropertyIDs, _ = r.propertiesFor(ctx, row.ID)
		out = append(out, g)
	}
	return out, nil
}

// ListByCreators returns groups whose `created_by` matches one of [creatorIDs].
// Used to scope the groups list per actor: an owner sees the groups their
// supervisors created (and their own); a supervisor sees only their own.
func (r *groupRepo) ListByCreators(ctx context.Context, creatorIDs []string) ([]domain.Group, error) {
	if len(creatorIDs) == 0 { return []domain.Group{}, nil }
	query, args, err := sqlx.In(
		`SELECT * FROM groups WHERE created_by IN (?) ORDER BY created_at`, creatorIDs)
	if err != nil { return nil, err }
	query = r.db.Rebind(query)
	var rows []struct {
		ID        string  `db:"id"`
		Name      string  `db:"name"`
		CreatedBy *string `db:"created_by"`
		CreatedAt string  `db:"created_at"`
		UpdatedAt string  `db:"updated_at"`
	}
	if err := r.db.SelectContext(ctx, &rows, query, args...); err != nil {
		return nil, err
	}
	out := make([]domain.Group, 0, len(rows))
	for _, row := range rows {
		g := domain.Group{ID: row.ID, Name: row.Name}
		if row.CreatedBy != nil { g.CreatedBy = *row.CreatedBy }
		g.CreatedAt, _ = time.Parse(time.RFC3339Nano, row.CreatedAt)
		g.UpdatedAt, _ = time.Parse(time.RFC3339Nano, row.UpdatedAt)
		g.UserIDs, _ = r.usersFor(ctx, row.ID)
		g.PropertyIDs, _ = r.propertiesFor(ctx, row.ID)
		out = append(out, g)
	}
	return out, nil
}

func (r *groupRepo) Update(ctx context.Context, g *domain.Group) error {
	g.UpdatedAt = nowUTC()
	res, err := r.db.ExecContext(ctx,
		`UPDATE groups SET name=?,updated_at=? WHERE id=?`,
		g.Name, g.UpdatedAt.Format(time.RFC3339Nano), g.ID)
	if err != nil { return err }
	if n, _ := res.RowsAffected(); n == 0 { return store.ErrNotFound }
	return nil
}

func (r *groupRepo) Delete(ctx context.Context, id string) error {
	res, err := r.db.ExecContext(ctx, `DELETE FROM groups WHERE id=?`, id)
	if err != nil { return err }
	if n, _ := res.RowsAffected(); n == 0 { return store.ErrNotFound }
	return nil
}

func (r *groupRepo) SetUsers(ctx context.Context, groupID string, userIDs []string) error {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil { return err }
	defer tx.Rollback() //nolint:errcheck
	if _, err := tx.ExecContext(ctx, `DELETE FROM group_users WHERE group_id=?`, groupID); err != nil {
		return err
	}
	for _, uid := range userIDs {
		if _, err := tx.ExecContext(ctx, `INSERT OR IGNORE INTO group_users(group_id,user_id) VALUES(?,?)`, groupID, uid); err != nil {
			return err
		}
	}
	return tx.Commit()
}

func (r *groupRepo) SetProperties(ctx context.Context, groupID string, propertyIDs []string) error {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil { return err }
	defer tx.Rollback() //nolint:errcheck
	if _, err := tx.ExecContext(ctx, `DELETE FROM group_properties WHERE group_id=?`, groupID); err != nil {
		return err
	}
	for _, pid := range propertyIDs {
		if _, err := tx.ExecContext(ctx, `INSERT OR IGNORE INTO group_properties(group_id,property_id) VALUES(?,?)`, groupID, pid); err != nil {
			return err
		}
	}
	return tx.Commit()
}

func (r *groupRepo) ListPropertiesForUser(ctx context.Context, userID string) ([]string, error) {
	var ids []string
	err := r.db.SelectContext(ctx, &ids,
		`SELECT DISTINCT gp.property_id
		 FROM group_properties gp
		 JOIN group_users gu ON gu.group_id = gp.group_id
		 WHERE gu.user_id = ?`, userID)
	return ids, err
}

func (r *groupRepo) usersFor(ctx context.Context, groupID string) ([]string, error) {
	var ids []string
	err := r.db.SelectContext(ctx, &ids, `SELECT user_id FROM group_users WHERE group_id=?`, groupID)
	return ids, err
}

func (r *groupRepo) propertiesFor(ctx context.Context, groupID string) ([]string, error) {
	var ids []string
	err := r.db.SelectContext(ctx, &ids, `SELECT property_id FROM group_properties WHERE group_id=?`, groupID)
	return ids, err
}

func (r *groupRepo) ListForSupervisor(ctx context.Context, supervisorID string) ([]domain.Group, error) {
	var rows []struct {
		ID        string `db:"id"`
		Name      string `db:"name"`
		CreatedAt string `db:"created_at"`
		UpdatedAt string `db:"updated_at"`
	}
	if err := r.db.SelectContext(ctx, &rows,
		`SELECT g.* FROM groups g
		 INNER JOIN group_users gu ON gu.group_id = g.id
		 WHERE gu.user_id = ?
		 ORDER BY g.created_at`, supervisorID); err != nil {
		return nil, err
	}
	out := make([]domain.Group, 0, len(rows))
	for _, row := range rows {
		g := domain.Group{ID: row.ID, Name: row.Name}
		g.CreatedAt, _ = time.Parse(time.RFC3339Nano, row.CreatedAt)
		g.UpdatedAt, _ = time.Parse(time.RFC3339Nano, row.UpdatedAt)
		g.UserIDs, _ = r.usersFor(ctx, row.ID)
		g.PropertyIDs, _ = r.propertiesFor(ctx, row.ID)
		out = append(out, g)
	}
	return out, nil
}

// ── property supervisors ─────────────────────────────────────────────────────

type propertySupervisorRepo struct{ db *sqlx.DB }

func (r *propertySupervisorRepo) SetSupervisors(ctx context.Context, propertyID string, supervisorIDs []string) error {
	tx, err := r.db.BeginTxx(ctx, nil)
	if err != nil { return err }
	defer tx.Rollback() //nolint:errcheck
	if _, err := tx.ExecContext(ctx, `DELETE FROM property_supervisors WHERE property_id=?`, propertyID); err != nil {
		return err
	}
	for _, sid := range supervisorIDs {
		if _, err := tx.ExecContext(ctx,
			`INSERT OR IGNORE INTO property_supervisors(property_id,supervisor_id) VALUES(?,?)`, propertyID, sid); err != nil {
			return err
		}
	}
	return tx.Commit()
}

func (r *propertySupervisorRepo) ListForProperty(ctx context.Context, propertyID string) ([]string, error) {
	var ids []string
	err := r.db.SelectContext(ctx, &ids,
		`SELECT supervisor_id FROM property_supervisors WHERE property_id=?`, propertyID)
	return ids, err
}

func (r *propertySupervisorRepo) ListPropertiesForSupervisor(ctx context.Context, supervisorID string) ([]string, error) {
	var ids []string
	err := r.db.SelectContext(ctx, &ids,
		`SELECT property_id FROM property_supervisors WHERE supervisor_id=?`, supervisorID)
	return ids, err
}

