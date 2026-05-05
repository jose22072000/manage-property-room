import { useCallback, useState } from "react";
import { useNavigate } from "react-router-dom";
import { Icon } from "@iconify/react";
import {
  DndContext,
  closestCenter,
  PointerSensor,
  TouchSensor,
  useSensor,
  useSensors,
  type DragEndEvent,
} from "@dnd-kit/core";
import {
  SortableContext,
  useSortable,
  verticalListSortingStrategy,
  arrayMove,
} from "@dnd-kit/sortable";
import { CSS } from "@dnd-kit/utilities";
import { useSettingsStore } from "@/store/settingsStore";
import { useBoardStore, EMPTY_COLS } from "@/store/boardStore";
import { useConfirmStore } from "@/store/confirmStore";
import type { Column, ColumnConfig, FieldDef, FieldType } from "@/types/domain";
import { COLUMN_COLOR_CLASSES } from "@/types/domain";
import { cn } from "@/lib/utils";

const TYPE_LABELS: Record<FieldType, string> = {
  text: "Texto",
  select: "Lista de opciones",
  checkbox: "Activar / Desactivar",
  image: "Fotos / Imágenes",
};
const TYPE_ICONS: Record<FieldType, string> = {
  text: "mdi:form-textbox",
  select: "mdi:format-list-bulleted",
  checkbox: "mdi:toggle-switch-outline",
  image: "mdi:image-multiple-outline",
};

export function SettingsPage() {
  const navigate      = useNavigate();
  const fieldDefs     = useSettingsStore((s) => s.fieldDefs);
  const addField      = useSettingsStore((s) => s.addField);
  const updateField   = useSettingsStore((s) => s.updateField);
  const removeField   = useSettingsStore((s) => s.removeField);
  const reorderFields = useSettingsStore((s) => s.reorderFields);
  const ask           = useConfirmStore((s) => s.ask);

  const properties   = useBoardStore((s) => s.properties);
  const allColumns   = useBoardStore((s) => s.columns);

  const [editingId,    setEditingId]    = useState<string | null>(null);
  const [adding,       setAdding]       = useState(false);
  const [activePropId, setActivePropId] = useState<string | null>(null);
  const [openColId,    setOpenColId]    = useState<string | null>(null);

  // Auto-select first property once loaded
  const resolvedPropId = activePropId ?? properties[0]?.id ?? null;

  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 5 } }),
    useSensor(TouchSensor,   { activationConstraint: { delay: 200, tolerance: 5 } })
  );

  function handleDragEnd(event: DragEndEvent) {
    const { active, over } = event;
    if (!over || active.id === over.id) return;
    const oldIdx = fieldDefs.findIndex((f) => f.id === active.id);
    const newIdx = fieldDefs.findIndex((f) => f.id === over.id);
    if (oldIdx === -1 || newIdx === -1) return;
    reorderFields(arrayMove(fieldDefs, oldIdx, newIdx).map((f) => f.id));
  }

  const propCols: Column[] = resolvedPropId ? (allColumns[resolvedPropId] ?? EMPTY_COLS) : EMPTY_COLS;

  return (
    <div className="max-w-screen-sm mx-auto px-4 py-6 pb-24 md:pb-8">
      {/* Header */}
      <div className="flex items-center gap-3 mb-6">
        <button
          onClick={() => navigate(-1)}
          className="p-2 rounded-xl hover:bg-gray-100 text-gray-400 hover:text-gray-700 transition-colors"
        >
          <Icon icon="mdi:arrow-left" width={20} />
        </button>
        <div>
          <h1 className="text-xl font-bold text-gray-900">Configuración</h1>
          <p className="text-xs text-gray-400">Personaliza campos y comportamiento</p>
        </div>
      </div>

      {/* Section: Custom Fields */}
      <section className="mb-8">
        <div className="flex items-center justify-between mb-3">
          <div>
            <h2 className="text-sm font-bold text-gray-800 flex items-center gap-2">
              <Icon icon="mdi:form-textbox" className="text-blue-500" width={16} />
              Campos personalizados
            </h2>
            <p className="text-xs text-gray-400 mt-0.5">
              Arrastra <Icon icon="mdi:drag-vertical" className="inline text-gray-300" width={12} /> para reordenar
            </p>
          </div>
          <button
            onClick={() => { setAdding(true); setEditingId(null); }}
            className="flex items-center gap-1.5 text-xs font-semibold text-blue-600 hover:text-blue-800 bg-blue-50 hover:bg-blue-100 px-3 py-1.5 rounded-xl transition-colors"
          >
            <Icon icon="mdi:plus" width={14} />
            Añadir campo
          </button>
        </div>

        <DndContext sensors={sensors} collisionDetection={closestCenter} onDragEnd={handleDragEnd}>
          <SortableContext items={fieldDefs.map((f) => f.id)} strategy={verticalListSortingStrategy}>
            <div className="space-y-2">
              {fieldDefs.map((def) =>
                editingId === def.id ? (
                  <FieldEditForm
                    key={def.id}
                    initial={def}
                    onSave={(patch) => { updateField(def.id, patch); setEditingId(null); }}
                    onCancel={() => setEditingId(null)}
                  />
                ) : (
                  <SortableFieldRow
                    key={def.id}
                    def={def}
                    onEdit={() => { setEditingId(def.id); setAdding(false); }}
                    onToggleEnabled={() => updateField(def.id, { enabled: !def.enabled })}
                    onToggleShowOnCard={() => updateField(def.id, { showOnCard: !def.showOnCard })}
                    onDelete={async () => {
                      const ok = await ask({ message: `¿Eliminar el campo "${def.label}"?`, confirmLabel: "Eliminar", danger: true });
                      if (ok) removeField(def.id);
                    }}
                  />
                )
              )}
            </div>
          </SortableContext>
        </DndContext>

        {adding && (
          <div className="mt-3">
            <NewFieldForm
              onSave={(def) => { addField(def); setAdding(false); }}
              onCancel={() => setAdding(false)}
            />
          </div>
        )}
      </section>

      {/* Section: Column configuration */}
      <section>
        <div className="flex items-center gap-2 mb-3">
          <Icon icon="mdi:tune-variant" className="text-purple-500" width={16} />
          <h2 className="text-sm font-bold text-gray-800">Configurar listas</h2>
        </div>

        {/* Property tabs */}
        {properties.length > 1 && (
          <div className="flex gap-1.5 flex-wrap mb-3">
            {properties.map((p) => (
              <button
                key={p.id}
                onClick={() => { setActivePropId(p.id); setOpenColId(null); }}
                className={cn(
                  "px-3 py-1 rounded-full text-xs font-semibold transition-colors",
                  resolvedPropId === p.id
                    ? "bg-purple-100 text-purple-700"
                    : "bg-gray-100 text-gray-500 hover:bg-gray-200"
                )}
              >
                {p.name}
              </button>
            ))}
          </div>
        )}

        {propCols.length === 0 ? (
          <p className="text-xs text-gray-400 italic px-2">
            {properties.length === 0
              ? "No hay propiedades cargadas. Visita el tablero primero."
              : "Esta propiedad no tiene listas aún."}
          </p>
        ) : (
          <div className="space-y-2">
            {propCols.map((col) => (
              <ColumnConfigRow
                key={col.id}
                column={col}
                isOpen={openColId === col.id}
                onToggle={() => setOpenColId(openColId === col.id ? null : col.id)}
              />
            ))}
          </div>
        )}
      </section>
    </div>
  );
}

/* ─── ColumnConfigRow ───────────────────────────────────────────────────────── */
function Toggle({ checked, onChange }: { checked: boolean; onChange: (v: boolean) => void }) {
  return (
    <button
      onClick={() => onChange(!checked)}
      className={cn(
        "relative w-9 h-5 rounded-full transition-colors shrink-0",
        checked ? "bg-blue-500" : "bg-gray-300"
      )}
    >
      <span className={cn(
        "absolute top-0.5 left-0.5 w-4 h-4 bg-white rounded-full shadow transition-transform",
        checked ? "translate-x-4" : "translate-x-0"
      )} />
    </button>
  );
}

function ColSectionTitle({ icon, label }: { icon: string; label: string }) {
  return (
    <div className="flex items-center gap-1.5 mb-1.5 mt-0.5">
      <Icon icon={icon} className="text-gray-400" width={13} />
      <p className="text-[10px] font-bold text-gray-400 uppercase tracking-wider">{label}</p>
    </div>
  );
}

function ColumnConfigRow({ column, isOpen, onToggle }: {
  column: Column;
  isOpen: boolean;
  onToggle: () => void;
}) {
  const updateColumnConfig = useBoardStore((s) => s.updateColumnConfig);
  const updateColumnFields = useBoardStore((s) => s.updateColumnFields);
  const _allFieldDefs      = useSettingsStore((s) => s.fieldDefs);
  const enabledFields      = _allFieldDefs.filter((f) => f.enabled);

  const cfg        = column.columnConfig ?? {};
  const chipIds    = cfg.cardChipFieldIds;
  const fieldIds   = column.fieldIds;
  const colors     = COLUMN_COLOR_CLASSES[column.color] ?? COLUMN_COLOR_CLASSES.gray;

  const isChipActive = useCallback((id: string) => {
    if (chipIds === undefined) return _allFieldDefs.find((f) => f.id === id)?.showOnCard ?? false;
    return chipIds.includes(id);
  }, [chipIds, _allFieldDefs]);

  const toggleChipField = useCallback((id: string) => {
    const globalChips = enabledFields.filter((f) => f.showOnCard).map((f) => f.id);
    const current = chipIds ?? globalChips;
    const next = current.includes(id) ? current.filter((x) => x !== id) : [...current, id];
    const matchesGlobal = next.length === globalChips.length && next.every((x) => globalChips.includes(x));
    updateColumnConfig(column.id, { cardChipFieldIds: matchesGlobal ? undefined : next });
  }, [chipIds, enabledFields, column.id, updateColumnConfig]);

  const isFormActive = useCallback((id: string) => {
    if (fieldIds === undefined) return true;
    return fieldIds.includes(id);
  }, [fieldIds]);

  const toggleFormField = useCallback((id: string) => {
    const allEnabled = enabledFields.map((f) => f.id);
    const current = fieldIds ?? allEnabled;
    const next = current.includes(id) ? current.filter((x) => x !== id) : [...current, id];
    const isAll = allEnabled.length === next.length && allEnabled.every((x) => next.includes(x));
    updateColumnFields(column.id, isAll ? undefined : next);
  }, [fieldIds, enabledFields, column.id, updateColumnFields]);

  const showCfg = (key: keyof ColumnConfig): boolean => {
    const val = cfg[key as keyof typeof cfg];
    if (val === undefined) return true;
    if (typeof val === "boolean") return val;
    return true;
  };
  const setCfg = (patch: Partial<ColumnConfig>) => updateColumnConfig(column.id, patch);

  return (
    <div className={cn("bg-white border rounded-2xl overflow-hidden transition-shadow", isOpen ? "border-gray-200 shadow-sm" : "border-gray-100")}>
      {/* Header row */}
      <button
        onClick={onToggle}
        className="w-full flex items-center gap-2.5 px-3 py-2.5 hover:bg-gray-50 transition-colors"
      >
        <div className={cn("w-2 h-2 rounded-full shrink-0", colors.dot ?? "bg-gray-400")} />
        <span className="flex-1 text-left text-sm font-semibold text-gray-800">{column.title}</span>
        <Icon
          icon={isOpen ? "mdi:chevron-up" : "mdi:chevron-down"}
          className="text-gray-400 shrink-0"
          width={16}
        />
      </button>

      {/* Expanded config */}
      {isOpen && (
        <div className="border-t border-gray-100 px-3 py-3 space-y-4">

          {/* Chips en tarjeta */}
          {enabledFields.length > 0 && (
            <div>
              <div className="flex items-center justify-between">
                <ColSectionTitle icon="mdi:label-multiple-outline" label="Chips en tarjeta" />
                {chipIds !== undefined && (
                  <button
                    onClick={() => updateColumnConfig(column.id, { cardChipFieldIds: undefined })}
                    className="text-[10px] text-blue-500 hover:text-blue-700 mb-1"
                  >↺ Global</button>
                )}
              </div>
              <div className="rounded-xl border border-gray-100 divide-y divide-gray-50 overflow-hidden">
                {enabledFields.map((f) => (
                  <div key={f.id} className="flex items-center justify-between px-3 py-2 hover:bg-gray-50">
                    <div className="flex items-center gap-2">
                      {f.icon && <Icon icon={f.icon} className="text-gray-400" width={13} />}
                      <span className="text-sm text-gray-700">{f.label}</span>
                      {chipIds === undefined && f.showOnCard && (
                        <span className="text-[9px] bg-blue-50 text-blue-500 px-1 rounded font-medium">global</span>
                      )}
                    </div>
                    <Toggle checked={isChipActive(f.id)} onChange={() => toggleChipField(f.id)} />
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Campos del formulario */}
          {enabledFields.length > 0 && (
            <div>
              <div className="flex items-center justify-between">
                <ColSectionTitle icon="mdi:form-select" label="Campos del formulario" />
                {fieldIds !== undefined && (
                  <button
                    onClick={() => updateColumnFields(column.id, undefined)}
                    className="text-[10px] text-blue-500 hover:text-blue-700 mb-1"
                  >↺ Global</button>
                )}
              </div>
              <div className="rounded-xl border border-gray-100 divide-y divide-gray-50 overflow-hidden">
                {enabledFields.map((f) => (
                  <div key={f.id} className="flex items-center justify-between px-3 py-2 hover:bg-gray-50">
                    <div className="flex items-center gap-2">
                      {f.icon && <Icon icon={f.icon} className="text-gray-400" width={13} />}
                      <span className="text-sm text-gray-700">{f.label}</span>
                    </div>
                    <Toggle checked={isFormActive(f.id)} onChange={() => toggleFormField(f.id)} />
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Secciones del formulario */}
          <div>
            <ColSectionTitle icon="mdi:view-list-outline" label="Secciones del formulario" />
            <div className="rounded-xl border border-gray-100 divide-y divide-gray-50 overflow-hidden">
              {([
                { key: "showDescription" as const, label: "Descripción",            icon: "mdi:text-box-outline" },
                { key: "showComments"    as const, label: "Comentarios y actividad", icon: "mdi:comment-outline"  },
              ]).map(({ key, label, icon }) => (
                <div key={key} className="flex items-center justify-between px-3 py-2 hover:bg-gray-50">
                  <div className="flex items-center gap-2">
                    <Icon icon={icon} className="text-gray-400" width={13} />
                    <span className="text-sm text-gray-700">{label}</span>
                  </div>
                  <Toggle checked={showCfg(key)} onChange={(v) => setCfg({ [key]: v })} />
                </div>
              ))}
            </div>
          </div>

          {/* Barra lateral */}
          <div>
            <ColSectionTitle icon="mdi:dock-right" label="Barra lateral del formulario" />
            <div className="rounded-xl border border-gray-100 divide-y divide-gray-50 overflow-hidden">
              {([
                { key: "showAssign"   as const, label: "Asignar",         icon: "mdi:account-plus-outline" },
                { key: "showPriority" as const, label: "Prioridad",        icon: "mdi:tag-outline"          },
                { key: "showCheckin"  as const, label: "Fecha de checkin", icon: "mdi:calendar-outline"     },
              ]).map(({ key, label, icon }) => (
                <div key={key} className="flex items-center justify-between px-3 py-2 hover:bg-gray-50">
                  <div className="flex items-center gap-2">
                    <Icon icon={icon} className="text-gray-400" width={13} />
                    <span className="text-sm text-gray-700">{label}</span>
                  </div>
                  <Toggle checked={showCfg(key)} onChange={(v) => setCfg({ [key]: v })} />
                </div>
              ))}
            </div>
          </div>

          {/* Elementos de la tarjeta */}
          <div>
            <ColSectionTitle icon="mdi:card-text-outline" label="Elementos de la tarjeta" />
            <div className="rounded-xl border border-gray-100 divide-y divide-gray-50 overflow-hidden">
              {([
                { key: "showCardRoomCode"    as const, label: "Código de habitación",            icon: "mdi:door-open"           },
                { key: "showCardDescription" as const, label: "Vista previa descripción",         icon: "mdi:text-short"          },
                { key: "showCardFooter"      as const, label: "Pie (comentarios, fecha, asignado)", icon: "mdi:information-outline" },
                { key: "showCardDoneStamp"   as const, label: 'Sello "Lista" (limpiado por)',     icon: "mdi:check-circle-outline" },
              ]).map(({ key, label, icon }) => (
                <div key={key} className="flex items-center justify-between px-3 py-2 hover:bg-gray-50">
                  <div className="flex items-center gap-2 min-w-0">
                    <Icon icon={icon} className="text-gray-400 shrink-0" width={13} />
                    <span className="text-sm text-gray-700 leading-tight">{label}</span>
                  </div>
                  <Toggle checked={showCfg(key)} onChange={(v) => setCfg({ [key]: v })} />
                </div>
              ))}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

/* ─── SortableFieldRow ──────────────────────────────────────────────────────── */
function SortableFieldRow({
  def, onEdit, onToggleEnabled, onToggleShowOnCard, onDelete,
}: {
  def: FieldDef;
  onEdit: () => void;
  onToggleEnabled: () => void;
  onToggleShowOnCard: () => void;
  onDelete: () => void;
}) {
  const {
    attributes, listeners, setNodeRef,
    transform, transition, isDragging,
  } = useSortable({ id: def.id });

  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
  };

  return (
    <div
      ref={setNodeRef}
      style={style}
      className={cn(
        "bg-white border rounded-2xl px-3 py-3 transition-all",
        def.enabled ? "border-gray-200" : "border-gray-100 opacity-60",
        isDragging && "shadow-xl opacity-80 z-50"
      )}
    >
      <div className="flex items-center gap-2">
        {/* Drag handle */}
        <button
          {...listeners}
          {...attributes}
          className="p-1 cursor-grab active:cursor-grabbing text-gray-300 hover:text-gray-500 shrink-0 touch-none"
          tabIndex={-1}
        >
          <Icon icon="mdi:drag-vertical" width={16} />
        </button>

        {/* Icon */}
        <div className="w-8 h-8 rounded-xl bg-gray-100 flex items-center justify-center shrink-0">
          <Icon icon={def.icon ?? TYPE_ICONS[def.type]} className="text-gray-500" width={16} />
        </div>

        {/* Label + type */}
        <div className="flex-1 min-w-0">
          <p className="text-sm font-semibold text-gray-800">{def.label}</p>
          <p className="text-[10px] text-gray-400">
            {TYPE_LABELS[def.type]}
            {def.type === "select" && def.options?.length ? ` · ${def.options.join(", ")}` : ""}
          </p>
        </div>

        {/* Action buttons */}
        <div className="flex items-center gap-1">
          <ToggleBtn
            active={!!def.showOnCard}
            icon="mdi:card-outline"
            title="Mostrar chip en tarjeta"
            onClick={onToggleShowOnCard}
          />
          <button
            onClick={onEdit}
            className="p-1.5 rounded-lg text-gray-400 hover:text-blue-600 hover:bg-blue-50 transition-colors"
            title="Editar"
          >
            <Icon icon="mdi:pencil-outline" width={14} />
          </button>
          <button
            onClick={onDelete}
            className="p-1.5 rounded-lg text-gray-400 hover:text-red-500 hover:bg-red-50 transition-colors"
            title="Eliminar"
          >
            <Icon icon="mdi:trash-can-outline" width={14} />
          </button>
          {/* Enable toggle */}
          <button
            onClick={onToggleEnabled}
            className={cn(
              "w-9 h-5 rounded-full transition-colors relative shrink-0",
              def.enabled ? "bg-blue-500" : "bg-gray-200"
            )}
            title={def.enabled ? "Desactivar" : "Activar"}
          >
            <span className={cn(
              "absolute top-0.5 w-4 h-4 rounded-full bg-white shadow transition-transform",
              def.enabled ? "translate-x-4" : "translate-x-0.5"
            )} />
          </button>
        </div>
      </div>
    </div>
  );
}

/* ─── FieldEditForm ─────────────────────────────────────────────────────────── */
function FieldEditForm({
  initial, onSave, onCancel,
}: {
  initial: FieldDef;
  onSave: (patch: Partial<FieldDef>) => void;
  onCancel: () => void;
}) {
  const [label,   setLabel]   = useState(initial.label);
  const [type,    setType]    = useState<FieldType>(initial.type);
  const [options, setOptions] = useState((initial.options ?? []).join("\n"));

  function save() {
    if (!label.trim()) return;
    const opts = options.split("\n").map((o) => o.trim()).filter(Boolean);
    onSave({
      label: label.trim(),
      type,
      options: type === "select" ? opts : undefined,
    });
  }

  return <FieldForm label={label} setLabel={setLabel} type={type} setType={setType}
    options={options} setOptions={setOptions} onSave={save} onCancel={onCancel} saveLabel="Guardar" />;
}

/* ─── NewFieldForm ─────────────────────────────────────────────────────────── */
function NewFieldForm({
  onSave, onCancel,
}: {
  onSave: (def: Omit<FieldDef, "id">) => void;
  onCancel: () => void;
}) {
  const [label,   setLabel]   = useState("");
  const [type,    setType]    = useState<FieldType>("text");
  const [options, setOptions] = useState("");

  function save() {
    if (!label.trim()) return;
    const opts = options.split("\n").map((o) => o.trim()).filter(Boolean);
    onSave({
      label: label.trim(),
      type,
      options: type === "select" ? opts : undefined,
      enabled: true,
      showOnCard: false,
    });
  }

  return <FieldForm label={label} setLabel={setLabel} type={type} setType={setType}
    options={options} setOptions={setOptions} onSave={save} onCancel={onCancel} saveLabel="Añadir campo" />;
}

/* ─── Shared FieldForm ──────────────────────────────────────────────────────── */
function FieldForm({
  label, setLabel, type, setType, options, setOptions, onSave, onCancel, saveLabel,
}: {
  label: string; setLabel: (v: string) => void;
  type: FieldType; setType: (v: FieldType) => void;
  options: string; setOptions: (v: string) => void;
  onSave: () => void; onCancel: () => void;
  saveLabel: string;
}) {
  return (
    <div className="bg-white border-2 border-blue-200 rounded-2xl p-4 space-y-3">
      <div>
        <label className="text-[10px] font-semibold text-gray-500 uppercase tracking-wide block mb-1">Nombre del campo</label>
        <input
          autoFocus
          value={label}
          onChange={(e) => setLabel(e.target.value)}
          onKeyDown={(e) => { if (e.key === "Enter") onSave(); if (e.key === "Escape") onCancel(); }}
          placeholder="Ej: Habitación, Limpieza extra…"
          className="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400"
        />
      </div>
      <div>
        <label className="text-[10px] font-semibold text-gray-500 uppercase tracking-wide block mb-1">Tipo de campo</label>
        <div className="grid grid-cols-2 gap-2">
          {(["text", "select", "checkbox", "image"] as FieldType[]).map((t) => (
            <button
              key={t}
              onClick={() => setType(t)}
              className={cn(
                "flex flex-col items-center gap-1 p-2 rounded-xl border text-xs font-medium transition-colors",
                type === t
                  ? "border-blue-400 bg-blue-50 text-blue-700"
                  : "border-gray-200 text-gray-600 hover:bg-gray-50"
              )}
            >
              <Icon icon={TYPE_ICONS[t]} width={18} />
              {TYPE_LABELS[t]}
            </button>
          ))}
        </div>
      </div>
      {type === "select" && (
        <div>
          <label className="text-[10px] font-semibold text-gray-500 uppercase tracking-wide block mb-1">
            Opciones <span className="font-normal normal-case text-gray-400">(una por línea)</span>
          </label>
          <textarea
            value={options}
            onChange={(e) => setOptions(e.target.value)}
            rows={4}
            placeholder={"Opción 1\nOpción 2\nOpción 3"}
            className="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400 resize-none font-mono"
          />
        </div>
      )}
      <div className="flex gap-2 pt-1">
        <button
          onClick={onSave}
          disabled={!label.trim()}
          className="flex-1 py-2 bg-blue-500 hover:bg-blue-600 disabled:opacity-40 text-white text-sm font-semibold rounded-xl transition-colors"
        >
          {saveLabel}
        </button>
        <button onClick={onCancel} className="px-4 py-2 bg-gray-100 hover:bg-gray-200 text-gray-700 text-sm rounded-xl transition-colors">
          Cancelar
        </button>
      </div>
    </div>
  );
}

function ToggleBtn({ active, icon, title, onClick }: { active: boolean; icon: string; title: string; onClick: () => void }) {
  return (
    <button
      onClick={onClick}
      title={title}
      className={cn(
        "p-1.5 rounded-lg transition-colors",
        active ? "text-blue-600 bg-blue-50" : "text-gray-300 hover:text-gray-500 hover:bg-gray-100"
      )}
    >
      <Icon icon={icon} width={14} />
    </button>
  );
}
