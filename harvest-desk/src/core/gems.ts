/**
 * Price of gems paid in FLOWER (components/modal/components/BuyGems.tsx).
 * Packs are priced in USD; paying in FLOWER takes 20 % off, and the FLOWER amount is that price
 * divided by the FLOWER rate of the moment. So: gems → USD at the pack rate, then USD → FLOWER.
 */
export const GEM_PACKS = [
  { amount: 100, usd: 1.29 },
  { amount: 650, usd: 6.49 },
  { amount: 1350, usd: 12.99 },
  { amount: 2800, usd: 25.99 },
  { amount: 7400, usd: 64.99 },
  { amount: 15500, usd: 129.99 },
  { amount: 200000, usd: 1299.99 },
];
export const FLOWER_DISCOUNT = 0.8;
/** The pack Wzx buys: 2 800 gems. */
export const USUAL_PACK = 2800;

/** What `gems` cost when bought with FLOWER at the usual pack's rate. */
export function gemCost(gems: number, flowerUsd: number, pack = USUAL_PACK): { usd: number; flower: number } {
  const p = GEM_PACKS.find((x) => x.amount === pack) ?? GEM_PACKS[3];
  const usd = (gems * p.usd / p.amount) * FLOWER_DISCOUNT;
  return { usd, flower: flowerUsd > 0 ? usd / flowerUsd : 0 };
}
