import { defineConfig } from "vite"
import { sharedPlugins } from "./vite-plugins"

// On GitHub Pages the build is served from a project sub-path
// (https://gg-gleam.github.io/gg_ui/), so assets must resolve under that base.
// The deploy workflow sets STORYBOOK_BASE_PATH=/gg_ui/; local dev/build defaults
// to "/" so nothing changes outside CI.
const base = process.env.STORYBOOK_BASE_PATH ?? "/"

export default defineConfig({
  base,
  plugins: [...sharedPlugins],
})
