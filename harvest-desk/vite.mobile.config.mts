import { defineConfig } from "vite";

// The calculations for the iOS app, as one plain script for JavaScriptCore.
export default defineConfig({
  publicDir: false,
  build: {
    outDir: "../ios/HarvestDesk/Resources",
    emptyOutDir: false,
    target: "es2020",
    minify: true,
    lib: { entry: "src/mobile/bridge.ts", name: "HDCore", formats: ["iife"], fileName: () => "core.js" },
  },
});
