import type { Category, CategoryKey, Line, Report } from "./engine";

/**
 * "Ce que tu encaisses" view of a report. What the farm makes and uses itself (wood and stone for
 * pickaxes, wheat and barley for the animals, iron and leather for oil drills…) is never sold, so it
 * is taken out of the line that makes it and out of the cost of the line that uses it.
 * Only the part covered by the farm's own production moves; what you buy stays a cost.
 * The total does not change.
 */
export function internalize(report: Report, prices: Record<string, number>): Report {
  const made: Record<string, number> = {}, used: Record<string, number> = {};
  const all = Object.values(report.categories).flatMap((c) => c.lines);
  for (const l of all) {
    for (const [i, q] of Object.entries(l.made ?? {})) made[i] = (made[i] ?? 0) + q;
    for (const [i, q] of Object.entries(l.uses ?? {})) used[i] = (used[i] ?? 0) + q;
  }
  // Share of each item that stays on the farm, seen from the maker and from the user.
  const kept: Record<string, number> = {};
  for (const i of Object.keys(used)) if (made[i]) kept[i] = Math.min(made[i], used[i]);

  const move = (l: Line): Line => {
    let gross = l.gross, cost = l.cost;
    for (const [i, q] of Object.entries(l.made ?? {})) if (kept[i]) gross -= (q / made[i]) * kept[i] * (prices[i] ?? 0);
    for (const [i, q] of Object.entries(l.uses ?? {})) if (kept[i]) cost -= (q / used[i]) * kept[i] * (prices[i] ?? 0);
    return { ...l, gross, cost, net: gross - cost };
  };

  const categories = Object.fromEntries(Object.entries(report.categories).map(([k, c]) => {
    const lines = c.lines.map(move);
    const cat: Category = {
      key: c.key, lines,
      gross: lines.reduce((a, l) => a + l.gross, 0),
      cost: lines.reduce((a, l) => a + l.cost, 0),
      net: lines.reduce((a, l) => a + l.net, 0),
    };
    return [k, cat];
  })) as Record<CategoryKey, Category>;
  const cats = Object.values(categories);
  return {
    categories,
    net: cats.reduce((a, c) => a + c.net, 0),
    gross: cats.reduce((a, c) => a + c.gross, 0),
    cost: cats.reduce((a, c) => a + c.cost, 0),
  };
}

/** Items the farm uses itself, per day: how much it makes and how much it uses. */
export function selfUse(report: Report): { item: string; made: number; used: number }[] {
  const made: Record<string, number> = {}, used: Record<string, number> = {};
  for (const l of Object.values(report.categories).flatMap((c) => c.lines)) {
    for (const [i, q] of Object.entries(l.made ?? {})) made[i] = (made[i] ?? 0) + q;
    for (const [i, q] of Object.entries(l.uses ?? {})) used[i] = (used[i] ?? 0) + q;
  }
  return Object.keys(used).filter((i) => made[i]).map((item) => ({ item, made: made[item], used: used[item] }));
}
