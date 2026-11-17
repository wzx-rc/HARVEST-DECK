import { useMemo } from "react";
import { dailyRates } from "../../core/engine";
import { dailyPops, forecast, MT_WINDOW, type KindForecast } from "../../core/moneyTree";
import { usePersisted } from "../usePersisted";
import { procStats, TREE_FR, treeMults, type ProcEvent } from "../../core/procs";
import { COINS_PER_FLOWER } from "../../core/gameData";
import type { AppState } from "../../shared/types";
import { Icon } from "../icons";
import { dayLabel, fmt, MONTH, nf, usd } from "../format";

const SKILL = "Money Tree";

/** Money Tree pops seen between farm readings, against what the skill should give. */
export function ProcsView({ state }: { state: AppState }) {
  const farm = state.farm as any, log = state.procs;
  const rank = Number(farm?.bumpkin?.skills?.[SKILL] ?? 0);
  const rate = state.market?.flowerUsd ?? 0;
  const s = useMemo(() => (log && farm ? procStats(log, rank, treeMults(farm)) : null), [log, farm, rank]);
  const toUsd = (coins: number) => (coins / COINS_PER_FLOWER) * rate;

  // With the farm id, the days come from the game's draws replayed on the counter readings: exact,
  // whatever the gaps between readings. Without it, from the pops seen between close readings.
  const replay = useMemo(() => (farm && state.farmId ? dailyPops(state.farmId, state.snapshots, treeMults(farm), rank) : null), [farm, state.farmId, state.snapshots, rank]);
  const draws = farm && state.farmId ? <Draws state={state} rank={rank} /> : null;
  if (!log || !s) {
    return draws ?? (
      <section className="card">
        <h2>Pops Money Tree</h2>
        <p className="hint">Le suivi démarre à la prochaine lecture de ta ferme. L'app note chaque pop qu'elle voit, toutes les 10 minutes.</p>
      </section>
    );
  }

  const days = Math.max(s.hours / 24, 1 / 24);
  // Real gain per day: coins per chop while followed × every chop of the day (app open or not).
  const perDay = s.chops && s.chopsPerDay ? (s.coins / s.chops) * s.chopsPerDay : s.coins / days;
  const expectedPerDay = s.chops && s.chopsPerDay ? (s.expectedCoins / s.chops) * s.chopsPerDay : s.expectedCoins / days;
  const luck = s.expectedPops ? s.pops / s.expectedPops : 0;
  const last = [...log.events].filter((e) => e.boost === SKILL).reverse();
  const shownDays = (replay ?? s.perDay).slice(-14);
  const maxBar = Math.max(...shownDays.map((d) => Math.max(d.coins, d.expectedCoins)), 1);

  return (
    <>
      {draws}
      {replay ? null : <div className="kpis">
        <div className="kpi">
          <div className="l">Pops relevés</div>
          <div className="v gold">{s.pops}</div>
          <div className="d dim">
            depuis le {new Date(log.since).toLocaleDateString("fr-FR", { day: "numeric", month: "long" })}, sur {fmt(s.hours, 0)} h suivies
            {rank ? `. Rang ${rank} : ${[1, 2, 3][Math.min(rank, 3) - 1]} % de chance par coupe` : ". Skill pas pris"}
          </div>
        </div>
        <div className="kpi">
          <div className="l">Gain moyen par jour</div>
          <div className="v">{nf(perDay)} coins</div>
          <div className="d dim">≈ {usd(toUsd(perDay))} par jour, {usd(toUsd(perDay) * MONTH)} par mois. En moyenne théorique : {nf(expectedPerDay)} coins</div>
        </div>
        <div className="kpi">
          <div className="l">Ta chance</div>
          <div className={"v" + (luck >= 1 ? " gold" : "")}>{s.expectedPops >= 0.5 ? `${Math.round(luck * 100)} %` : "—"}</div>
          <div className="d dim">{s.pops} pops pour {fmt(s.expectedPops, 1)} attendus sur tes {nf(s.chops)} coupes suivies. 100 % = pile la moyenne{s.expectedPops < 10 ? ". Encore trop peu de pops pour conclure : attends une dizaine de pops attendus" : ""}</div>
        </div>
      </div>}

      <div className={replay ? "" : "grid"}>
        <section className="card" aria-labelledby="h-pd">
          <h2 id="h-pd">Coins par jour</h2>
          <p className="hint">Barre : ce que Money Tree t'a donné{replay ? ", recalculé avec les tirages du jeu" : ""}. Trait : ce qu'il aurait dû donner en moyenne avec tes coupes du jour.</p>
          <div className="pchart" role="img" aria-label="Coins Money Tree par jour, réel et attendu">
            {shownDays.map((d) => (
              <div className="pcol" key={d.day} title={`${dayLabel(d.day)} : ${d.pops} pop${d.pops > 1 ? "s" : ""}, ${nf(d.coins)} coins (attendu ${nf(d.expectedCoins)})`}>
                <div className="pplot">
                  <b style={{ height: `${(d.coins / maxBar) * 100}%` }} />
                  <i style={{ bottom: `${(d.expectedCoins / maxBar) * 100}%` }} />
                </div>
                <span className="pn">{d.pops || ""}</span>
                <span className="pd">{new Date(d.day).toLocaleDateString("fr-FR", { day: "numeric", month: "numeric" })}</span>
              </div>
            ))}
          </div>
        </section>

        {replay ? null : <section className="card" aria-labelledby="h-pt">
          <h2 id="h-pt">Par arbre</h2>
          <p className="hint">Un pop vaut 200 coins × le multiplicateur de l'arbre coupé.</p>
          <div className="ptree">
            {s.byTree.map((t) => (
              <div key={t.tree} className="pt-row">
                <span className="lb"><Icon name="wood" size={18} />{TREE_FR[t.tree]}</span>
                <span>{t.pops} <small className="dim">/ {fmt(t.expectedPops, 1)} att.</small></span>
                <b>{nf(t.coins)}</b>
              </div>
            ))}
            {s.unknown ? <p className="hint">{s.unknown} pop{s.unknown > 1 ? "s" : ""} sur un arbre déjà recoupé avant la lecture : compté au gain moyen d'un pop.</p> : null}
          </div>
        </section>}
      </div>

      <section className="card" aria-labelledby="h-pl">
        <h2 id="h-pl">Derniers pops</h2>
        {last.length ? (
          <ul className="plist">
            {last.slice(0, 30).map((e: ProcEvent) => (
              <li key={e.at}>
                <span>{new Date(e.at).toLocaleString("fr-FR", { weekday: "short", day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" })}</span>
                <span className="dim">{e.tree ? TREE_FR[e.tree] : "arbre inconnu"}{e.before ? " · avant le suivi" : ""}</span>
                <b>{e.coins !== undefined ? `+${nf(e.coins)} coins` : "—"}</b>
              </li>
            ))}
          </ul>
        ) : <p className="hint">Aucun pop pour l'instant.</p>}
      </section>

      {replay ? <p className="foot">
        Les pops sont recalculés avec le tirage du jeu (chop.ts, prng.ts) sur tes compteurs de coupes : ils ne dépendent ni de l'heure des relevés ni de l'app ouverte.
        « Derniers pops » liste ceux que l'app a vus passer. Coins comptés au taux de la banque (320 pour 1 FLOWER).
      </p> : <p className="foot">
        Le jeu ne garde que l'heure du dernier pop. L'app la relit toutes les 10 minutes quand elle est ouverte : deux pops dans les mêmes 10 minutes comptent pour un.
        Quand l'app est fermée, les pops peuvent passer inaperçus : ces heures-là ne comptent ni pour les pops ni pour les coupes. Le gain par jour applique tes coins par coupe à toutes tes coupes de la journée.
        Coins comptés au taux de la banque (320 pour 1 FLOWER).
      </p>}
    </>
  );
}

const KIND_FR: Record<string, string> = { "Basic Tree": "Arbre", "Ancient Tree": "Arbre ancien", "Sacred Tree": "Arbre sacré" };

/**
 * The game's Money Tree draws are fixed: from the chop counters, the real pops of the last 30 days
 * and the next ones are known. Two switches show the same chops at rank 2 or 3.
 */
function Draws({ state, rank }: { state: AppState; rank: number }) {
  const farm = state.farm as any;
  const [alt, setAlt] = usePersisted<number>("procs.rank", 0);
  const shown = alt || rank;
  const rates = useMemo(() => dailyRates(state.snapshots).rates, [state.snapshots]);
  const mults = useMemo(() => treeMults(farm), [farm]);
  const f = useMemo(() => forecast(state.farmId!, farm.farmActivity ?? {}, rates, mults, shown), [state.farmId, farm, rates, mults, shown]);
  const base = useMemo(() => (alt && alt !== rank ? forecast(state.farmId!, farm.farmActivity ?? {}, rates, mults, rank) : null), [alt, rank, state.farmId, farm, rates, mults]);
  const rate = state.market?.flowerUsd ?? 0;
  const sum = (l: KindForecast[], g: (k: KindForecast) => number) => l.reduce((a, k) => a + g(k), 0);
  const day = (coins: number, days: number) => coins / days / COINS_PER_FLOWER;
  const past = sum(f, (k) => k.past.coins), pastExp = sum(f, (k) => k.past.expected);
  const month = sum(f, (k) => k.month.coins), week = sum(f, (k) => k.week.coins);
  const vsBase = base ? (month - sum(base, (k) => k.month.coins)) / COINS_PER_FLOWER * rate : 0;
  const noChops = sum(f, (k) => k.perDay) === 0;

  return (
    <section className="card" aria-labelledby="h-draw">
      <div className="rev-head">
        <h2 id="h-draw">Les tirages du jeu {alt ? <small className="dim">si rang {alt}</small> : <small className="dim">rang {rank || 0}</small>}</h2>
        <div className="seg" role="group" aria-label="Voir un autre rang">
          {[2, 3].map((r) => (
            <button key={r} className="mini-sw" role="switch" aria-checked={alt === r} onClick={() => setAlt(alt === r ? 0 : r)} disabled={r === rank}>
              <span className="sw" aria-hidden="true" />Si rang {r}
            </button>
          ))}
        </div>
      </div>
      <p className="hint">
        Money Tree n'est pas du hasard : chaque coupe tire un nombre fixe, qui dépend de ta ferme, du type d'arbre et du nombre d'arbres de ce type déjà coupés.
        L'app recalcule donc tes vrais pops passés et prévoit les prochains, à ton rythme de coupe mesuré.
      </p>
      {noChops ? <p className="hint">Pas encore assez de relevés pour connaître ton rythme de coupe.</p> : (
        <>
          <div className="kpis">
            <div className="kpi">
              <div className="l">{MT_WINDOW} derniers jours</div>
              <div className="v">{nf(day(past, MT_WINDOW))} F<small className="unit dim"> /jour</small></div>
              <div className="d dim">{sum(f, (k) => k.past.pops)} pops, {nf(past)} coins. Moyenne théorique : {nf(day(pastExp, MT_WINDOW))} F/jour</div>
            </div>
            <div className="kpi">
              <div className="l">7 prochains jours</div>
              <div className="v">{nf(day(week, 7))} F<small className="unit dim"> /jour</small></div>
              <div className="d dim">{sum(f, (k) => k.week.pops)} pops, {nf(week)} coins</div>
            </div>
            <div className="kpi">
              <div className="l">30 prochains jours</div>
              <div className="v gold">{usd((month / COINS_PER_FLOWER) * rate)}<small className="unit dim"> /mois</small></div>
              <div className="d dim">{sum(f, (k) => k.month.pops)} pops, {nf(month)} coins ({nf(month / COINS_PER_FLOWER)} F){base ? `, soit ${vsBase >= 0 ? "+" : ""}${usd(vsBase)} par rapport à ton rang ${rank}` : ""}</div>
            </div>
          </div>
          <div className="ptree">
            {f.map((k) => (
              <div key={k.kind} className="pt-row">
                <span className="lb"><Icon name="wood" size={18} />{KIND_FR[k.kind]} <small className="dim">×{k.mult}</small></span>
                <span>{k.nextIn !== null ? <>prochain pop dans <b>{k.nextIn}</b> coupes{k.nextDays !== null ? <small className="dim"> (≈ {k.nextDays < 1 ? `${Math.max(1, Math.round(k.nextDays * 24))} h` : `${fmt(k.nextDays, 1)} j`})</small> : null}</> : "—"}</span>
                <b>{k.month.pops} pops / 30 j</b>
              </div>
            ))}
          </div>
        </>
      )}
    </section>
  );
}
