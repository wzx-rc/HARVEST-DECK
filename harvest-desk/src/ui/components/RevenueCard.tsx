import type { CategoryKey } from "../../core/engine";
import { Legend } from "./Legend";
import { Ring } from "./Ring";

interface Props {
  values: Record<CategoryKey, number>; baseValues: Record<CategoryKey, number>;
  total: number; base: number; scale: number; days: number; subtitles: Record<CategoryKey, string>;
  /** Show what the farm sells, without what it makes and uses itself. */
  cash: boolean; setCash: (v: boolean) => void;
}

export function RevenueCard({ values, baseValues, total, base, scale, days, subtitles, cash, setCash }: Props) {
  return (
    <section className="card" aria-labelledby="h-rev">
      <div className="rev-head">
        <h2 id="h-rev">Ce que la ferme rapporte par jour</h2>
        <button className="mini-sw" role="switch" aria-checked={cash} onClick={() => setCash(!cash)}
          title="Retire de chaque ligne ce que ta ferme produit et consomme elle-même (bois et pierre des pioches, céréales des animaux, fer et cuir des Oil Drills…). Le total ne change pas.">
          <span className="sw" aria-hidden="true" />Ce que tu encaisses
        </button>
      </div>
      <p className="hint">
        {cash
          ? "Sans ce que ta ferme produit et consomme elle-même : chaque ligne montre ce qui part vraiment au marché."
          : "Net, après graines, nourriture et pioches, tout compté au prix du marché."}
        {" "}Moyenne réelle sur {days >= 1.5 ? `${Math.round(days)} jours` : "moins de 2 jours"}.
      </p>
      <div className="hero" style={{ marginTop: 18 }}>
        <Ring values={values} total={total} base={base} scale={scale} />
        <Legend values={values} base={baseValues} subtitles={subtitles} />
      </div>
    </section>
  );
}
