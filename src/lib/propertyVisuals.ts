// Deterministic gradient per property id
const GRADIENTS = [
  "bg-gradient-to-br from-blue-500 to-indigo-700",
  "bg-gradient-to-br from-emerald-500 to-teal-700",
  "bg-gradient-to-br from-orange-500 to-red-600",
  "bg-gradient-to-br from-purple-500 to-pink-700",
  "bg-gradient-to-br from-amber-500 to-orange-700",
  "bg-gradient-to-br from-cyan-500 to-blue-700",
  "bg-gradient-to-br from-rose-500 to-red-700",
  "bg-gradient-to-br from-lime-500 to-green-700",
  "bg-gradient-to-br from-violet-500 to-purple-700",
  "bg-gradient-to-br from-sky-500 to-indigo-600",
];

function hashStr(s: string): number {
  let h = 0;
  for (let i = 0; i < s.length; i++) h = ((h << 5) - h + s.charCodeAt(i)) | 0;
  return Math.abs(h);
}

export function getPropertyGradient(id: string): string {
  return GRADIENTS[hashStr(id) % GRADIENTS.length];
}
