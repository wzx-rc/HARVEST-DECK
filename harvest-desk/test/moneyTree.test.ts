import { describe, expect, it } from "vitest";
import { forecast, popsBetween, prng } from "../src/core/moneyTree";

const FARM = 150782;

describe("Money Tree draws", () => {
  it("are spread like the rank chance", () => {
    let n = 0;
    for (let c = 0; c < 100_000; c++) if (prng(FARM, 618, c) * 100 < 1) n++;
    expect(n / 1000).toBeGreaterThan(0.85);
    expect(n / 1000).toBeLessThan(1.15);
  });
  it("finds the one pop of 15 to 17 November on this farm", () => {
    // Counters read on 15/11 10:34 and 17/11 19:55 UTC; the only pop seen was on a basic tree.
    expect(popsBetween(FARM, 618, 47776, 47971, 1)).toEqual([47962]);
    expect(popsBetween(FARM, 2702, 13762, 13888, 1)).toEqual([]);
    expect(popsBetween(FARM, 2703, 4110, 4163, 1)).toEqual([]);
  });
  it("forecasts the next pops at each rank", () => {
    const act = { "Basic Tree Chopped": 47977, "Ancient Tree Chopped": 13897, "Sacred Tree Chopped": 4164 };
    const rates = { "Basic Tree Chopped": 82, "Ancient Tree Chopped": 53, "Sacred Tree Chopped": 22 };
    const mults = { "Basic Tree": 1, "Ancient Tree": 4, "Sacred Tree": 16 };
    const r1 = forecast(FARM, act, rates, mults, 1);
    expect(r1.find((k) => k.kind === "Sacred Tree")!.nextIn).toBe(164);
    const coins = (l: typeof r1) => l.reduce((a, k) => a + k.month.coins, 0);
    expect(coins(r1)).toBe(42000);
    expect(coins(forecast(FARM, act, rates, mults, 3))).toBeGreaterThan(coins(r1));
  });
});
