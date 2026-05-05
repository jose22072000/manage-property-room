import { useCallback } from "react";
import { Icon } from "@iconify/react";
import type { Column, ColumnConfig } from "@/types/domain";
import { useBoardStore } from "@/store/boardStore";
import { useSettingsStore } from "@/store/settingsStore";
import { cn } from "@/lib/utils";

type Props = {
  column: Column;
  onClose: () => void;
};

function Toggle({ checked, onChange }: { checked: boolean; onChange: (v: boolean) => void }) {
  return (
    <button
      onClick={() => onChange(!checked)}
      className={cn(
        "relative w-9 h-5 rounded-full transition-colors shrink-0",
        checked ? "bg-blue-500" : "bg-gray-300"
      )}
    >
      <span
        className={cn(
          "absolute top-0.5 left-0.5 w-4 h-4 bg-white rounded-full shadow transition-transform",
          checked ? "translate-x-4" : "translate-x-0"
        )}
      />
    </button>
  );
}

function SectionTitle({ icon, label }: { icon: string; label: string }) {
  return (
    <div className="flex items-center gap-1.5 mb-2 mt-1">
      <Icon icon={icon} className="text-gray-400" width={14} />
      <p className="text-[10px] font-bold text-gray-400 uppercase tracking-wider">{label}</p>
    </div>
  );
}

export function ColumnConfigModal({ column, onClose }: Props) {
  const updateColumnConfig = useBoardStore((s) => s.updateColumnConfig);
  const updateColumnFields = useBoardStore((s) => s.updateColumnFields);
  const _allFieldDefs = useSettingsStore((s) => s.fieldDefs);
  const enabledFields = _allFieldDefs.filter((f) => f.enabled);

  const cfg = column.columnConfig ?? {};

  // ── Chip fields ────────────────────────────────────────────────────────────
  const chipFieldIds = cfg.cardChipFieldIds;

  const isChipActive = useCallback(
    (fieldId: string) => {
      if (chipFieldIds === undefined) {
        return _allFieldDefs.find((f) => f.id === fieldId)?.showOnCard ?? false;
      }
      return chipFieldIds.includes(fieldId);
    },
    [chipFieldIds, _allFieldDefs]
  );

  const toggleChipField = useCallback(
    (fieldId: string) => {
      const globalChips = enabledFields.filter((f) => f.showOnCard).map((f) => f.id);
      const current = chipFieldIds ?? globalChips;
      const next = current.includes(fieldId)
        ? current.filter((id) => id !== fieldId)
        : [...current, fieldId];
      // If next matches global showOnCard exactly, reset to undefined
      const matchesGlobal =
        next.length === globalChips.length && next.every((id) => globalChips.includes(id));
      updateColumnConfig(column.id, { cardChipFieldIds: matchesGlobal ? undefined : next });
    },
    [chipFieldIds, enabledFields, column.id, updateColumnConfig]
  );

  const resetChips = useCallback(() => {
    updateColumnConfig(column.id, { cardChipFieldIds: undefined });
  }, [column.id, updateColumnConfig]);

  // ── Form fields ────────────────────────────────────────────────────────────
  const fieldIds = column.fieldIds;

  const isFormFieldActive = useCallback(
    (fieldId: string) => {
      if (fieldIds === undefined) return true;
      return fieldIds.includes(fieldId);
    },
    [fieldIds]
  );

  const toggleFormField = useCallback(
    (fieldId: string) => {
      const allEnabled = enabledFields.map((f) => f.id);
      const current = fieldIds ?? allEnabled;
      const next = current.includes(fieldId)
        ? current.filter((id) => id !== fieldId)
        : [...current, fieldId];
      const isAll = allEnabled.length === next.length && allEnabled.every((id) => next.includes(id));
      updateColumnFields(column.id, isAll ? undefined : next);
    },
    [fieldIds, enabledFields, column.id, updateColumnFields]
  );

  const resetFormFields = useCallback(() => {
    updateColumnFields(column.id, undefined);
  }, [column.id, updateColumnFields]);

  // ── Section toggles ────────────────────────────────────────────────────────
  const showCfg = (key: keyof ColumnConfig): boolean => {
    const val = cfg[key as keyof typeof cfg];
    if (val === undefined) return true;
    if (typeof val === "boolean") return val;
    return true;
  };

  const setCfg = (patch: Partial<ColumnConfig>) => {
    updateColumnConfig(column.id, patch);
  };

  const hasChipOverride = chipFieldIds !== undefined;
  const hasFormOverride = fieldIds !== undefined;

  return (
    <div
      className="fixed inset-0 z-[70] flex items-center justify-center p-4 bg-black/45 backdrop-blur-sm"
      onClick={(e) => { if (e.target === e.currentTarget) onClose(); }}
    >
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-sm max-h-[88vh] flex flex-col overflow-hidden">
        {/* Header */}
        <div className="flex items-center gap-2.5 px-4 py-3.5 border-b border-gray-100 shrink-0">
          <div className="w-8 h-8 rounded-xl bg-blue-50 flex items-center justify-center shrink-0">
            <Icon icon="mdi:tune-variant" className="text-blue-500" width={18} />
          </div>
          <div className="flex-1 min-w-0">
            <p className="text-[10px] text-gray-400 font-semibold uppercase tracking-wide leading-none">
              Configurar lista
            </p>
            <p className="text-sm font-bold text-gray-800 truncate leading-tight">{column.title}</p>
          </div>
          <button
            onClick={onClose}
            className="p-1.5 rounded-xl hover:bg-gray-100 text-gray-400 hover:text-gray-600 transition-colors shrink-0"
          >
            <Icon icon="mdi:close" width={18} />
          </button>
        </div>

        {/* Scrollable body */}
        <div className="overflow-y-auto flex-1 px-4 py-3 space-y-4 [&::-webkit-scrollbar]:w-1.5 [&::-webkit-scrollbar-thumb]:rounded-full [&::-webkit-scrollbar-thumb]:bg-gray-200">

          {/* ── CHIPS EN TARJETA ─────────────────────────────────────────── */}
          <section>
            <div className="flex items-center justify-between mb-1">
              <SectionTitle icon="mdi:label-multiple-outline" label="Chips en tarjeta" />
              {hasChipOverride && (
                <button
                  onClick={resetChips}
                  className="text-[10px] text-blue-500 hover:text-blue-700 transition-colors mb-1"
                >
                  ↺ Global
                </button>
              )}
            </div>
            {enabledFields.length === 0 ? (
              <p className="text-xs text-gray-400 italic px-2">No hay campos activos</p>
            ) : (
              <div className="rounded-xl border border-gray-100 divide-y divide-gray-50 overflow-hidden">
                {enabledFields.map((f) => (
                  <div key={f.id} className="flex items-center justify-between px-3 py-2 hover:bg-gray-50 transition-colors">
                    <div className="flex items-center gap-2">
                      {f.icon && <Icon icon={f.icon} className="text-gray-400" width={13} />}
                      <span className="text-sm text-gray-700">{f.label}</span>
                      {!hasChipOverride && f.showOnCard && (
                        <span className="text-[9px] bg-blue-50 text-blue-500 px-1 rounded font-medium">global</span>
                      )}
                    </div>
                    <Toggle checked={isChipActive(f.id)} onChange={() => toggleChipField(f.id)} />
                  </div>
                ))}
              </div>
            )}
          </section>

          <div className="h-px bg-gray-100" />

          {/* ── CAMPOS DEL FORMULARIO ────────────────────────────────────── */}
          <section>
            <div className="flex items-center justify-between mb-1">
              <SectionTitle icon="mdi:form-select" label="Campos del formulario" />
              {hasFormOverride && (
                <button
                  onClick={resetFormFields}
                  className="text-[10px] text-blue-500 hover:text-blue-700 transition-colors mb-1"
                >
                  ↺ Global
                </button>
              )}
            </div>
            {enabledFields.length === 0 ? (
              <p className="text-xs text-gray-400 italic px-2">No hay campos activos</p>
            ) : (
              <div className="rounded-xl border border-gray-100 divide-y divide-gray-50 overflow-hidden">
                {enabledFields.map((f) => (
                  <div key={f.id} className="flex items-center justify-between px-3 py-2 hover:bg-gray-50 transition-colors">
                    <div className="flex items-center gap-2">
                      {f.icon && <Icon icon={f.icon} className="text-gray-400" width={13} />}
                      <span className="text-sm text-gray-700">{f.label}</span>
                    </div>
                    <Toggle checked={isFormFieldActive(f.id)} onChange={() => toggleFormField(f.id)} />
                  </div>
                ))}
              </div>
            )}
          </section>

          <div className="h-px bg-gray-100" />

          {/* ── SECCIONES DEL FORMULARIO ─────────────────────────────────── */}
          <section>
            <SectionTitle icon="mdi:view-list-outline" label="Secciones del formulario" />
            <div className="rounded-xl border border-gray-100 divide-y divide-gray-50 overflow-hidden">
              {(
                [
                  { key: "showDescription" as const, label: "Descripción",                icon: "mdi:text-box-outline"  },
                  { key: "showComments"    as const, label: "Comentarios y actividad",    icon: "mdi:comment-outline"   },
                ] as const
              ).map(({ key, label, icon }) => (
                <div key={key} className="flex items-center justify-between px-3 py-2 hover:bg-gray-50 transition-colors">
                  <div className="flex items-center gap-2">
                    <Icon icon={icon} className="text-gray-400" width={13} />
                    <span className="text-sm text-gray-700">{label}</span>
                  </div>
                  <Toggle checked={showCfg(key)} onChange={(v) => setCfg({ [key]: v })} />
                </div>
              ))}
            </div>
          </section>

          <div className="h-px bg-gray-100" />

          {/* ── BARRA LATERAL ────────────────────────────────────────────── */}
          <section>
            <SectionTitle icon="mdi:dock-right" label="Barra lateral del formulario" />
            <div className="rounded-xl border border-gray-100 divide-y divide-gray-50 overflow-hidden">
              {(
                [
                  { key: "showAssign"   as const, label: "Asignar",          icon: "mdi:account-plus-outline" },
                  { key: "showPriority" as const, label: "Prioridad",         icon: "mdi:tag-outline"          },
                  { key: "showCheckin"  as const, label: "Fecha de checkin",  icon: "mdi:calendar-outline"     },
                ] as const
              ).map(({ key, label, icon }) => (
                <div key={key} className="flex items-center justify-between px-3 py-2 hover:bg-gray-50 transition-colors">
                  <div className="flex items-center gap-2">
                    <Icon icon={icon} className="text-gray-400" width={13} />
                    <span className="text-sm text-gray-700">{label}</span>
                  </div>
                  <Toggle checked={showCfg(key)} onChange={(v) => setCfg({ [key]: v })} />
                </div>
              ))}
            </div>
          </section>

          <div className="h-px bg-gray-100" />

          {/* ── ELEMENTOS DE LA TARJETA ──────────────────────────────────── */}
          <section>
            <SectionTitle icon="mdi:card-text-outline" label="Elementos de la tarjeta" />
            <div className="rounded-xl border border-gray-100 divide-y divide-gray-50 overflow-hidden">
              {(
                [
                  { key: "showCardRoomCode"    as const, label: "Código de habitación",   icon: "mdi:door-open"           },
                  { key: "showCardDescription" as const, label: "Vista previa descripción", icon: "mdi:text-short"         },
                  { key: "showCardFooter"      as const, label: "Pie (comentarios, fecha, asignado)", icon: "mdi:information-outline" },
                  { key: "showCardDoneStamp"   as const, label: 'Sello "Lista" (limpiado por)', icon: "mdi:check-circle-outline" },
                ] as const
              ).map(({ key, label, icon }) => (
                <div key={key} className="flex items-center justify-between px-3 py-2 hover:bg-gray-50 transition-colors">
                  <div className="flex items-center gap-2 min-w-0">
                    <Icon icon={icon} className="text-gray-400 shrink-0" width={13} />
                    <span className="text-sm text-gray-700 leading-tight">{label}</span>
                  </div>
                  <Toggle checked={showCfg(key)} onChange={(v) => setCfg({ [key]: v })} />
                </div>
              ))}
            </div>
          </section>
        </div>

        {/* Footer */}
        <div className="px-4 py-3 border-t border-gray-100 shrink-0">
          <button
            onClick={onClose}
            className="w-full text-sm font-semibold text-gray-600 hover:text-gray-900 hover:bg-gray-100 rounded-xl py-2 transition-colors"
          >
            Listo
          </button>
        </div>
      </div>
    </div>
  );
}
