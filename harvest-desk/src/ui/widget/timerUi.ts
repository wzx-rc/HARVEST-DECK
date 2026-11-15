import { useCallback, useEffect, useState } from "react";
import { TIMER_FAMILIES, TIMER_GROUPS, type TimerGroup } from "../../core/timers";
import type { WidgetConfig } from "../../shared/types";
import { bridge } from "../useAppState";

export const GROUP_COLOR: Record<TimerGroup, string> = {
  crops: "var(--wheat)", greenhouse: "var(--glass)", machine: "var(--wheat)", fruits: "var(--fruit)", flowers: "var(--fruit)",
  trees: "var(--wood)", stone: "var(--ore)", iron: "var(--ore)", gold: "var(--gold)", crimstone: "var(--loss)", sunstone: "var(--gold)",
  oil: "var(--sky)", chickens: "var(--sheep)", cows: "var(--sheep)", sheep: "var(--sheep)", pigs: "var(--sheep)", honey: "var(--honey)",
  compost: "var(--wood)", cooking: "var(--gold)", aging: "var(--dim)", crabs: "var(--sky)", power: "var(--gold)",
};

export { clock, frWhat, subLine } from "./timerText";

export const WIDGET_DEFAULT: WidgetConfig = {
  groups: ["crops", "greenhouse", "trees", "stone", "iron", "gold", "sheep", "cooking", "power"],
  notify: [], open: false, opacity: 0.92, onTop: false,
  order: "auto", familyOrder: TIMER_FAMILIES.map((f) => f.key), groupOrder: TIMER_GROUPS.map((g) => g.key),
};

/** The widget settings, kept by the desktop app (or in this browser for the demo). */
export function useWidgetConfig() {
  const [cfg, setCfg] = useState<WidgetConfig>(() => {
    if (bridge()) return WIDGET_DEFAULT;
    try { return { ...WIDGET_DEFAULT, ...JSON.parse(localStorage.getItem("hd.widget") ?? "{}") }; } catch { return WIDGET_DEFAULT; }
  });
  useEffect(() => {
    const b = bridge();
    if (!b) return;
    b.getWidget().then(setCfg);
    return b.onWidget(setCfg);
  }, []);
  const update = useCallback((patch: Partial<WidgetConfig>) => {
    const b = bridge();
    if (b) { b.setWidget(patch).then(setCfg); return; }
    setCfg((c) => {
      const next = { ...c, ...patch };
      try { localStorage.setItem("hd.widget", JSON.stringify(next)); } catch { /* storage unavailable */ }
      return next;
    });
  }, []);
  return [cfg, update] as const;
}

/** Re-renders every `ms` so countdowns move. */
export function useNow(ms = 15_000) {
  const [now, setNow] = useState(Date.now());
  useEffect(() => { const t = setInterval(() => setNow(Date.now()), ms); return () => clearInterval(t); }, [ms]);
  return now;
}
