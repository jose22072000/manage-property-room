import { create } from "zustand";
import { persist } from "zustand/middleware";
import type { MockUser } from "@/types/domain";
import { mockUsers } from "@/mocks/mockUsers";

type UserState = {
  currentUser: MockUser;
  setCurrentUser: (user: MockUser) => void;
};

export const useUserStore = create<UserState>()(
  persist(
    (set) => ({
      currentUser: mockUsers[0],
      setCurrentUser: (user) => set({ currentUser: user }),
    }),
    { name: "pmr-user-v1" }
  )
);
