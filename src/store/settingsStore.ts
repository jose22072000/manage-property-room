import { create } from "zustand";
import { persist } from "zustand/middleware";
import type { FieldDef } from "@/types/domain";

function uid() { return crypto.randomUUID().slice(0, 8); }

export const DEFAULT_FIELD_DEFS: FieldDef[] = [
  {
    id: "salida",
    label: "Salida",
    type: "select",
    options: ["Mañana", "Tarde", "Noche", "Flexible"],
    enabled: true,
    showOnCard: true,
    icon: "mdi:exit-run",
  },
  {
    id: "entrada",
    label: "Entrada",
    type: "checkbox",
    enabled: true,
    showOnCard: true,
    icon: "mdi:login",
  },
  {
    id: "cobrar",
    label: "Cobrar",
    type: "checkbox",
    enabled: true,
    showOnCard: false,
    icon: "mdi:currency-eur",
  },
  {
    id: "statusMant",
    label: "Status Mantenimiento",
    type: "select",
    options: ["PENDIENTE", "EN PROCESO", "RESUELTO"],
    enabled: true,
    showOnCard: false,
    icon: "mdi:tools",
  },
  {
    id: "pendiente",
    label: "PENDIENTE",
    type: "text",
    enabled: true,
    showOnCard: false,
    icon: "mdi:alert-outline",
  },
];

type SettingsState = {
  fieldDefs: FieldDef[];
  addField:     (def: Omit<FieldDef, "id">) => void;
  updateField:  (id: string, patch: Partial<FieldDef>) => void;
  removeField:  (id: string) => void;
  reorderFields:(ids: string[]) => void;
};

export const useSettingsStore = create<SettingsState>()(
  persist(
    (set) => ({
      fieldDefs: DEFAULT_FIELD_DEFS,

      addField(def) {
        set((s) => ({ fieldDefs: [...s.fieldDefs, { ...def, id: uid() }] }));
      },

      updateField(id, patch) {
        set((s) => ({
          fieldDefs: s.fieldDefs.map((f) => (f.id === id ? { ...f, ...patch } : f)),
        }));
      },

      removeField(id) {
        set((s) => ({ fieldDefs: s.fieldDefs.filter((f) => f.id !== id) }));
      },

      reorderFields(ids) {
        set((s) => ({
          fieldDefs: ids
            .map((id) => s.fieldDefs.find((f) => f.id === id))
            .filter((f): f is FieldDef => !!f),
        }));
      },
    }),
    { name: "pmr-settings-v1" }
  )
);
