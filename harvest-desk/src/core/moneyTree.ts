/**
 * Money Tree is not random: the game draws each chop from a fixed sequence
 * (events/landExpansion/chop.ts → getReward, lib/prng.ts). A chop pops when
 *   prng(farmId, KNOWN_IDS[tree], "<Kind> Tree Chopped" before the chop, "Money Tree") × 100 < rank
 * and pays 200 coins × the tree multiplier. Knowing the counters, every past and future pop is known.
 */

export const MT_KINDS = [
  { kind: "Basic Tree", tree: "Tree", itemId: 618 },
  { kind: "Ancient Tree", tree: "Ancient Tree", itemId: 2702 },
  { kind: "Sacred Tree", tree: "Sacred Tree", itemId: 2703 },
] as const;
export type MtKind = (typeof MT_KINDS)[number]["kind"];
export const MT_COINS = 200;
/** Days of past chops the revenue counts. */
export const MT_WINDOW = 30;

const hash = (s: string) => { let h = 0; for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) >>> 0; return h; };
const NAME = hash("Money Tree");

/** lib/prng.ts, MurmurHash3 style, between 0 and 1. */
export function prng(farmId: number, itemId: number, counter: number): number {
  const seed = (Math.imul(farmId, 0x85ebca6b) + Math.imul(itemId, 0x9e3779b9) + Math.imul(counter, 0x27d4eb2f) + Math.imul(NAME, 0x517cc1b7)) >>> 0;
  let t = seed ^ (seed >>> 16);
  t = Math.imul(t, 0x21f0aaad);
  t = t ^ (t >>> 15);
  t = Math.imul(t, 0x735a2d97);
  return ((t ^ (t >>> 15)) >>> 0) / 2 ** 32;
}

/** Does the chop made when the counter reads `counter` pop at this rank (1 to 3)? */
export const pops = (farmId: number, itemId: number, counter: number, rank: number) => rank > 0 && prng(farmId, itemId, counter) * 100 < rank;

/** Pops among the chops numbered from `from` (included) to `to` (excluded). */
export function popsBetween(farmId: number, itemId: number, from: number, to: number, rank: number): number[] {
  const out: number[] = [];
  for (let c = Math.max(0, Math.floor(from)); c < Math.floor(to); c++) if (pops(farmId, itemId, c, rank)) out.push(c);
  return out;
}

export interface KindForecast {
  kind: MtKind;
  mult: number;
  /** Chops per day measured. */
  perDay: number;
  counter: number;
  /** Chops left before the next pop, and roughly when, in days. */
  nextIn: number | null;
  nextDays: number | null;
  past: { pops: number; coins: number; expected: number };
  week: { pops: number; coins: number };
  month: { pops: number; coins: number; expected: number };
}

/**
 * Past 30 days and next 7 and 30 days of each tree kind, from the counters and the chop pace.
 * `mults`: multiplier of each tree kind on the farm.
 */
export function forecast(farmId: number, activity: Record<string, number>, rates: Record<string, number>, mults: Record<string, number>, rank: number): KindForecast[] {
  return MT_KINDS.map(({ kind, itemId }) => {
    const counter = Number(activity[`${kind} Chopped`] ?? 0), perDay = rates[`${kind} Chopped`] ?? 0, mult = mults[kind] ?? 1;
    const each = MT_COINS * mult, chance = rank / 100;
    const span = (days: number) => Math.round(perDay * days);
    const back = popsBetween(farmId, itemId, counter - span(MT_WINDOW), counter, rank).length;
    const week = popsBetween(farmId, itemId, counter, counter + span(7), rank).length;
    const month = popsBetween(farmId, itemId, counter, counter + span(30), rank).length;
    let nextIn: number | null = null;
    if (rank > 0) for (let c = counter; c < counter + 5000; c++) if (pops(farmId, itemId, c, rank)) { nextIn = c - counter + 1; break; }
    return {
      kind, mult, perDay, counter, nextIn, nextDays: nextIn !== null && perDay > 0 ? nextIn / perDay : null,
      past: { pops: back, coins: back * each, expected: span(MT_WINDOW) * chance * each },
      week: { pops: week, coins: week * each },
      month: { pops: month, coins: month * each, expected: span(30) * chance * each },
    };
  });
}

/** Coins per day Money Tree really paid on one tree kind over the last 30 days of chops. */
export function realCoinsPerDay(farmId: number, kind: string, counter: number, perDay: number, mult: number, rank: number): number {
  const k = MT_KINDS.find((x) => x.kind === kind);
  if (!k || perDay <= 0) return 0;
  const n = popsBetween(farmId, k.itemId, counter - Math.round(perDay * MT_WINDOW), counter, rank).length;
  return (n * MT_COINS * mult) / MT_WINDOW;
}
