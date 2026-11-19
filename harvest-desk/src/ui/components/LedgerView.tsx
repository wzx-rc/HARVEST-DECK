import { useMemo, useState } from "react";
import { flowerOf, gains, type EntryKind, type LedgerEntry } from "../../core/ledger";
import type { AppState, ManualEntry } from "../../shared/types";
import { Icon } from "../icons";
import { dayLabel, fmt, nf } from "../format";
import { usePersisted } from "../usePersisted";

const DAY = 86_400_000;
const PERIODS = [
  { k: "7", label: "7 jours", days: 7 },
  { k: "30", label: "30 jours", days: 30 },
  { k: "all", label: "Tout", days: Infinity },
] as const;

const KIND: Record<EntryKind, { label: string; icon: string; color: string }> = {
  withdraw: { label: "Sortie du jeu", icon: "out", color: "var(--sky)" },
  delivery: { label: "Livraisons", icon: "delivery", color: "var(--sheep)" },
  purchase: { label: "Achat", icon: "bag", color: "var(--loss)" },
  sale: { label: "Vente", icon: "coins", color: "var(--sheep)" },
  spend: { label: "Dépense en jeu", icon: "out", color: "var(--wheat)" },
  income: { label: "Autre gain", icon: "in", color: "var(--sheep)" },
  manual: { label: "Saisi à la main", icon: "pen", color: "var(--ore)" },
};

const money = (v: number) => (v < 0 ? "−" : "+") + (Math.abs(v) >= 100 ? nf(Math.abs(v)) : fmt(Math.abs(v))) + " $";

const fl = (v: number) => (Math.abs(v) >= 100 ? nf(v) : fmt(v)) + "\u00a0FL";
const sfl = (v: number) => (v < 0 ? "−" : "+") + fl(Math.abs(v));

/** "Gains": FLOWER the farm made and spent over the period, NFT trades counted or not, and what left the game. */
export function LedgerView({ state, onAdd, onRemove }: { state: AppState; onAdd: (e: ManualEntry) => void; onRemove: (id: string) => void }) {
  const [period, setPeriod] = usePersisted<(typeof PERIODS)[number]["k"]>("ledger.period", "30");
  const [withNft, setWithNft] = usePersisted<boolean>("ledger.withNft", false);
  const now = state.fetchedAt ? Date.parse(state.fetchedAt) : Date.now();
  const rate = state.market?.flowerUsd ?? 0;
  const days = PERIODS.find((p) => p.k === period)!.days;
  const list = useMemo(() => state.ledger.filter((e) => now - e.at <= days * DAY), [state.ledger, now, days]);
  const g = gains(list, withNft, rate);
  const first = state.ledger.length ? Math.min(...state.ledger.map((e) => e.at)) : now;
  const nftNote = (v: number, verb: string) => v > 0 ? (withNft ? `Dont ${fl(v)} ${verb} de NFT` : `Hors ${verb} de NFT (${fl(v)} non comptés)`) : (verb === "ventes" ? "Aucune vente de NFT" : "Aucun achat de NFT");

  return (
    <>
      <div className="top2">
        <div className="seg" role="group" aria-label="Période">
          {PERIODS.map((p) => (
            <button key={p.k} className="btn" aria-pressed={period === p.k} onClick={() => setPeriod(p.k)}>{p.label}</button>
          ))}
        </div>
        <button className="mini-sw" role="switch" aria-checked={withNft} onClick={() => setWithNft(!withNft)}>
          <span className="sw" aria-hidden="true" />Avec achats et ventes de NFT
        </button>
        <span className="dim small">Suivi depuis le {new Date(first).toLocaleDateString("fr-FR")}.</span>
      </div>

      <div className="kpis four">
        <div className="kpi"><div className="l">Généré</div><div className="v pos">{sfl(g.made)}<Usd v={g.made * rate} /></div><div className="d dim">{nftNote(g.nftSold, "ventes")}</div></div>
        <div className="kpi"><div className="l">Dépensé</div><div className="v neg">{sfl(-g.spent)}<Usd v={-g.spent * rate} /></div><div className="d dim">{nftNote(g.nftBought, "achats")}</div></div>
        <div className="kpi"><div className="l">Gain</div><div className={"v " + (g.gain >= 0 ? "gold" : "neg")}>{sfl(g.gain)}<Usd v={g.gain * rate} /></div><div className="d dim">Généré moins dépensé</div></div>
        <div className="kpi"><div className="l">Sortie du jeu</div><div className="v" style={{ color: "var(--sky)" }}>{sfl(g.out)}<Usd v={g.out * rate} /></div><div className="d dim">Retiré vers ton portefeuille</div></div>
      </div>

      <FlowChart entries={list} now={now} rate={rate} withNft={withNft} days={days === Infinity ? Math.max(7, Math.ceil((now - first) / DAY) + 1) : days} />

      <div className="grid">
        <section className="card" aria-labelledby="h-list">
          <h2 id="h-list">Mouvements</h2>
          <p className="hint">Le plus récent en haut, en FLOWER et en dollars au cours du moment.{withNft ? "" : " Les achats et ventes de NFT sont listés mais pas comptés."}</p>
          <ul className="moves">
            {list.length === 0 ? <li className="empty">Aucun mouvement sur cette période.</li> : null}
            {list.map((e) => <Move key={e.id} e={e} rate={rate} muted={!withNft && !!e.nft} onRemove={e.kind === "manual" ? () => onRemove(e.id) : undefined} />)}
          </ul>
        </section>
        <AddEntry onAdd={onAdd} />
      </div>
    </>
  );
}

/** Dollar value beside a FLOWER amount, a bit smaller. */
const Usd = ({ v }: { v: number }) => <>{" "}<small className="usd">{"/\u00a0" + money(v)}</small></>;

function Move({ e, rate, muted, onRemove }: { e: LedgerEntry; rate: number; muted: boolean; onRemove?: () => void }) {
  const k = KIND[e.kind];
  const f = flowerOf(e, rate), out = e.kind === "withdraw";
  return (
    <li className="move" style={muted ? { opacity: 0.55 } : undefined} title={muted ? "Achat ou vente de NFT, pas compté" : undefined}>
      <span className="chip" style={{ color: k.color }}><Icon name={k.icon} size={18} /></span>
      <span className="t">
        <b>{e.label}</b>
        <span title={e.detail}>{dayLabel(e.at)} · {e.detail ?? k.label}</span>
      </span>
      <span className="g">
        <b className={out ? "" : f < 0 ? "neg" : "pos"} style={out ? { color: "var(--sky)" } : undefined}>{sfl(out ? -f : f)}</b>
        <span>{e.flower !== undefined ? money(out ? -e.usd : e.usd) : `saisi en $ : ${money(e.usd)}`}</span>
      </span>
      {onRemove ? <button className="iconbtn sm" aria-label={`Supprimer ${e.label}`} title="Supprimer" onClick={onRemove}><Icon name="close" size={14} /></button> : <span />}
    </li>
  );
}

function AddEntry({ onAdd }: { onAdd: (e: ManualEntry) => void }) {
  const today = new Date().toISOString().slice(0, 10);
  const [date, setDate] = useState(today);
  const [label, setLabel] = useState("");
  const [amount, setAmount] = useState("");
  const [dir, setDir] = usePersisted<"in" | "out">("ledger.dir", "out");
  const value = Number(amount.replace(",", "."));
  const ok = label.trim() && Number.isFinite(value) && value > 0;
  const submit = (ev: React.FormEvent) => {
    ev.preventDefault();
    if (!ok) return;
    onAdd({ at: Date.parse(date + "T12:00:00"), usd: dir === "in" ? value : -value, label: label.trim() });
    setLabel(""); setAmount("");
  };
  return (
    <section className="card" aria-labelledby="h-add">
      <h2 id="h-add">Ajouter un mouvement</h2>
      <p className="hint">Pour ce que l'app ne voit pas : FLOWER acheté par carte ou en crypto, revente hors jeu, abonnement VIP…</p>
      <form onSubmit={submit}>
        <div className="seg" role="group" aria-label="Sens">
          <button type="button" className="btn" aria-pressed={dir === "out"} onClick={() => setDir("out")}>Sortie</button>
          <button type="button" className="btn" aria-pressed={dir === "in"} onClick={() => setDir("in")}>Entrée</button>
        </div>
        <div className="field"><label htmlFor="m-label">Libellé</label>
          <input id="m-label" value={label} onChange={(e) => setLabel(e.target.value)} placeholder="Achat de 500 FLOWER" maxLength={120} /></div>
        <div className="row2">
          <div className="field"><label htmlFor="m-amount">Montant en $</label>
            <input id="m-amount" inputMode="decimal" value={amount} onChange={(e) => setAmount(e.target.value)} placeholder="70" /></div>
          <div className="field"><label htmlFor="m-date">Date</label>
            <input id="m-date" type="date" value={date} max={today} onChange={(e) => setDate(e.target.value)} /></div>
        </div>
        <div className="actions"><button className="btn primary" type="submit" disabled={!ok}>Ajouter</button></div>
      </form>
    </section>
  );
}

/** Daily bars in FLOWER: made above the line, spent below, and what left the game in blue. Weekly bars past 60 days. */
function FlowChart({ entries, now, days, rate, withNft }: { entries: LedgerEntry[]; now: number; days: number; rate: number; withNft: boolean }) {
  const W = 760, H = 200, L = 64, R = 12, T = 12, B = 26;
  const step = days > 60 ? 7 : 1;
  const n = Math.ceil(days / step);
  const start = new Date(now - (n * step - 1) * DAY); start.setHours(0, 0, 0, 0);
  const bins = [...Array(n)].map((_, i) => ({ t: start.getTime() + i * step * DAY, entries: [] as LedgerEntry[] }));
  for (const e of entries) {
    const i = Math.floor((e.at - start.getTime()) / (step * DAY));
    if (i >= 0 && i < n) bins[i].entries.push(e);
  }
  const sums = bins.map((b) => ({ t: b.t, ...gains(b.entries, withNft, rate) }));
  const hi = Math.max(1, ...sums.map((b) => Math.max(b.made, b.out))), lo = Math.min(-1, ...sums.map((b) => -b.spent));
  const span = hi - lo;
  const y = (v: number) => T + ((hi - v) / span) * (H - T - B);
  const bw = (W - L - R) / n;
  const labelEvery = Math.ceil(n / 10);
  return (
    <section className="card" aria-labelledby="h-flow">
      <h2 id="h-flow">Gains {step === 7 ? "par semaine" : "par jour"}</h2>
      <svg className="chart" viewBox={`0 0 ${W} ${H}`} role="img" aria-label="Barres du FLOWER généré, dépensé et sorti du jeu">
        {[hi, 0, lo].map((v) => (
          <g key={v}>
            <line x1={L} x2={W - R} y1={y(v)} y2={y(v)} stroke={v === 0 ? "var(--dim)" : "var(--line)"} />
            <text x={L - 8} y={y(v) + 3} textAnchor="end">{v === 0 ? "0 FL" : sfl(v)}</text>
          </g>
        ))}
        {sums.map((b, i) => {
          const x = L + i * bw, w = b.out > 0 ? bw * 0.4 : bw * 0.64, x0 = b.out > 0 ? x + bw * 0.1 : x + bw * 0.18;
          return (
            <g key={b.t}>
              {b.made > 0 ? <rect x={x0} width={w} y={y(b.made)} height={y(0) - y(b.made)} rx="2" fill="var(--sheep)"><title>{`${dayLabel(b.t)} : généré ${sfl(b.made)}`}</title></rect> : null}
              {b.spent > 0 ? <rect x={x0} width={w} y={y(0)} height={y(-b.spent) - y(0)} rx="2" fill="var(--loss)"><title>{`${dayLabel(b.t)} : dépensé ${sfl(-b.spent)}`}</title></rect> : null}
              {b.out > 0 ? <rect x={x + bw * 0.52} width={bw * 0.38} y={y(b.out)} height={y(0) - y(b.out)} rx="2" fill="var(--sky)"><title>{`${dayLabel(b.t)} : sorti du jeu ${sfl(b.out)}`}</title></rect> : null}
              {i % labelEvery === 0 ? <text x={x + bw / 2} y={H - 8} textAnchor="middle">{new Date(b.t).toLocaleDateString("fr-FR", { day: "numeric", month: "short" })}</text> : null}
            </g>
          );
        })}
      </svg>
      <div className="lg2">
        <span><i style={{ background: "var(--sheep)" }} />Généré</span>
        <span><i style={{ background: "var(--loss)" }} />Dépensé</span>
        <span><i style={{ background: "var(--sky)" }} />Sortie du jeu</span>
      </div>
    </section>
  );
}
