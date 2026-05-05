import { useEffect, useRef, useState } from "react";
import { Icon } from "@iconify/react";
import type { Card, Column, CardCustomFields } from "@/types/domain";
import { useBoardStore, EMPTY_COMMENTS, EMPTY_ACTIVITY } from "@/store/boardStore";
import { useSettingsStore } from "@/store/settingsStore";
import { useUserStore } from "@/store/userStore";
import { useToastStore } from "@/store/toastStore";
import { useConfirmStore } from "@/store/confirmStore";
import { mockUsers } from "@/mocks/mockUsers";
import { cn } from "@/lib/utils";

type Props = {
  card: Card;
  columns: Column[];
  onClose: () => void;
};

function fmtRelative(iso: string) {
  const diff = Date.now() - new Date(iso).getTime();
  const s = Math.floor(diff / 1000);
  if (s < 60)  return "hace unos segundos";
  const m = Math.floor(s / 60);
  if (m < 60)  return `hace ${m} minuto${m !== 1 ? "s" : ""}`;
  const h = Math.floor(m / 60);
  if (h < 24)  return `hace ${h} hora${h !== 1 ? "s" : ""}`;
  return new Date(iso).toLocaleDateString("es-ES", { day: "numeric", month: "short" });
}

export function CardDetailModal({ card, columns, onClose }: Props) {
  const updateCard     = useBoardStore((s) => s.updateCard);
  const moveCard       = useBoardStore((s) => s.moveCard);
  const archiveCard    = useBoardStore((s) => s.archiveCard);
  const addCommentFn   = useBoardStore((s) => s.addComment);
  const _comments      = useBoardStore((s) => s.comments[card.id]);
  const _activity      = useBoardStore((s) => s.activity[card.id]);
  const comments       = _comments  ?? EMPTY_COMMENTS;
  const activity       = _activity  ?? EMPTY_ACTIVITY;
  const currentUser    = useUserStore((s) => s.currentUser);
  const addToast       = useToastStore((s) => s.addToast);
  const ask            = useConfirmStore((s) => s.ask);

  // Live card from store (keep modal in sync)
  const liveCard = useBoardStore((s) => {
    for (const colId of Object.keys(s.cards)) {
      const found = s.cards[colId].find((c) => c.id === card.id);
      if (found) return found;
    }
    return card;
  });

  const [title,       setTitle]      = useState(liveCard.title);
  const [editingTitle, setEditingTitle] = useState(false);
  const [description, setDescription] = useState(liveCard.description ?? "");
  const [editingDesc,  setEditingDesc]  = useState(false);
  const [commentText, setCommentText] = useState("");
  const [showActivity, setShowActivity] = useState(false);
  const [expandedAction, setExpandedAction] = useState<"assign" | "labels" | "date" | null>(null);

  const _allFieldDefs = useSettingsStore((s) => s.fieldDefs);
  const liveColumns   = useBoardStore((s) => s.columns);
  // Find which column this card is currently in to apply per-column field config
  const currentCol = columns.find((c) => c.id === liveCard.columnId)
    ?? Object.values(liveColumns).flat().find((c) => c.id === liveCard.columnId);
  const cfg = currentCol?.columnConfig ?? {};
  // Helper: returns true when a column config boolean is unset (defaults to true)
  const cfgShow = (key: keyof typeof cfg) => {
    const v = cfg[key];
    return v === undefined || v === true;
  };
  const fieldDefs = _allFieldDefs.filter((f) => {
    if (!f.enabled) return false;
    if (currentCol?.fieldIds !== undefined) return currentCol.fieldIds.includes(f.id);
    return true;
  });

  // Draft state for text inputs only
  const [textDrafts, setTextDrafts] = useState<Record<string, string>>(() => {
    const init: Record<string, string> = {};
    for (const [k, v] of Object.entries(liveCard.customFields ?? {})) {
      if (typeof v === "string") init[k] = v;
    }
    return init;
  });
  useEffect(() => {
    const init: Record<string, string> = {};
    for (const [k, v] of Object.entries(liveCard.customFields ?? {})) {
      if (typeof v === "string") init[k] = v;
    }
    setTextDrafts(init);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [card.id]);

  const titleRef = useRef<HTMLInputElement>(null);
  const descRef  = useRef<HTMLTextAreaElement>(null);

  useEffect(() => { if (editingTitle) titleRef.current?.focus(); }, [editingTitle]);
  useEffect(() => { if (editingDesc)  descRef.current?.focus();  }, [editingDesc]);

  // Close on Escape
  useEffect(() => {
    function onKey(e: KeyboardEvent) { if (e.key === "Escape") onClose(); }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);

  function saveTitle() {
    const t = title.trim();
    if (t && t !== liveCard.title) updateCard(card.id, { title: t });
    setEditingTitle(false);
  }

  function saveDescription() {
    updateCard(card.id, { description: description.trim() || undefined });
    setEditingDesc(false);
  }

  function updateFields(patch: Record<string, string | boolean | undefined>) {
    const merged = { ...(liveCard.customFields ?? {}), ...patch };
    const cleaned = Object.fromEntries(Object.entries(merged).filter(([, v]) => v !== undefined && v !== false));
    updateCard(card.id, { customFields: Object.keys(cleaned).length > 0 ? cleaned as CardCustomFields : undefined });
  }

  function handleMoveToColumn(colId: string) {
    if (colId !== liveCard.columnId) {
      moveCard(card.id, colId, currentUser.name);
      addToast("Tarjeta movida");
    }
  }

  function handleComment() {
    const t = commentText.trim();
    if (!t) return;
    addCommentFn(card.id, t, currentUser);
    setCommentText("");
  }

  async function handleArchive() {
    const ok = await ask({
      message: "¿Archivar esta tarjeta?",
      confirmLabel: "Archivar",
    });
    if (ok) {
      archiveCard(card.id, currentUser.name);
      addToast("Tarjeta archivada", { label: "Ver historial", href: "/archive" });
      onClose();
    }
  }

  // Sorted columns for move selector
  const sortedCols = [...columns].sort((a, b) => a.position - b.position);
  const sortedComments  = [...comments].sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
  const sortedActivity  = [...activity].sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());

  return (
    <div
      className="fixed inset-0 z-[60] flex items-start justify-center p-4 pt-10 overflow-y-auto"
      style={{ backgroundColor: "rgba(0,0,0,0.55)", backdropFilter: "blur(3px)" }}
      onMouseDown={(e) => { if (e.target === e.currentTarget) onClose(); }}
    >
      <div
        className="bg-gray-50 rounded-2xl shadow-2xl w-full max-w-2xl mb-10 overflow-hidden"
        style={{ animation: "confirmIn 0.15s ease-out" }}
        onMouseDown={(e) => e.stopPropagation()}
      >
        {/* Header bar */}
        <div className="bg-white border-b border-gray-200 px-5 py-3.5 flex items-start gap-3">
          <Icon icon="mdi:card-text-outline" className="text-gray-400 mt-0.5 shrink-0" width={20} />
          <div className="flex-1 min-w-0">
            {editingTitle ? (
              <input
                ref={titleRef}
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                onBlur={saveTitle}
                onKeyDown={(e) => { if (e.key === "Enter") { e.preventDefault(); saveTitle(); } if (e.key === "Escape") { setTitle(liveCard.title); setEditingTitle(false); } }}
                className="w-full text-base font-bold text-gray-900 bg-transparent border-b-2 border-blue-400 focus:outline-none"
              />
            ) : (
              <h2
                className="text-base font-bold text-gray-900 cursor-pointer hover:text-blue-600 transition-colors"
                onClick={() => setEditingTitle(true)}
              >
                {liveCard.title}
              </h2>
            )}
            <div className="flex items-center gap-1 mt-0.5 text-xs text-gray-400">
              en lista
              <select
                value={liveCard.columnId}
                onChange={(e) => handleMoveToColumn(e.target.value)}
                className="text-xs text-blue-600 font-medium bg-transparent border-none focus:outline-none cursor-pointer"
              >
                {sortedCols.map((c) => (
                  <option key={c.id} value={c.id}>{c.title}</option>
                ))}
              </select>
            </div>
          </div>
          <button onClick={onClose} className="p-1.5 rounded-xl hover:bg-gray-100 text-gray-400 shrink-0">
            <Icon icon="mdi:close" width={18} />
          </button>
        </div>

        {/* Body */}
        <div className="flex flex-col md:flex-row gap-0">
          {/* LEFT — main content */}
          <div className="flex-1 p-5 space-y-5 min-w-0">

            {/* Description */}
          {cfgShow("showDescription") && (
          <section>
            <div className="flex items-center gap-2 mb-2">
              <Icon icon="mdi:text" className="text-gray-400" width={16} />
              <span className="text-sm font-semibold text-gray-700">Descripción</span>
              {!editingDesc && description && (
                <button onClick={() => setEditingDesc(true)} className="ml-auto text-xs text-gray-400 hover:text-gray-700 bg-gray-100 hover:bg-gray-200 px-2 py-0.5 rounded-lg transition-colors">Editar</button>
              )}
            </div>
            {editingDesc ? (
              <div>
                <textarea
                  ref={descRef}
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                  placeholder="Añadir una descripción más detallada…"
                  rows={4}
                  className="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400 resize-none"
                />
                <div className="flex gap-2 mt-1.5">
                  <button onClick={saveDescription} className="px-3 py-1.5 bg-blue-500 hover:bg-blue-600 text-white text-xs font-semibold rounded-xl transition-colors">Guardar</button>
                  <button onClick={() => { setDescription(liveCard.description ?? ""); setEditingDesc(false); }} className="px-3 py-1.5 bg-gray-100 hover:bg-gray-200 text-gray-600 text-xs rounded-xl transition-colors">Cancelar</button>
                </div>
              </div>
            ) : (
              <div
                onClick={() => setEditingDesc(true)}
                className={cn(
                  "min-h-[64px] rounded-xl px-3 py-2.5 text-sm cursor-pointer transition-colors",
                  description ? "text-gray-700 hover:bg-gray-100 bg-white border border-gray-100" : "bg-gray-100 hover:bg-gray-200 text-gray-400 italic"
                )}
              >
                {description || "Añadir una descripción más detallada…"}
              </div>
            )}
          </section>
          )}

          {/* Custom fields */}
          {cfgShow("showCustomFields") && (
            <section>
              <div className="flex items-center gap-2 mb-3">
                <Icon icon="mdi:form-textbox" className="text-gray-400" width={16} />
                <span className="text-sm font-semibold text-gray-700">Campos personalizados</span>
              </div>
              <div className="grid grid-cols-2 gap-3 bg-white border border-gray-100 rounded-xl p-3">
                {fieldDefs.map((def) => {
                  const val = liveCard.customFields?.[def.id];
                  // image and text fields span full width
                  const fullWidth = def.type === "image" || (
                    def.type === "text" &&
                    fieldDefs.filter((f) => f.type === "text").indexOf(def) ===
                    fieldDefs.filter((f) => f.type === "text").length - 1 &&
                    fieldDefs.filter((f) => f.type === "text").length % 2 === 1
                  );
                  return (
                    <Field key={def.id} label={def.label} className={fullWidth ? "col-span-2" : ""}>
                      {def.type === "checkbox" && (
                        <label className="flex items-center gap-2 cursor-pointer">
                          <input
                            type="checkbox"
                            checked={!!val}
                            onChange={(e) => updateFields({ [def.id]: e.target.checked || undefined })}
                            className="w-4 h-4 rounded accent-blue-500"
                          />
                          <span className={cn(
                            "text-sm font-medium",
                            val ? "text-blue-600" : "text-gray-400"
                          )}>
                            {val ? def.label : "No"}
                          </span>
                        </label>
                      )}
                      {def.type === "select" && (
                        <select
                          value={(val as string) ?? ""}
                          onChange={(e) => updateFields({ [def.id]: e.target.value || undefined })}
                          className="field-input"
                        >
                          <option value="">Seleccionar…</option>
                          {def.options?.map((o) => <option key={o}>{o}</option>)}
                        </select>
                      )}
                      {def.type === "text" && (
                        <input
                          type="text"
                          value={textDrafts[def.id] ?? ""}
                          onChange={(e) => setTextDrafts((d) => ({ ...d, [def.id]: e.target.value }))}
                          onBlur={(e) => updateFields({ [def.id]: e.target.value.trim() || undefined })}
                          placeholder={`Añadir ${def.label}…`}
                          className="field-input"
                        />
                      )}
                      {def.type === "image" && (
                        <ImageField
                          fieldId={def.id}
                          value={val as string | undefined}
                          onChange={(next) => updateFields({ [def.id]: next })}
                        />
                      )}
                    </Field>
                  );
                })}
                {fieldDefs.length === 0 && (
                  <p className="col-span-2 text-xs text-gray-400 text-center py-3">
                    No hay campos configurados.
                    <a href="/settings" className="text-blue-500 ml-1 hover:underline">Ir a configuración</a>
                  </p>
                )}
              </div>
            </section>
          )}

          {/* Comments */}
          {cfgShow("showComments") && (
            <section>
              <div className="flex items-center gap-2 mb-3">
                <Icon icon="mdi:comment-outline" className="text-gray-400" width={16} />
                <span className="text-sm font-semibold text-gray-700">Comentarios y Actividad</span>
                <button
                  onClick={() => setShowActivity((v) => !v)}
                  className="ml-auto text-xs text-gray-400 hover:text-gray-700 transition-colors"
                >
                  {showActivity ? "Ocultar actividad" : "Mostrar actividad"}
                </button>
              </div>

              {/* New comment */}
              <div className="flex items-start gap-2.5 mb-4">
                <div className="w-7 h-7 rounded-full bg-blue-500 flex items-center justify-center text-white text-[10px] font-bold shrink-0">
                  {currentUser.initials}
                </div>
                <div className="flex-1">
                  <textarea
                    value={commentText}
                    onChange={(e) => setCommentText(e.target.value)}
                    onKeyDown={(e) => { if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); handleComment(); } }}
                    placeholder="Escribe un comentario…"
                    rows={2}
                    className="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400 resize-none"
                  />
                  {commentText.trim() && (
                    <button
                      onClick={handleComment}
                      className="mt-1.5 px-3 py-1.5 bg-blue-500 hover:bg-blue-600 text-white text-xs font-semibold rounded-xl transition-colors"
                    >
                      Guardar
                    </button>
                  )}
                </div>
              </div>

              {/* Comment list */}
              <div className="space-y-3">
                {sortedComments.map((c) => (
                  <div key={c.id} className="flex items-start gap-2.5">
                    <div className="w-7 h-7 rounded-full bg-slate-400 flex items-center justify-center text-white text-[10px] font-bold shrink-0">
                      {c.authorInitials}
                    </div>
                    <div className="flex-1">
                      <div className="flex items-baseline gap-2">
                        <span className="text-xs font-semibold text-gray-800">{c.author}</span>
                        <span className="text-[10px] text-gray-400">{fmtRelative(c.createdAt)}</span>
                      </div>
                      <p className="text-sm text-gray-700 mt-0.5 bg-white border border-gray-100 rounded-xl px-3 py-2 leading-relaxed">{c.text}</p>
                    </div>
                  </div>
                ))}

                {/* Activity log */}
                {showActivity && sortedActivity.map((e) => (
                  <div key={e.id} className="flex items-start gap-2.5">
                    <div className="w-7 h-7 rounded-full bg-gray-200 flex items-center justify-center shrink-0">
                      <Icon icon="mdi:information-outline" className="text-gray-400" width={13} />
                    </div>
                    <div className="flex-1 pt-1">
                      <span className="text-xs text-gray-600">{e.message}</span>
                      <span className="text-[10px] text-gray-400 ml-2">{fmtRelative(e.createdAt)}</span>
                    </div>
                  </div>
                ))}
              </div>
            </section>
          )}
          </div>

          {/* RIGHT — sidebar actions */}
          <div className="md:w-48 p-4 flex flex-col gap-1 md:border-l border-gray-200">
            <p className="text-[10px] font-semibold text-gray-400 uppercase tracking-wide mb-1 px-1">Acciones</p>

            {/* ASIGNAR */}
            {cfgShow("showAssign") && (
              <>
                <SidebarAction
                  icon="mdi:account-plus-outline"
                  label={liveCard.assignedTo ? `Asignado: ${liveCard.assignedTo}` : "Asignar"}
                  active={expandedAction === "assign"}
                  onClick={() => setExpandedAction((v) => (v === "assign" ? null : "assign"))}
                />
                {expandedAction === "assign" && (
                  <div className="bg-gray-50 border border-gray-200 rounded-xl p-2 space-y-1">
                    {mockUsers.map((u) => (
                      <button
                        key={u.id}
                        onClick={() => {
                          updateCard(card.id, { assignedTo: liveCard.assignedTo === u.name ? undefined : u.name });
                          setExpandedAction(null);
                        }}
                        className={cn(
                          "w-full flex items-center gap-2 px-2 py-1.5 rounded-lg text-xs transition-colors",
                          liveCard.assignedTo === u.name
                            ? "bg-blue-100 text-blue-700 font-semibold"
                            : "hover:bg-gray-100 text-gray-700"
                        )}
                      >
                        <div className="w-6 h-6 rounded-full bg-blue-400 flex items-center justify-center text-white text-[9px] font-bold shrink-0">
                          {u.initials}
                        </div>
                        {u.name}
                        {liveCard.assignedTo === u.name && (
                          <Icon icon="mdi:check" className="ml-auto text-blue-500" width={12} />
                        )}
                      </button>
                    ))}
                    {liveCard.assignedTo && (
                      <button
                        onClick={() => { updateCard(card.id, { assignedTo: undefined }); setExpandedAction(null); }}
                        className="w-full text-xs text-red-400 hover:text-red-600 py-1 text-center transition-colors"
                      >
                        × Quitar asignación
                      </button>
                    )}
                  </div>
                )}
              </>
            )}

            {/* PRIORIDAD */}
            {cfgShow("showPriority") && (
              <>
                <SidebarAction
                  icon="mdi:tag-outline"
                  label="Prioridad"
                  active={expandedAction === "labels"}
                  onClick={() => setExpandedAction((v) => (v === "labels" ? null : "labels"))}
                />
                {expandedAction === "labels" && (
                  <div className="bg-gray-50 border border-gray-200 rounded-xl p-2 space-y-1">
                    {(["HIGH", "NORMAL", "LOW"] as const).map((p) => {
                      const pCfg = {
                        HIGH:   { label: "🔴 Alta / Urgente",  cls: "bg-red-100 text-red-700"       },
                        NORMAL: { label: "🟡 Normal",           cls: "bg-yellow-100 text-yellow-700" },
                        LOW:    { label: "🟢 Baja",             cls: "bg-green-100 text-green-700"   },
                      }[p];
                      return (
                        <button
                          key={p}
                          onClick={() => {
                            updateCard(card.id, { priority: liveCard.priority === p ? undefined : p });
                            setExpandedAction(null);
                          }}
                          className={cn(
                            "w-full flex items-center gap-2 px-2 py-1.5 rounded-lg text-xs font-medium transition-colors",
                            liveCard.priority === p ? pCfg.cls : "hover:bg-gray-100 text-gray-700"
                          )}
                        >
                          {pCfg.label}
                          {liveCard.priority === p && <Icon icon="mdi:check" className="ml-auto" width={12} />}
                        </button>
                      );
                    })}
                  </div>
                )}
              </>
            )}

            {/* CHECKIN — fecha + ¿mañana? toggle (previously split between Prioridad and Fecha) */}
            {cfgShow("showCheckin") && (
              <>
                <SidebarAction
                  icon="mdi:calendar-outline"
                  label={
                    liveCard.checkinDate
                      ? `Checkin: ${new Date(liveCard.checkinDate + "T12:00:00").toLocaleDateString("es-ES", { day: "numeric", month: "short" })}`
                      : liveCard.hasNextDayCheckin
                      ? "Checkin mañana"
                      : "Fecha de checkin"
                  }
                  active={expandedAction === "date"}
                  onClick={() => setExpandedAction((v) => (v === "date" ? null : "date"))}
                />
                {expandedAction === "date" && (
                  <div className="bg-gray-50 border border-gray-200 rounded-xl p-2 space-y-2">
                    {/* "Checkin mañana" toggle — moved here from Prioridad panel */}
                    <button
                      onClick={() => updateCard(card.id, { hasNextDayCheckin: !liveCard.hasNextDayCheckin })}
                      className={cn(
                        "w-full flex items-center gap-2 px-2 py-1.5 rounded-lg text-xs font-medium transition-colors",
                        liveCard.hasNextDayCheckin ? "bg-orange-100 text-orange-700" : "hover:bg-gray-100 text-gray-700"
                      )}
                    >
                      <Icon icon="mdi:calendar-alert" width={13} className="shrink-0" />
                      Checkin mañana
                      {liveCard.hasNextDayCheckin && <Icon icon="mdi:check" className="ml-auto" width={12} />}
                    </button>
                    <div className="h-px bg-gray-200" />
                    <p className="text-[10px] text-gray-400 px-1 font-medium">Fecha exacta de checkin</p>
                    <input
                      type="date"
                      defaultValue={liveCard.checkinDate ?? ""}
                      onChange={(e) => updateCard(card.id, { checkinDate: e.target.value || undefined })}
                      className="w-full text-xs border border-gray-200 rounded-lg px-2 py-1.5 focus:outline-none focus:ring-2 focus:ring-blue-400"
                    />
                    {liveCard.checkinDate && (
                      <button
                        onClick={() => { updateCard(card.id, { checkinDate: undefined }); setExpandedAction(null); }}
                        className="w-full text-xs text-red-400 hover:text-red-600 text-center transition-colors"
                      >
                        × Quitar fecha
                      </button>
                    )}
                  </div>
                )}
              </>
            )}

            <div className="h-px bg-gray-100 my-1" />
            <SidebarAction icon="mdi:archive-arrow-down-outline" label="Archivar" onClick={handleArchive} danger />
          </div>
        </div>
      </div>

      <style>{`
        .field-input {
          width: 100%;
          font-size: 0.8rem;
          border: 1px solid #e5e7eb;
          border-radius: 0.5rem;
          padding: 0.3rem 0.5rem;
          background: white;
          outline: none;
        }
        .field-input:focus { border-color: #60a5fa; }
      `}</style>
    </div>
  );
}

function Field({ label, children, className }: { label: string; children: React.ReactNode; className?: string }) {
  return (
    <div className={cn("flex flex-col gap-1", className)}>
      <label className="text-[10px] font-semibold text-gray-500 uppercase tracking-wide">{label}</label>
      {children}
    </div>
  );
}

function SidebarAction({
  icon, label, onClick, danger = false, active = false,
}: { icon: string; label: string; onClick: () => void; danger?: boolean; active?: boolean }) {
  return (
    <button
      onClick={onClick}
      className={cn(
        "flex items-center gap-2 px-3 py-2 rounded-xl text-xs font-medium w-full text-left transition-colors",
        danger
          ? "bg-red-50 text-red-600 hover:bg-red-100"
          : active
          ? "bg-blue-100 text-blue-700"
          : "bg-gray-100 text-gray-700 hover:bg-gray-200"
      )}
    >
      <Icon icon={icon} width={14} className="shrink-0" />
      <span className="truncate">{label}</span>
    </button>
  );
}

/* ── ImageField ──────────────────────────────────────────────────────────────
   Stores images as JSON array of data-URLs in the customFields string value.
   Each image is resized client-side to max 1024px before storing as JPEG.
*/
const MAX_PX = 1024;
const JPEG_Q = 0.78;

function resizeAndEncode(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const img = new Image();
    const url = URL.createObjectURL(file);
    img.onload = () => {
      URL.revokeObjectURL(url);
      const scale = Math.min(1, MAX_PX / Math.max(img.width, img.height));
      const w = Math.round(img.width * scale);
      const h = Math.round(img.height * scale);
      const canvas = document.createElement("canvas");
      canvas.width = w; canvas.height = h;
      canvas.getContext("2d")!.drawImage(img, 0, 0, w, h);
      resolve(canvas.toDataURL("image/jpeg", JPEG_Q));
    };
    img.onerror = reject;
    img.src = url;
  });
}

function ImageField({
  fieldId: _fieldId, value, onChange,
}: { fieldId: string; value: string | undefined; onChange: (next: string | undefined) => void }) {
  const images: string[] = value ? (() => { try { return JSON.parse(value); } catch { return []; } })() : [];
  const [lightbox, setLightbox] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleFiles(files: FileList | null) {
    if (!files || files.length === 0) return;
    setLoading(true);
    try {
      const encoded = await Promise.all(Array.from(files).map(resizeAndEncode));
      const next = [...images, ...encoded];
      onChange(JSON.stringify(next));
    } finally {
      setLoading(false);
    }
  }

  function removeImage(idx: number) {
    const next = images.filter((_, i) => i !== idx);
    onChange(next.length > 0 ? JSON.stringify(next) : undefined);
  }

  return (
    <>
      <div className="flex flex-wrap gap-2">
        {images.map((src, i) => (
          <div key={i} className="relative group w-20 h-20 rounded-xl overflow-hidden border border-gray-200 shrink-0">
            <img
              src={src}
              alt=""
              className="w-full h-full object-cover cursor-pointer"
              onClick={() => setLightbox(src)}
            />
            <button
              onClick={(e) => { e.stopPropagation(); removeImage(i); }}
              className="absolute top-0.5 right-0.5 w-5 h-5 rounded-full bg-black/60 text-white flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity"
            >
              <Icon icon="mdi:close" width={11} />
            </button>
          </div>
        ))}
        {/* Upload button */}
        <label className={cn(
          "w-20 h-20 rounded-xl border-2 border-dashed border-gray-300 flex flex-col items-center justify-center gap-1 cursor-pointer hover:border-blue-400 hover:bg-blue-50 transition-colors shrink-0",
          loading && "opacity-50 pointer-events-none"
        )}>
          <Icon icon={loading ? "mdi:loading" : "mdi:camera-plus-outline"} className={cn("text-gray-400", loading && "animate-spin")} width={22} />
          <span className="text-[9px] text-gray-400 font-medium">{loading ? "Cargando…" : "Añadir"}</span>
          <input
            type="file"
            accept="image/*"
            multiple
            className="hidden"
            onChange={(e) => handleFiles(e.target.files)}
            // allow re-selecting same file
            onClick={(e) => { (e.target as HTMLInputElement).value = ""; }}
          />
        </label>
      </div>

      {/* Lightbox */}
      {lightbox && (
        <div
          className="fixed inset-0 z-[100] bg-black/80 flex items-center justify-center p-4"
          onClick={() => setLightbox(null)}
        >
          <img
            src={lightbox}
            alt=""
            className="max-w-full max-h-full rounded-2xl shadow-2xl object-contain"
            onClick={(e) => e.stopPropagation()}
          />
          <button
            onClick={() => setLightbox(null)}
            className="absolute top-4 right-4 w-9 h-9 rounded-full bg-white/20 text-white flex items-center justify-center hover:bg-white/30 transition-colors"
          >
            <Icon icon="mdi:close" width={20} />
          </button>
        </div>
      )}
    </>
  );
}
