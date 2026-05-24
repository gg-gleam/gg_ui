import { storybookTest } from "@storybook/addon-vitest/vitest-plugin"
import { defineConfig } from "vitest/config"
import { sharedPlugins } from "./vite-plugins"

// Runs every Storybook story as a test. Unlike `pnpm dev`/`build`, vitest does
// NOT auto-merge `vite.config.ts`, so it reuses the same `sharedPlugins`
// (`gleam()` for `.gleam` imports + `tailwindcss()` for the real CSS). Project
// annotations (the axes decorator + a11y) are applied automatically by
// `@storybook/addon-vitest` since Storybook 10.3 — no setup file needed.
//
// The provider is Playwright/Chromium, NOT jsdom: the components depend on the
// native Popover API, CSS anchor positioning, the top layer and `:popover-open`,
// none of which exist in jsdom. jsdom would render a green test against a
// component that never actually opens or light-dismisses.
export default defineConfig({
  plugins: [...sharedPlugins, storybookTest({ configDir: ".storybook" })],
  test: {
    name: "storybook",
    deps: {
      optimizer: {
        web: {
          exclude: ["react", "react-dom/client", "react/jsx-runtime"],
        },
      },
    },
    coverage: {
      provider: "v8",
      // Hold only the *library* FFI (`gg_base_ui` / `gg_ui`) to a coverage
      // contract — that's the shipped glue, wherever the path-deps resolve it.
      // Scoping `include` to those package segments naturally leaves out the
      // storybook app's own story-helper FFI (`src/helpers/*_ffi.ts`, demo
      // scaffolding) without an `exclude` (which would replace v8's defaults
      // and double-instrument the raw source).
      include: ["**/gg_base_ui/**/*_ffi.ts", "**/gg_ui/**/*_ffi.ts"],
    },
    browser: {
      enabled: true,
      provider: "playwright",
      headless: true,
      instances: [{ browser: "chromium" }],
    },
  },
})
