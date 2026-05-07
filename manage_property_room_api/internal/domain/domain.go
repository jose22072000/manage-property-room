// Package domain holds pure entities. Mirrors the Flutter `lib/domain` layer.
package domain

import "time"

// ── Enums (string-typed for JSON parity with Flutter `.name`) ──

type UserRole string

const (
	RoleAdmin       UserRole = "admin"
	RoleOperator    UserRole = "operator"
	RoleCleaning    UserRole = "cleaning"
	RoleMaintenance UserRole = "maintenance"
)

type CardKind string

const (
	CardKindRoom CardKind = "room"
	CardKindTask CardKind = "task"
	CardKindFree CardKind = "free"
)

type FieldType string

const (
	FieldText     FieldType = "text"
	FieldSelect   FieldType = "select"
	FieldCheckbox FieldType = "checkbox"
	FieldImage    FieldType = "image"
)

type ColumnColor string

const (
	ColorGreen  ColumnColor = "green"
	ColorYellow ColumnColor = "yellow"
	ColorOrange ColumnColor = "orange"
	ColorRed    ColumnColor = "red"
	ColorPurple ColumnColor = "purple"
	ColorBlue   ColumnColor = "blue"
	ColorCyan   ColumnColor = "cyan"
	ColorLime   ColumnColor = "lime"
	ColorPink   ColumnColor = "pink"
	ColorGray   ColumnColor = "gray"
)

type CardPriority string

const (
	PriorityLow    CardPriority = "low"
	PriorityNormal CardPriority = "normal"
	PriorityHigh   CardPriority = "high"
)

type ActivityType string

const (
	ActivityCreated   ActivityType = "created"
	ActivityMoved     ActivityType = "moved"
	ActivityArchived  ActivityType = "archived"
	ActivityDone      ActivityType = "done"
	ActivityUndone    ActivityType = "undone"
	ActivityCommented ActivityType = "commented"
	ActivityAssigned  ActivityType = "assigned"
	ActivityEdited    ActivityType = "edited"
)

type ArchiveKind string

const (
	ArchiveKindCard   ArchiveKind = "card"
	ArchiveKindColumn ArchiveKind = "column"
)

// ── Entities ──

type User struct {
	ID                  string    `json:"id" db:"id"`
	Email               string    `json:"email" db:"email"`
	PasswordHash        string    `json:"-" db:"password_hash"`
	Name                string    `json:"name" db:"name"`
	Initials            string    `json:"initials" db:"initials"`
	Role                UserRole  `json:"role" db:"role"`
	MustChangePassword  bool      `json:"mustChangePassword" db:"must_change_password"`
	AssignedPropertyIDs []string  `json:"assignedPropertyIds" db:"-"`
	CreatedAt           time.Time `json:"createdAt" db:"created_at"`
	UpdatedAt           time.Time `json:"updatedAt" db:"updated_at"`
}

type Property struct {
	ID         string    `json:"id" db:"id"`
	Code       string    `json:"code" db:"code"`
	Name       string    `json:"name" db:"name"`
	TotalRooms int       `json:"totalRooms" db:"total_rooms"`
	ColorSeed  int       `json:"colorSeed" db:"color_seed"`
	Position   int       `json:"position" db:"position"`
	Archived   bool      `json:"archived" db:"archived"`
	CreatedAt  time.Time `json:"createdAt" db:"created_at"`
	UpdatedAt  time.Time `json:"updatedAt" db:"updated_at"`
}

type ColumnConfig struct {
	// Form-level toggles (shown in card detail sheet)
	ShowDescription  *bool `json:"showDescription,omitempty"`
	ShowCustomFields *bool `json:"showCustomFields,omitempty"`
	ShowComments     *bool `json:"showComments,omitempty"`
	ShowAssign       *bool `json:"showAssign,omitempty"`
	ShowPriority     *bool `json:"showPriority,omitempty"`
	ShowCheckin      *bool `json:"showCheckin,omitempty"`
	// Card chip field IDs
	CardChipFieldIDs []string `json:"cardChipFieldIds,omitempty"`
	// Card compact-view toggles (persistent, formerly CardDisplayPrefs)
	CardShowDone           *bool `json:"cardShowDone,omitempty"`
	CardShowDescription    *bool `json:"cardShowDescription,omitempty"`
	CardShowCleanedBy      *bool `json:"cardShowCleanedBy,omitempty"`
	CardShowPriority       *bool `json:"cardShowPriority,omitempty"`
	CardShowPriorityBorder *bool `json:"cardShowPriorityBorder,omitempty"`
	CardShowCheckin        *bool `json:"cardShowCheckin,omitempty"`
	CardShowRoomCode       *bool `json:"cardShowRoomCode,omitempty"`
	CardShowImage          *bool `json:"cardShowImage,omitempty"`
}

type BoardColumn struct {
	ID          string        `json:"id" db:"id"`
	PropertyID  string        `json:"propertyId" db:"property_id"`
	Title       string        `json:"title" db:"title"`
	Color       ColumnColor   `json:"color" db:"color"`
	Position    int           `json:"position" db:"position"`
	Description string        `json:"description" db:"description"`
	Archived    bool          `json:"archived" db:"archived"`
	FieldIDs    []string      `json:"fieldIds,omitempty" db:"-"`
	Config      *ColumnConfig `json:"columnConfig,omitempty" db:"-"`
	CreatedAt   time.Time     `json:"createdAt" db:"created_at"`
	UpdatedAt   time.Time     `json:"updatedAt" db:"updated_at"`
}

type Card struct {
	ID           string                 `json:"id" db:"id"`
	PropertyID   string                 `json:"propertyId" db:"property_id"`
	ColumnID     string                 `json:"columnId" db:"column_id"`
	Title        string                 `json:"title" db:"title"`
	Description  string                 `json:"description" db:"description"`
	Position     int                    `json:"position" db:"position"`
	IsDone       bool                   `json:"isDone" db:"is_done"`
	Archived     bool                   `json:"archived" db:"archived"`
	RoomCode     string                 `json:"roomCode" db:"room_code"`
	Priority     CardPriority           `json:"priority" db:"priority"`
	CheckinDate  *time.Time             `json:"checkinDate,omitempty" db:"checkin_date"`
	AssignedToID *string                `json:"assignedToId,omitempty" db:"assigned_to_id"`
	Kind         CardKind               `json:"kind" db:"kind"`
	CustomFields map[string]any         `json:"customFields" db:"-"`
	CreatedAt    time.Time              `json:"createdAt" db:"created_at"`
	UpdatedAt    time.Time              `json:"updatedAt" db:"updated_at"`
	CleanedBy    string                 `json:"cleanedBy" db:"cleaned_by"`
	DoneAt       *time.Time             `json:"doneAt,omitempty" db:"done_at"`
}

type FieldDef struct {
	ID         string    `json:"id" db:"id"`
	Label      string    `json:"label" db:"label"`
	Type       FieldType `json:"type" db:"type"`
	Options    []string  `json:"options,omitempty" db:"-"`
	Enabled    bool      `json:"enabled" db:"enabled"`
	ShowOnCard bool      `json:"showOnCard" db:"show_on_card"`
	Icon       string    `json:"icon,omitempty" db:"icon"`
	OffLabel   string    `json:"offLabel,omitempty" db:"off_label"`
	Position   int       `json:"position" db:"position"`
}

type Comment struct {
	ID        string    `json:"id" db:"id"`
	CardID    string    `json:"cardId" db:"card_id"`
	AuthorID  string    `json:"authorId" db:"author_id"`
	Text      string    `json:"text" db:"text"`
	CreatedAt time.Time `json:"createdAt" db:"created_at"`
}

type ActivityEvent struct {
	ID        string         `json:"id" db:"id"`
	CardID    string         `json:"cardId" db:"card_id"`
	UserID    string         `json:"userId" db:"user_id"`
	Type      ActivityType   `json:"type" db:"type"`
	Payload   map[string]any `json:"payload,omitempty" db:"-"`
	CreatedAt time.Time      `json:"createdAt" db:"created_at"`
}

type ArchiveItem struct {
	ID         string         `json:"id" db:"id"`
	Kind       ArchiveKind    `json:"kind" db:"kind"`
	Payload    map[string]any `json:"payload" db:"-"`
	ArchivedAt time.Time      `json:"archivedAt" db:"archived_at"`
}

// AuditEvent records a mutation performed by a user.
type AuditEvent struct {
	ID        string    `json:"id" db:"id"`
	ActorID   string    `json:"actorId" db:"actor_id"`
	ActorName string    `json:"actorName" db:"actor_name"`
	Action    string    `json:"action" db:"action"`
	Entity    string    `json:"entity" db:"entity"`
	EntityID  string    `json:"entityId" db:"entity_id"`
	Detail    string    `json:"detail,omitempty" db:"detail"`
	CreatedAt time.Time `json:"createdAt" db:"created_at"`
}
