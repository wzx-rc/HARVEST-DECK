import { describe, expect, it } from "vitest";
import type { Category, CategoryKey, Line, Report } from "../src/core/engine";
import { internalize } from "../src/core/internal";

const L = (key: string, gross: number, cost: number, made?: Record<string, number>, uses?: Record<string, number>): Line =>
  ({ key, label: key, gross, cost, net: gross - cost, made, uses });
const cat = (key: CategoryKey, lines: Line[]): Category =>
  ({ key, lines, gross: lines.reduce((a, l) => a + l.gross, 0), cost: lines.reduce((a, l) => a + l.cost, 0), net: lines.reduce((a, l) => a + l.net, 0) });
const report = (cats: Category[]): Report => {
  const all = { crops: cat("crops", []), animals: cat("animals", []), greenhouse: cat("greenhouse", []), minerals: cat("minerals", []), wood: cat("wood", []), fruits: cat("fruits", []), honey: cat("honey", []) };
  for (const c of cats) all[c.key] = c;
  const v = Object.values(all);
  return { categories: all, net: v.reduce((a, c) => a + c.net, 0), gross: v.reduce((a, c) => a + c.gross, 0), cost: v.reduce((a, c) => a + c.cost, 0) };
};

describe("Ce que tu encaisses", () => {
  const prices = { Wood: 0.01, Stone: 0.02 };
  // 1 000 wood cut, 800 used by pickaxes (plus 0.5 F of coins); 100 stone used, 50 mined.
  const r = report([
    cat("wood", [L("Tree", 1000 * 0.01, 1, { Wood: 1000 })]),
    cat("minerals", [L("Stone", 50 * 0.02, 800 * 0.01 + 100 * 0.02 + 0.5, { Stone: 50 }, { Wood: 800, Stone: 100 })]),
  ]);
  const c = internalize(r, prices);

  it("keeps the total", () => {
    expect(c.net).toBeCloseTo(r.net);
  });
  it("moves the wood the pickaxes use out of both lines", () => {
    expect(c.categories.wood.net).toBeCloseTo(200 * 0.01 - 1);
    expect(c.categories.minerals.lines[0].cost).toBeCloseTo(0.5 + 50 * 0.02);
  });
  it("leaves what is bought as a cost", () => {
    // 100 stone used, only 50 mined: the other 50 are still paid for.
    expect(c.categories.minerals.lines[0].gross).toBeCloseTo(0);
  });
});
