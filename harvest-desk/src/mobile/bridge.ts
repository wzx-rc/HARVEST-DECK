/**
 * The desktop app's calculations, packed for the iOS app (JavaScriptCore).
 * Built into ios/HarvestDesk/Resources/core.js by `npm run mobile:core`; exposes `globalThis.HD`.
 * Every function takes and returns JSON strings, so Swift only handles plain text.
 */
import { dailyRates, Engine, type Market } from "../core/engine";
import type { Farm } from "../core/farm";
import { farmValue } from "../core/farmValue";
import { parseMarket } from "../core/market";
import { mergeRemoteReads, parseRemoteReads, procStats, TREE_FR, treeMults } from "../core/procs";
import { farmTimers, summarize, TIMER_FAMILIES, TIMER_GROUPS } from "../core/timers";
import { COINS_PER_FLOWER } from "../core/gameData";
import { subLine } from "../ui/widget/timerText";

const j = <T>(s: string): T => JSON.parse(s) as T;
const farmOf = (s: string): Farm => { const v = j<any>(s); return (v?.farm ?? v) as Farm; };

/** Timers of the farm: raw list (the widget recomputes it over time) and today's groups. */
function timers(farmJson: string, now: number): string {
  const farm = farmOf(farmJson);
  const list = farmTimers(farm as any);
  const groups = summarize(list, now).map((g) => ({ ...g, sub: subLine(g.key, g.what, g.total) }));
  return JSON.stringify({ at: now, timers: list, groups, meta: TIMER_GROUPS, families: TIMER_FAMILIES });
}

function market(rawJson: string): string {
  return JSON.stringify(parseMarket(j(rawJson)));
}

function value(farmJson: string, marketJson: string): string {
  const v = farmValue(farmOf(farmJson), j<Market>(marketJson));
  return JSON.stringify({
    total: v.total, netIfSold: v.netIfSold, unpriced: v.unpriced.length,
    groups: v.groups.map((g) => ({ key: g.key, label: g.label, total: g.total, items: g.items.slice(0, 12) })),
  });
}

/** Money Tree pops from the GitHub readings (reads.jsonl). */
function procs(readsText: string, farmJson: string): string {
  const farm = farmOf(farmJson) as any;
  const log = mergeRemoteReads(null, parseRemoteReads(readsText));
  if (!log) return JSON.stringify(null);
  const rank = Number(farm?.bumpkin?.skills?.["Money Tree"] ?? 0);
  const s = procStats(log, rank, treeMults(farm));
  return JSON.stringify({
    since: log.since, rank, stats: s, treeNames: TREE_FR, coinsPerFlower: COINS_PER_FLOWER,
    events: log.events.filter((e) => e.boost === "Money Tree").slice(-40).reverse(),
  });
}

/** Net per day by category, from counter snapshots ({at, farmActivity}[] oldest first). */
function revenue(farmJson: string, marketJson: string, snapsJson: string): string {
  const snaps = j<{ at: number; farmActivity: Record<string, number> }[]>(snapsJson);
  const { rates, days } = dailyRates(snaps);
  const m = j<Market>(marketJson);
  const r = new Engine(farmOf(farmJson), rates, m).report();
  return JSON.stringify({
    days, usd: m.flowerUsd, net: r.net, gross: r.gross, cost: r.cost,
    categories: Object.values(r.categories).map((c) => ({
      key: c.key, net: c.net, gross: c.gross, cost: c.cost,
      lines: [...c.lines].sort((a, b) => b.net - a.net).slice(0, 8),
    })),
  });
}

(globalThis as any).HD = { timers, market, value, procs, revenue, version: 1 };
