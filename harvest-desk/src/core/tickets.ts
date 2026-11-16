import chapters from "./data/chapters.json";
import { currentChapter, ticketsFor, utcDay, type Chapter } from "./deliveries";
import type { Farm } from "./farm";

/**
 * Chapter tickets you can still earn before the chapter ends, source by source.
 * Rules from the game code: deliver.ts (one ticket delivery per NPC per day, x2 on the
 * calendar's double delivery days), sellBounty.ts and claimBountyBonus.ts (weekly bounty
 * board and its bonus), completeNPCChore.ts (weekly chore board) and tracks.ts (chapter track).
 */

const DAY = 86_400_000, WEEK = 7 * DAY;
const TICKET_NAME = chapters.ticketName as Record<string, string>;
const TICKET_NPCS = Object.keys(chapters.tickets);
const BOUNTY_BONUS = chapters.bountyBonus as number;
const TRACK = chapters.track as Record<string, { free: number; premium: number }>;

export interface Source {
  id: "deliveries" | "extra" | "bounties" | "chores" | "track";
  label: string;
  /** Tickets still to earn before the chapter ends. */
  total: number;
  detail: string;
}

export interface TicketPlan {
  chapter: Chapter;
  ticket: string;
  /** Tickets earned this chapter that the API reports (deliveries and bounties only). */
  seen: number;
  daysLeft: number;
  doubles: { known: number; estimated: number };
  /** Tickets per day from the chosen deliveries. */
  perDay: number;
  /** The ticket deliveries left out, with what each would add before the end. */
  extras: { npc: string; per: number; total: number }[];
  sources: Source[];
}

/** Monday 00:00 UTC resets strictly after `now` and before `end`. */
function weekResets(now: number, end: number): number {
  const d = new Date(utcDay(now));
  let t = utcDay(now) + (((8 - d.getUTCDay()) % 7) || 7) * DAY;
  let n = 0;
  for (; t < end; t += WEEK) n++;
  return n;
}

/** `off`: the NPCs whose ticket delivery you skip (Tywin by default). */
export function ticketPlan(farm: Farm, now: number, off: Set<string> = new Set(["tywin"])): TicketPlan | null {
  const chapter = currentChapter(now);
  if (!chapter) return null;
  const ticket = TICKET_NAME[chapter.name];
  if (!ticket) return null;
  const today = utcDay(now);
  const from = Math.max(today, chapter.ticketsFrom);
  const days = Math.max(0, Math.round((chapter.end - from) / DAY));

  // Double delivery days: the calendar shows the next few weeks, about one a week after that.
  const dates = (farm.calendar?.dates ?? []).map((d) => ({ ...d, t: Date.parse(d.date + "T00:00:00Z") }));
  const doubleDays = dates.filter((d) => d.name === "doubleDelivery" && d.t >= from && d.t < chapter.end).map((d) => d.t);
  const horizon = Math.max(today, ...dates.map((d) => d.t));
  const estimated = Math.max(0, Math.round((chapter.end - Math.max(from, horizon + DAY)) / WEEK));

  const doneToday = (npc: string) => utcDay(farm.npcs?.[npc]?.deliveryCompletedAt ?? 0) === today;
  const deliveries = (npc: string) => {
    const t = ticketsFor(npc, farm, now, chapter.name);
    const n = days - (doneToday(npc) && from === today ? 1 : 0);
    const dbl = doubleDays.filter((d) => !(d === today && doneToday(npc))).length + estimated;
    return { per: t, total: t * Math.max(0, n + dbl) };
  };
  const others = TICKET_NPCS.filter((n) => !off.has(n)).map(deliveries);
  const extras = TICKET_NPCS.filter((n) => off.has(n)).map((npc) => ({ npc, ...deliveries(npc) })).filter((x) => x.per > 0);
  const perDay = others.reduce((a, x) => a + x.per, 0);

  // Bounty board: what is left this week, then a full board and its bonus each Monday.
  const reqs = farm.bounties?.requests ?? [];
  const done = new Set((farm.bounties?.completed ?? []).map((c) => c.id));
  const capsOf = (r: { items?: Record<string, number> }) => r.items?.[ticket] ?? 0;
  const board = reqs.reduce((a, r) => a + capsOf(r), 0);
  const boardLeft = reqs.filter((r) => !done.has(r.id)).reduce((a, r) => a + capsOf(r), 0);
  const weekStart = today - (((new Date(today).getUTCDay() + 6) % 7) * DAY);
  const bonusLeft = (farm.bounties?.bonusClaimedAt ?? 0) >= weekStart ? 0 : BOUNTY_BONUS;
  const resets = weekResets(now, chapter.end);

  const chores = Object.values(farm.choreBoard?.chores ?? {});
  const choreWeek = chores.reduce((a, c) => a + (c.reward?.items?.[ticket] ?? 0), 0);
  const choreLeft = chores.filter((c) => !c.completedAt).reduce((a, c) => a + (c.reward?.items?.[ticket] ?? 0), 0);

  const track = TRACK[chapter.name] ?? { free: 0, premium: 0 };
  const banner = Number(farm.inventory?.[`${chapter.name} Banner`] ?? 0) > 0 || Number(farm.inventory?.["Lifetime Farmer Banner"] ?? 0) > 0;

  const sources: Source[] = [
    { id: "deliveries", label: extras.length ? "Livraisons choisies" : "Toutes les livraisons à tickets", total: others.reduce((a, x) => a + x.total, 0),
      detail: `${perDay} par jour × ${days} jours, plus ${doubleDays.length + estimated} jours de double livraison` },
    { id: "bounties", label: "Bounties et bonus de la semaine", total: boardLeft + bonusLeft + resets * (board + BOUNTY_BONUS),
      detail: `${board} par tableau + ${BOUNTY_BONUS} de bonus, ${resets} nouveaux tableaux d'ici la fin` },
    { id: "chores", label: "Chores", total: choreLeft + resets * choreWeek,
      detail: `${choreWeek} par semaine` },
    { id: "track", label: banner ? "Track du chapitre (gratuit + Banner)" : "Track du chapitre (gratuit)",
      total: 0, detail: `jusqu'à ${track.free + (banner ? track.premium : 0)} sur tout le chapitre, déjà en partie pris : non compté` },
    { id: "extra", label: "Livraisons non cochées", total: extras.reduce((a, x) => a + x.total, 0),
      detail: `${extras.reduce((a, x) => a + x.per, 0)} par jour si tu les ajoutes` },
  ];

  return {
    chapter, ticket, seen: farm.farmActivity?.[`${ticket} Collected`] ?? 0, daysLeft: (chapter.end - now) / DAY,
    doubles: { known: doubleDays.length, estimated }, perDay, extras, sources,
  };
}

export type Verdict = "easy" | "tight" | "add" | "no";

/**
 * How a goal compares with what is left to earn with your chosen deliveries, and with all of them.
 * When the choice falls short, `toAdd` lists the skipped deliveries to add, cheapest ticket first
 * (`costPer`: FLOWER per ticket for each NPC).
 */
export function verdict(plan: TicketPlan, owned: number, goal: number, costPer: Record<string, number> = {}) {
  const need = Math.max(0, goal - owned);
  const without = plan.sources.filter((s) => s.id !== "extra").reduce((a, s) => a + s.total, 0);
  const extra = plan.sources.find((s) => s.id === "extra")!.total;
  const toAdd: string[] = [];
  let sum = without;
  for (const x of [...plan.extras].sort((a, b) => (costPer[a.npc] ?? Infinity) - (costPer[b.npc] ?? Infinity) || b.per - a.per)) {
    if (sum >= need) break;
    toAdd.push(x.npc);
    sum += x.total;
  }
  const v: Verdict = without >= need * 1.1 ? "easy" : without >= need ? "tight" : without + extra >= need ? "add" : "no";
  return { need, without, withAll: without + extra, verdict: v, missing: Math.max(0, need - without), toAdd: v === "add" ? toAdd : [] };
}
