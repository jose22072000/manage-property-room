package seed

import (
	"context"
	"errors"
	"log"

	"github.com/google/uuid"
	"github.com/jaswdr/faker/v2"

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

	fake := faker.New()
	_ = fake

	// ── Helpers ──────────────────────────────────────────────────
	makeUser := func(email, name, initials, password string, role domain.UserRole, mustChange bool, createdBy string) *domain.User {
		hash, err := auth.HashPassword(password)
		if err != nil { panic(err) }
		return &domain.User{
			ID: uuid.NewString(), Email: email, PasswordHash: hash,
			Name: name, Initials: initials, Role: role,
			MustChangePassword: mustChange, CreatedBy: createdBy,
		}
	}

	// ── Admin ─────────────────────────────────────────────────────
	admin := makeUser("admin@app.local", "María García", "MG", "admin123", domain.RoleAdmin, false, "")

	// ── Owners ───────────────────────────────────────────────────
	owner1 := makeUser("owner1@app.local", "Carlos Mendoza", "CM", "owner123", domain.RoleOwner, false, admin.ID)
	owner2 := makeUser("owner2@app.local", "Laura Rojas", "LR", "owner123", domain.RoleOwner, false, admin.ID)

	// ── Supervisors ──────────────────────────────────────────────
	sup1 := makeUser("sup1@app.local", "Andrés Torres", "AT", "super123", domain.RoleSupervisor, false, owner1.ID)
	sup2 := makeUser("sup2@app.local", "Patricia Vega", "PV", "super123", domain.RoleSupervisor, false, owner1.ID)
	sup3 := makeUser("sup3@app.local", "Juan Ramírez", "JR", "super123", domain.RoleSupervisor, false, owner2.ID)

	// ── Workers ──────────────────────────────────────────────────
	w1 := makeUser("clean1@app.local", "Ana López", "AL", "work123", domain.RoleCleaning, false, sup1.ID)
	w2 := makeUser("clean2@app.local", "Rosa Díaz", "RD", "work123", domain.RoleCleaning, false, sup1.ID)
	w3 := makeUser("clean3@app.local", "Carmen Silva", "CS", "work123", domain.RoleCleaning, false, sup2.ID)
	w4 := makeUser("maint1@app.local", "Pedro Gómez", "PG", "work123", domain.RoleMaintenance, false, sup1.ID)
	w5 := makeUser("maint2@app.local", "Luis Herrera", "LH", "work123", domain.RoleMaintenance, false, sup3.ID)

	allUsers := []*domain.User{admin, owner1, owner2, sup1, sup2, sup3, w1, w2, w3, w4, w5}
	for _, u := range allUsers {
		if err := s.Users().Create(ctx, u); err != nil { return err }
	}

	// ── Properties ───────────────────────────────────────────────
	props := []domain.Property{
		{ID: uuid.NewString(), Code: "FN13", Name: "FN13 - Centro", TotalRooms: 5, ColorSeed: 0, Position: 0, OwnerUserID: owner1.ID},
		{ID: uuid.NewString(), Code: "MR",   Name: "Madrid Río",    TotalRooms: 4, ColorSeed: 1, Position: 1, OwnerUserID: owner1.ID},
		{ID: uuid.NewString(), Code: "RO",   Name: "Romeo",         TotalRooms: 3, ColorSeed: 2, Position: 2, OwnerUserID: owner1.ID},
		{ID: uuid.NewString(), Code: "JU",   Name: "Julieta",       TotalRooms: 3, ColorSeed: 3, Position: 3, OwnerUserID: owner2.ID},
		{ID: uuid.NewString(), Code: "MO",   Name: "Moroto",        TotalRooms: 2, ColorSeed: 4, Position: 4, OwnerUserID: owner2.ID},
		{ID: uuid.NewString(), Code: "SL",   Name: "Sol y Luna",    TotalRooms: 6, ColorSeed: 5, Position: 5, OwnerUserID: owner2.ID},
	}
	for i := range props {
		if err := s.Properties().Create(ctx, &props[i]); err != nil { return err }
	}

	// ── Assign supervisors to properties ─────────────────────────
	_ = s.PropertySupervisors().SetSupervisors(ctx, props[0].ID, []string{sup1.ID})
	_ = s.PropertySupervisors().SetSupervisors(ctx, props[1].ID, []string{sup1.ID, sup2.ID})
	_ = s.PropertySupervisors().SetSupervisors(ctx, props[2].ID, []string{sup2.ID})
	_ = s.PropertySupervisors().SetSupervisors(ctx, props[3].ID, []string{sup3.ID})
	_ = s.PropertySupervisors().SetSupervisors(ctx, props[4].ID, []string{sup3.ID})
	_ = s.PropertySupervisors().SetSupervisors(ctx, props[5].ID, []string{sup3.ID})

	// ── Assign workers to properties ─────────────────────────────
	_ = s.Users().SetAssignedProperties(ctx, w1.ID, []string{props[0].ID, props[1].ID})
	_ = s.Users().SetAssignedProperties(ctx, w2.ID, []string{props[0].ID})
	_ = s.Users().SetAssignedProperties(ctx, w3.ID, []string{props[1].ID, props[2].ID})
	_ = s.Users().SetAssignedProperties(ctx, w4.ID, []string{props[0].ID, props[1].ID, props[2].ID})
	_ = s.Users().SetAssignedProperties(ctx, w5.ID, []string{props[3].ID, props[4].ID, props[5].ID})

	// ── Default columns per property ─────────────────────────────
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
	fn13Cols := map[string]string{}
	for _, p := range props {
		for i, c := range defaultCols {
			col := &domain.BoardColumn{
				ID: uuid.NewString(), PropertyID: p.ID,
				Title: c.Title, Color: c.Color, Position: i,
			}
			if err := s.Columns().Create(ctx, col); err != nil { return err }
			if p.Code == "FN13" { fn13Cols[c.Title] = col.ID }
		}
	}

	// ── Default custom fields ─────────────────────────────────────
	fields := []domain.FieldDef{
		{ID: uuid.NewString(), Label: "Salida", Type: domain.FieldSelect, Options: []string{"Mañana", "Tarde", "Noche", "Flexible"}, Enabled: true, ShowOnCard: true, Position: 0},
		{ID: uuid.NewString(), Label: "Entrada", Type: domain.FieldCheckbox, Enabled: true, ShowOnCard: true, Position: 1},
		{ID: uuid.NewString(), Label: "Cobrar", Type: domain.FieldCheckbox, Enabled: true, ShowOnCard: false, Position: 2},
		{ID: uuid.NewString(), Label: "Status Mantenimiento", Type: domain.FieldSelect, Options: []string{"PENDIENTE", "EN PROCESO", "RESUELTO"}, Enabled: true, ShowOnCard: false, Position: 3},
		{ID: uuid.NewString(), Label: "PENDIENTE", Type: domain.FieldText, Enabled: true, ShowOnCard: false, Position: 4},
	}
	for i := range fields {
		if err := s.Fields().Create(ctx, &fields[i]); err != nil {
			if !errors.Is(err, store.ErrConflict) { return err }
		}
	}

	// ── Demo cards for FN13 ──────────────────────────────────────
	var fn13ID string
	for _, p := range props {
		if p.Code == "FN13" { fn13ID = p.ID; break }
	}
	if fn13ID != "" && fn13Cols["Aviso del día"] != "" {
		demoCards := []domain.Card{
			{
				ID: uuid.NewString(), PropertyID: fn13ID, ColumnID: fn13Cols["Aviso del día"],
				Title: "Limpieza profunda 1A", RoomCode: "1A", Priority: domain.PriorityHigh,
				Kind: domain.CardKindRoom, CustomFields: map[string]any{}, Position: 0, AssignedToID: &w1.ID,
			},
			{
				ID: uuid.NewString(), PropertyID: fn13ID, ColumnID: fn13Cols["Salidas"],
				Title: "Salida 2B 11:00", RoomCode: "2B", Priority: domain.PriorityNormal,
				Kind: domain.CardKindRoom, CustomFields: map[string]any{}, Position: 0, AssignedToID: &w2.ID,
			},
			{
				ID: uuid.NewString(), PropertyID: fn13ID, ColumnID: fn13Cols["Apartamentos libres"],
				Title: "Apt 3C listo", RoomCode: "3C", Priority: domain.PriorityNormal,
				Kind: domain.CardKindRoom, CustomFields: map[string]any{}, Position: 0,
			},
			{
				ID: uuid.NewString(), PropertyID: fn13ID, ColumnID: fn13Cols["Mantenimiento"],
				Title: "Revisar calefacción 4D", RoomCode: "4D", Priority: domain.PriorityHigh,
				Kind: domain.CardKindRoom, CustomFields: map[string]any{}, Position: 0, AssignedToID: &w4.ID,
			},
			{
				ID: uuid.NewString(), PropertyID: fn13ID, ColumnID: fn13Cols["Compras"],
				Title: "Jabón y toallas", RoomCode: "", Priority: domain.PriorityNormal,
				Kind: domain.CardKindTask, CustomFields: map[string]any{}, Position: 0,
			},
		}
		for i := range demoCards {
			if err := s.Cards().Create(ctx, &demoCards[i]); err != nil { return err }
		}
	}

	log.Printf("[seed] done — admin: admin@app.local/admin123 | owner1: owner1@app.local/owner123 | sup1: sup1@app.local/super123 | worker: clean1@app.local/work123")
	return nil
}

