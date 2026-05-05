import { create } from "zustand";

export type ConfirmOpts = {
  message: string;
  description?: string;
  confirmLabel?: string;
  cancelLabel?: string;
  danger?: boolean;
};

type ConfirmState = ConfirmOpts & {
  open: boolean;
  resolve: ((ok: boolean) => void) | null;
  ask: (opts: ConfirmOpts) => Promise<boolean>;
  respond: (ok: boolean) => void;
};

export const useConfirmStore = create<ConfirmState>()((set, get) => ({
  open: false,
  message: "",
  resolve: null,

  ask(opts) {
    return new Promise<boolean>((resolve) => {
      set({ open: true, ...opts, resolve });
    });
  },

  respond(ok) {
    const { resolve } = get();
    set({ open: false, resolve: null });
    resolve?.(ok);
  },
}));
