export function ellipsify(s: string, len: number = 4) {
  if (s.length <= len) return s;
  return `${s.slice(0, len + 2)}...${s.slice(-1 * len)}`;
}