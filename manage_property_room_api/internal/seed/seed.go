package seed

import (
	"context"
	"errors"
	"log"

	"github.com/google/uuid"

	"github.com/jose/manage_property_room_api/internal/auth"
	"github.com/jose/manage_property_room_api/internal/domain"
	"github.com/jose/manage_property_room_api/internal/store"
)

// Run inserts demo data if the users table is empty.
// Idempotent: safe to call on every startup.
func Run(ctx context.Context, s store.Store) error {
	users, err := s.Users().List(ctx)
	if err != nil {
		return err
	}
	if len(users) > 0 {
		return nil
	}
	log.Printf("[seed] inserting demo data")

	// ── Users ───────────────────────────────────────────────
	makeUser := func(email, name, initials, password string, role domain.UserRole, mustChange bool) *domain.User {
		hash, err := auth.HashPassword(password)
		if err != nil { panic(err) }
		return &domain.User{
			ID: uuid.NewString(), Email: email, PasswordHash: hash,
			Name: name, Initials: initials, Role: role,
			MustChangePassword: mustChange,
		}
	}
	maria := makeUser("maria@app.local", "María García", "MG", "admin123", domain.RoleAdmin, false)
	for _, u := range []*domain.User{maria} {
		if err := s.Users().Create(ctx, u); err != nil {
			return err
		}
	}

	// ── Properties ──────────────────────────────────────────
	props := []domain.Property{
		{ID: uuid.NewString(), Code: "FN13", Name: "FN13", TotalRooms: 5, ColorSeed: 0, Position: 0},
		{ID: uuid.NewString(), Code: "MR", Name: "Madrid Río", TotalRooms: 4, ColorSeed: 1, Position: 1},
		{ID: uuid.NewString(), Code: "RO", Name: "Romeo", TotalRooms: 3, ColorSeed: 2, Position: 2},
		{ID: uuid.NewString(), Code: "JU", Name: "Julieta", TotalRooms: 3, ColorSeed: 3, Position: 3},
		{ID: uuid.NewString(), Code: "MO", Name: "Moroto", TotalRooms: 2, ColorSeed: 4, Position: 4},
	}
	for i := range props {
		if err := s.Properties().Create(ctx, &props[i]); err != nil {
			return err
		}
	}

	// ── Default columns per property ────────────────────────
	defaultCols := []struct {
		Title string
		Color domain.ColumnColor
	}{
		{"Apartamentos libres", domain.ColorGreen},
		{"Aviso del día", domain.ColorYellow},
		{"Salidas", domain.ColorOrange},
		{"Hecho", domain.ColorBlue},
		{"Compras", domain.ColorPurple},
		{"Mantenimiento", domain.ColorRed},
	}
	// Track FN13 column IDs by title so we can seed demo cards below.
	fn13Cols := map[string]string{}
	for _, p := range props {
		for i, c := range defaultCols {
			col := &domain.BoardColumn{
				ID: uuid.NewString(), PropertyID: p.ID,
				Title: c.Title, Color: c.Color, Position: i,
			}
			if err := s.Columns().Create(ctx, col); err != nil {
				return err
			}
			if p.Code == "FN13" {
				fn13Cols[c.Title] = col.ID
			}
		}
	}

	// ── Default custom fields (paridad spec usuario) ───────
	fields := []domain.FieldDef{
		{ID: uuid.NewString(), Label: "Salida", Type: domain.FieldSelect, Options: []string{"Mañana", "Tarde", "Noche", "Flexible"}, Enabled: true, ShowOnCard: true, Position: 0},
		{ID: uuid.NewString(), Label: "Entrada", Type: domain.FieldCheckbox, Enabled: true, ShowOnCard: true, Position: 1},
		{ID: uuid.NewString(), Label: "Cobrar", Type: domain.FieldCheckbox, Enabled: true, ShowOnCard: false, Position: 2},
		{ID: uuid.NewString(), Label: "Status Mantenimiento", Type: domain.FieldSelect, Options: []string{"PENDIENTE", "EN PROCESO", "RESUELTO"}, Enabled: true, ShowOnCard: false, Position: 3},
		{ID: uuid.NewString(), Label: "PENDIENTE", Type: domain.FieldText, Enabled: true, ShowOnCard: false, Position: 4},
	}
	for i := range fields {
		if err := s.Fields().Create(ctx, &fields[i]); err != nil {
			if !errors.Is(err, store.ErrConflict) {
				return err
			}
		}
	}

	// ── Demo cards en FN13 (tablero de ejemplo) ────────────
	var fn13ID string
	for _, p := range props {
		if p.Code == "FN13" {
			fn13ID = p.ID
			break
		}
	}
	if fn13ID != "" && fn13Cols["Aviso del día"] != "" {
		demoCards := []domain.Card{
			{
				ID: uuid.NewString(), PropertyID: fn13ID, ColumnID: fn13Cols["Aviso del día"],
				Title: "Limpieza profunda 1A", RoomCode: "1A", Priority: domain.PriorityHigh,
				Kind: domain.CardKindRoom, CustomFields: map[string]any{}, Position: 0,
			},
			{
				ID: uuid.NewString(), PropertyID: fn13ID, ColumnID: fn13Cols["Salidas"],
				Title: "Salida 2B 11:00", RoomCode: "2B", Priority: domain.PriorityNormal,
				Kind: domain.CardKindRoom, CustomFields: map[string]any{}, Position: 0,
			},
			{
				ID: uuid.NewString(), PropertyID: fn13ID, ColumnID: fn13Cols["Apartamentos libres"],
				Title: "Apt 3C listo", RoomCode: "3C", Priority: domain.PriorityNormal,
				Kind: domain.CardKindRoom, CustomFields: map[string]any{}, Position: 0,
			},
		}
		for i := range demoCards {
			if err := s.Cards().Create(ctx, &demoCards[i]); err != nil {
				return err
			}
		}
	}

	log.Printf("[seed] done — admin: maria@app.local / admin123")
	return nil
}
