import { execFileSync } from "node:child_process"
import { fileURLToPath } from "node:url"

// Warm the Gleam → JS build ONCE before the suite runs.
//
// vite-plugin-gleam compiles `.gleam` imports during Vite's transform phase,
// shelling out to `gleam build` under a hardcoded 5s execa timeout that its
// options don't expose. A cold full-graph build (stdlib + lustre + gleam_otp +
// gva + birdie deps + the app) on a fresh CI runner exceeds that and fails at
// module load — before any test runs. Building here, in Node, before the first
// transform makes the plugin's in-test build incremental (well under the cap).
//
// This is the single common place for the warm-up: every vitest entrypoint —
// `test:stories`, `coverage`, the watcher — inherits it via `globalSetup`, so
// the npm scripts stay plain `vitest`.
export async function setup(): Promise<void> {
  execFileSync("gleam", ["build", "--target", "javascript"], {
    cwd: fileURLToPath(new URL(".", import.meta.url)),
    stdio: "inherit",
  })
}
