import { describe, expect, it } from "vitest";
import { gemCost } from "../src/core/gems";

describe("gems bought with FLOWER", () => {
  it("matches the game's 2 800 gem pack", () => {
    // In game: 2 800 gems = $20.79 = 161.7903 FLOWER at 1 FLOWER = $0.1285.
    const c = gemCost(2800, 0.1285);
    expect(c.usd).toBeCloseTo(20.79, 2);
    expect(c.flower).toBeCloseTo(161.79, 1);
  });
  it("prices a 200 gem skill reset", () => {
    expect(gemCost(200, 0.1285).usd).toBeCloseTo(1.485, 2);
  });
});

import { dailyRates } from "../src/core/engine";

describe("gems in the daily rates", () => {
  it("averages a counter from the first reading that has it", () => {
    const D = 86_400_000;
    const r = dailyRates([
      { at: 0, farmActivity: { "Wheat Harvested": 0 } },
      { at: 5 * D, farmActivity: { "Wheat Harvested": 500, "Instant Gems Spent": 2600 } },
      { at: 10 * D, farmActivity: { "Wheat Harvested": 1000, "Instant Gems Spent": 2800 } },
    ]);
    expect(r.rates["Wheat Harvested"]).toBeCloseTo(100);
    expect(r.rates["Instant Gems Spent"]).toBeCloseTo(40);
  });
});
