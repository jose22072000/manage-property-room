import { useRef, useState, useEffect } from "react";
import { Icon } from "@iconify/react";

type Props = {
  onAdd: (title: string) => void;
  onCancel: () => void;
};

export function AddListInline({ onAdd, onCancel }: Props) {
  const [title, setTitle] = useState("");
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => { inputRef.current?.focus(); }, []);

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    const t = title.trim();
    if (t) onAdd(t);
    onCancel();
  }

  return (
    <form
      onSubmit={handleSubmit}
      className="bg-white border border-gray-200 rounded-2xl shadow-sm p-3 w-72 shrink-0 flex flex-col gap-2"
    >
      <input
        ref={inputRef}
        type="text"
        value={title}
        onChange={(e) => setTitle(e.target.value)}
        onKeyDown={(e) => { if (e.key === "Escape") onCancel(); }}
        placeholder="Introduce el nombre de la lista…"
        className="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400"
      />
      <div className="flex items-center gap-2">
        <button
          type="submit"
          disabled={!title.trim()}
          className="px-3 py-1.5 bg-blue-500 hover:bg-blue-600 disabled:opacity-40 text-white text-sm font-semibold rounded-xl transition-colors"
        >
          Añadir lista
        </button>
        <button
          type="button"
          onClick={onCancel}
          className="p-1.5 text-gray-400 hover:text-gray-700 hover:bg-gray-100 rounded-xl transition-colors"
        >
          <Icon icon="mdi:close" width={18} />
        </button>
      </div>
    </form>
  );
}
