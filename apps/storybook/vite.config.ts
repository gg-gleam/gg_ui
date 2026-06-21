import { defineConfig } from "vite"
import { sharedPlugins } from "./vite-plugins"

// The Node global isn't typed here (tsconfig `types: []` keeps it minimal);
// declare just the env shape we read rather than pull in @types/node.
declare const process: { env: Record<string, string | undefined> }

// On GitHub Pages the build is served from a project sub-path
// (https://gg-gleam.github.io/gg_ui/), so assets must resolve under that base.
// The deploy workflow sets STORYBOOK_BASE_PATH=/gg_ui/; local dev/build defaults
// to "/" so nothing changes outside CI.
const base = process.env.STORYBOOK_BASE_PATH ?? "/"

export default defineConfig({
  base,
  plugins: [...sharedPlugins],
})
