import { useUserStore } from "@/store/userStore";
import { mockUsers } from "@/mocks/mockUsers";

export function UserSelector() {
  const currentUser    = useUserStore((s) => s.currentUser);
  const setCurrentUser = useUserStore((s) => s.setCurrentUser);

  return (
    <div className="flex items-center gap-2">
      <div className="w-7 h-7 rounded-full bg-blue-500 flex items-center justify-center text-white text-[11px] font-bold shrink-0 select-none">
        {currentUser.initials}
      </div>
      <select
        value={currentUser.id}
        onChange={(e) => {
          const user = mockUsers.find((u) => u.id === e.target.value);
          if (user) setCurrentUser(user);
        }}
        className="text-sm font-medium text-gray-700 bg-transparent border-none cursor-pointer focus:outline-none max-w-[90px] truncate"
      >
        {mockUsers.map((u) => (
          <option key={u.id} value={u.id}>{u.name}</option>
        ))}
      </select>
    </div>
  );
}
