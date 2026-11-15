// Plain-text labels of the timers, shared by the desktop widget and the iOS app (no React here).
import type { TimerGroup } from "../../core/timers";
import { frCrop } from "../format";

const NAMES: Record<string, string> = {
  Tree: "arbre", "Ancient Tree": "arbre ancien", "Sacred Tree": "arbre sacré",
  "Stone Rock": "pierre", "Fused Stone Rock": "pierre fusionnée", "Reinforced Stone Rock": "pierre renforcée",
  "Iron Rock": "fer", "Refined Iron Rock": "fer raffiné", "Tempered Iron Rock": "fer trempé",
  "Gold Rock": "or", "Pure Gold Rock": "or pur", "Prime Gold Rock": "or suprême",
  "Crimstone Rock": "crimstone", "Sunstone Rock": "sunstone",
  Chicken: "poule", Cow: "vache", Sheep: "mouton", Pig: "cochon",
  "Réserve de pétrole": "réserve", Ruche: "ruche", "Ruche pleine": "ruche pleine",
  "Compost Bin": "Compost Bin", "Crab Pot": "casier", "Mariner Pot": "grand casier",
};

/** "Rice ×3, Grape" → "Riz ×3, raisin". */
export function frWhat(what: string): string {
  const s = what.split(", ").map((part) => {
    const m = /^(.*?)( ×\d+)?$/.exec(part)!;
    return (NAMES[m[1]] ?? frCrop(m[1])) + (m[2] ?? "");
  }).join(", ");
  return s.charAt(0).toUpperCase() + s.slice(1);
}

const COUNT_NOUN: Partial<Record<TimerGroup, [string, string]>> = {
  chickens: ["poule", "poules"], cows: ["vache", "vaches"], sheep: ["mouton", "moutons"], pigs: ["cochon", "cochons"],
  honey: ["ruche", "ruches"], oil: ["réserve", "réserves"], trees: ["arbre", "arbres"],
};

/** The line under a group's name: what grows there, or a plain count when it is all the same thing. */
export function subLine(key: TimerGroup, what: string, total: number): string {
  const noun = COUNT_NOUN[key];
  if (noun && key !== "trees") return `${total} ${total > 1 ? noun[1] : noun[0]}`;
  return what ? frWhat(what) : "";
}

/** "14:20", or "demain 07:10", or "sam. 09:00". */
export function clock(at: number, now: number): string {
  const d = new Date(at), n = new Date(now);
  const hm = d.toLocaleTimeString("fr-FR", { hour: "2-digit", minute: "2-digit" });
  const days = Math.round((new Date(d.toDateString()).getTime() - new Date(n.toDateString()).getTime()) / 86_400_000);
  if (days <= 0) return hm;
  if (days === 1) return `demain ${hm}`;
  return `${d.toLocaleDateString("fr-FR", { weekday: "short" })} ${hm}`;
}
