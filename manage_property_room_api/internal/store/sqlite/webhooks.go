package sqlite

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"time"

	"github.com/jmoiron/sqlx"

	"github.com/jose/manage_property_room_api/internal/domain"
	"github.com/jose/manage_property_room_api/internal/store"
)

// ── outbound webhooks ───────────────────────────────────────────────────────

type webhookRepo struct{ db *sqlx.DB }

type webhookRow struct {
	ID         string `db:"id"`
	Name       string `db:"name"`
	URL        string `db:"url"`
	Secret     string `db:"secret"`
	Events     string `db:"events"`
	PropertyID sql.NullString `db:"property_id"`
	Active     int    `db:"active"`
	CreatedBy  string `db:"created_by"`
	CreatedAt  string `db:"created_at"`
	UpdatedAt  string `db:"updated_at"`
}

func (r webhookRow) toDomain() domain.Webhook {
	created, _ := time.Parse(time.RFC3339Nano, r.CreatedAt)
	updated, _ := time.Parse(time.RFC3339Nano, r.UpdatedAt)
	var events []string
	_ = json.Unmarshal([]byte(r.Events), &events)
	pid := ""
	if r.PropertyID.Valid {
		pid = r.PropertyID.String
	}
	return domain.Webhook{
		ID: r.ID, Name: r.Name, URL: r.URL, Secret: r.Secret,
		Events: events, PropertyID: pid, Active: r.Active != 0,
		CreatedBy: r.CreatedBy, CreatedAt: created, UpdatedAt: updated,
	}
}

func (r *webhookRepo) Create(ctx context.Context, w *domain.Webhook) error {
	if w.CreatedAt.IsZero() {
		w.CreatedAt = nowUTC()
	}
	w.UpdatedAt = nowUTC()
	events, _ := json.Marshal(w.Events)
	var pid any
	if w.PropertyID != "" {
		pid = w.PropertyID
	}
	active := 0
	if w.Active {
		active = 1
	}
	_, err := r.db.ExecContext(ctx,
		`INSERT INTO webhooks(id,name,url,secret,events,property_id,active,created_by,created_at,updated_at)
		 VALUES(?,?,?,?,?,?,?,?,?,?)`,
		w.ID, w.Name, w.URL, w.Secret, string(events), pid, active,
		w.CreatedBy, w.CreatedAt.Format(time.RFC3339Nano), w.UpdatedAt.Format(time.RFC3339Nano))
	return err
}

func (r *webhookRepo) GetByID(ctx context.Context, id string) (*domain.Webhook, error) {
	var row webhookRow
	if err := r.db.GetContext(ctx, &row, `SELECT * FROM webhooks WHERE id=?`, id); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, store.ErrNotFound
		}
		return nil, err
	}
	d := row.toDomain()
	return &d, nil
}

func (r *webhookRepo) List(ctx context.Context) ([]domain.Webhook, error) {
	var rows []webhookRow
	if err := r.db.SelectContext(ctx, &rows, `SELECT * FROM webhooks ORDER BY created_at DESC`); err != nil {
		return nil, err
	}
	out := make([]domain.Webhook, 0, len(rows))
	for _, r := range rows {
		out = append(out, r.toDomain())
	}
	return out, nil
}

// ListActiveForEvent returns active webhooks that subscribed to `event` and
// either have no property scope or match `propertyID`.
func (r *webhookRepo) ListActiveForEvent(ctx context.Context, event, propertyID string) ([]domain.Webhook, error) {
	all, err := r.List(ctx)
	if err != nil {
		return nil, err
	}
	out := make([]domain.Webhook, 0, len(all))
	for _, w := range all {
		if !w.Active {
			continue
		}
		if w.PropertyID != "" && w.PropertyID != propertyID {
			continue
		}
		matched := false
		for _, e := range w.Events {
			if e == event {
				matched = true
				break
			}
		}
		if matched {
			out = append(out, w)
		}
	}
	return out, nil
}

func (r *webhookRepo) Update(ctx context.Context, w *domain.Webhook) error {
	w.UpdatedAt = nowUTC()
	events, _ := json.Marshal(w.Events)
	var pid any
	if w.PropertyID != "" {
		pid = w.PropertyID
	}
	active := 0
	if w.Active {
		active = 1
	}
	res, err := r.db.ExecContext(ctx,
		`UPDATE webhooks SET name=?,url=?,secret=?,events=?,property_id=?,active=?,updated_at=? WHERE id=?`,
		w.Name, w.URL, w.Secret, string(events), pid, active,
		w.UpdatedAt.Format(time.RFC3339Nano), w.ID)
	if err != nil {
		return err
	}
	n, _ := res.RowsAffected()
	if n == 0 {
		return store.ErrNotFound
	}
	return nil
}

func (r *webhookRepo) Delete(ctx context.Context, id string) error {
	res, err := r.db.ExecContext(ctx, `DELETE FROM webhooks WHERE id=?`, id)
	if err != nil {
		return err
	}
	n, _ := res.RowsAffected()
	if n == 0 {
		return store.ErrNotFound
	}
	return nil
}

// ── webhook deliveries ──────────────────────────────────────────────────────

type webhookDeliveryRepo struct{ db *sqlx.DB }

type deliveryRow struct {
	ID        string `db:"id"`
	WebhookID string `db:"webhook_id"`
	Event     string `db:"event"`
	Payload   string `db:"payload"`
	Status    string `db:"status"`
	HTTPCode  int    `db:"http_code"`
	Attempts  int    `db:"attempts"`
	LastError string `db:"last_error"`
	CreatedAt string `db:"created_at"`
	UpdatedAt string `db:"updated_at"`
}

func (r deliveryRow) toDomain() domain.WebhookDelivery {
	created, _ := time.Parse(time.RFC3339Nano, r.CreatedAt)
	updated, _ := time.Parse(time.RFC3339Nano, r.UpdatedAt)
	return domain.WebhookDelivery{
		ID: r.ID, WebhookID: r.WebhookID, Event: r.Event,
		Payload: r.Payload, Status: r.Status, HTTPCode: r.HTTPCode,
		Attempts: r.Attempts, LastError: r.LastError,
		CreatedAt: created, UpdatedAt: updated,
	}
}

func (r *webhookDeliveryRepo) Create(ctx context.Context, d *domain.WebhookDelivery) error {
	if d.CreatedAt.IsZero() {
		d.CreatedAt = nowUTC()
	}
	d.UpdatedAt = nowUTC()
	_, err := r.db.ExecContext(ctx,
		`INSERT INTO webhook_deliveries(id,webhook_id,event,payload,status,http_code,attempts,last_error,created_at,updated_at)
		 VALUES(?,?,?,?,?,?,?,?,?,?)`,
		d.ID, d.WebhookID, d.Event, d.Payload, d.Status, d.HTTPCode,
		d.Attempts, d.LastError,
		d.CreatedAt.Format(time.RFC3339Nano), d.UpdatedAt.Format(time.RFC3339Nano))
	return err
}

func (r *webhookDeliveryRepo) Update(ctx context.Context, d *domain.WebhookDelivery) error {
	d.UpdatedAt = nowUTC()
	_, err := r.db.ExecContext(ctx,
		`UPDATE webhook_deliveries SET status=?,http_code=?,attempts=?,last_error=?,updated_at=? WHERE id=?`,
		d.Status, d.HTTPCode, d.Attempts, d.LastError,
		d.UpdatedAt.Format(time.RFC3339Nano), d.ID)
	return err
}

func (r *webhookDeliveryRepo) ListByWebhook(ctx context.Context, webhookID string, limit int) ([]domain.WebhookDelivery, error) {
	if limit <= 0 || limit > 200 {
		limit = 50
	}
	var rows []deliveryRow
	if err := r.db.SelectContext(ctx, &rows,
		`SELECT * FROM webhook_deliveries WHERE webhook_id=? ORDER BY created_at DESC LIMIT ?`,
		webhookID, limit); err != nil {
		return nil, err
	}
	out := make([]domain.WebhookDelivery, 0, len(rows))
	for _, r := range rows {
		out = append(out, r.toDomain())
	}
	return out, nil
}

// ── inbound hooks ───────────────────────────────────────────────────────────

type inboundHookRepo struct{ db *sqlx.DB }

type inboundRow struct {
	ID         string `db:"id"`
	Name       string `db:"name"`
	Token      string `db:"token"`
	Secret     string `db:"secret"`
	PropertyID string `db:"property_id"`
	ColumnID   string `db:"column_id"`
	Active     int    `db:"active"`
	CreatedBy  string `db:"created_by"`
	CreatedAt  string `db:"created_at"`
	UpdatedAt  string `db:"updated_at"`
}

func (r inboundRow) toDomain() domain.InboundHook {
	created, _ := time.Parse(time.RFC3339Nano, r.CreatedAt)
	updated, _ := time.Parse(time.RFC3339Nano, r.UpdatedAt)
	return domain.InboundHook{
		ID: r.ID, Name: r.Name, Token: r.Token, Secret: r.Secret,
		PropertyID: r.PropertyID, ColumnID: r.ColumnID, Active: r.Active != 0,
		CreatedBy: r.CreatedBy, CreatedAt: created, UpdatedAt: updated,
	}
}

func (r *inboundHookRepo) Create(ctx context.Context, h *domain.InboundHook) error {
	if h.CreatedAt.IsZero() {
		h.CreatedAt = nowUTC()
	}
	h.UpdatedAt = nowUTC()
	active := 0
	if h.Active {
		active = 1
	}
	_, err := r.db.ExecContext(ctx,
		`INSERT INTO inbound_hooks(id,name,token,secret,property_id,column_id,active,created_by,created_at,updated_at)
		 VALUES(?,?,?,?,?,?,?,?,?,?)`,
		h.ID, h.Name, h.Token, h.Secret, h.PropertyID, h.ColumnID, active,
		h.CreatedBy, h.CreatedAt.Format(time.RFC3339Nano), h.UpdatedAt.Format(time.RFC3339Nano))
	return err
}

func (r *inboundHookRepo) GetByID(ctx context.Context, id string) (*domain.InboundHook, error) {
	var row inboundRow
	if err := r.db.GetContext(ctx, &row, `SELECT * FROM inbound_hooks WHERE id=?`, id); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, store.ErrNotFound
		}
		return nil, err
	}
	d := row.toDomain()
	return &d, nil
}

func (r *inboundHookRepo) GetByToken(ctx context.Context, token string) (*domain.InboundHook, error) {
	var row inboundRow
	if err := r.db.GetContext(ctx, &row, `SELECT * FROM inbound_hooks WHERE token=?`, token); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, store.ErrNotFound
		}
		return nil, err
	}
	d := row.toDomain()
	return &d, nil
}

func (r *inboundHookRepo) List(ctx context.Context) ([]domain.InboundHook, error) {
	var rows []inboundRow
	if err := r.db.SelectContext(ctx, &rows, `SELECT * FROM inbound_hooks ORDER BY created_at DESC`); err != nil {
		return nil, err
	}
	out := make([]domain.InboundHook, 0, len(rows))
	for _, r := range rows {
		out = append(out, r.toDomain())
	}
	return out, nil
}

func (r *inboundHookRepo) Update(ctx context.Context, h *domain.InboundHook) error {
	h.UpdatedAt = nowUTC()
	active := 0
	if h.Active {
		active = 1
	}
	res, err := r.db.ExecContext(ctx,
		`UPDATE inbound_hooks SET name=?,secret=?,property_id=?,column_id=?,active=?,updated_at=? WHERE id=?`,
		h.Name, h.Secret, h.PropertyID, h.ColumnID, active,
		h.UpdatedAt.Format(time.RFC3339Nano), h.ID)
	if err != nil {
		return err
	}
	n, _ := res.RowsAffected()
	if n == 0 {
		return store.ErrNotFound
	}
	return nil
}

func (r *inboundHookRepo) Delete(ctx context.Context, id string) error {
	res, err := r.db.ExecContext(ctx, `DELETE FROM inbound_hooks WHERE id=?`, id)
	if err != nil {
		return err
	}
	n, _ := res.RowsAffected()
	if n == 0 {
		return store.ErrNotFound
	}
	return nil
}
