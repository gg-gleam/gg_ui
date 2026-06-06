// Load the CSS entry (Tailwind + all base-color/theme/shape fragments +
// motion). Tailwind is processed by @tailwindcss/vite (see vite.config.ts).
import "../src/gg_ui.css"

import type { Preview } from "@storybook/html-vite"

// The axes, matching shadcn's vocabulary. All are classes on the story root:
//   SHAPE      → style-<name>        (padding / radius / density)
//   BASE COLOR → base-color-<name>   (neutral palette: bg / fg / muted / border)
//   THEME      → theme-<name>        (accent; overrides --primary). "none" = the
//                                     base color's own neutral primary.
//   MODE       → .dark
// Keep these in sync with packages/gg_ui/src/gg_ui/styles/{shapes,base_colors,themes}.
const shapes = ["nova", "vega", "luma", "sera", "lyra", "mira", "maia"] as const
const baseColors = [
  "neutral",
  "stone",
  "zinc",
  "mauve",
  "olive",
  "mist",
  "taupe",
  "lucy",
] as const
const themes = [
  "none",
  "amber",
  "blue",
  "cyan",
  "emerald",
  "fuchsia",
  "green",
  "indigo",
  "lime",
  "orange",
  "pink",
  "purple",
  "red",
  "rose",
  "sky",
  "teal",
  "violet",
  "yellow",
  "lucy",
] as const

const preview: Preview = {
  parameters: {
    layout: "centered",
    a11y: { test: "error" },
  },

  globalTypes: {
    shape: {
      description: "Shape style (padding / radius / density)",
      toolbar: {
        title: "Shape",
        icon: "component",
        items: shapes.map((s) => ({ value: s, title: s })),
        dynamicTitle: true,
      },
    },
    baseColor: {
      description: "Base color (neutral palette)",
      toolbar: {
        title: "Base color",
        icon: "circle",
        items: baseColors.map((c) => ({ value: c, title: c })),
        dynamicTitle: true,
      },
    },
    theme: {
      description: "Theme (accent / primary color)",
      toolbar: {
        title: "Theme",
        icon: "paintbrush",
        items: themes.map((t) => ({ value: t, title: t })),
        dynamicTitle: true,
      },
    },
    mode: {
      description: "Light / dark mode",
      toolbar: {
        title: "Mode",
        icon: "contrast",
        items: [
          { value: "light", title: "Light", icon: "sun" },
          { value: "dark", title: "Dark", icon: "moon" },
        ],
        dynamicTitle: true,
      },
    },
    // Manual trigger for a story's interaction test (`play`). Storybook auto-runs
    // `play` on every render, which flickers stateful components (popover opening
    // then closing) while you browse. Stories gate their play behind this global
    // (see `testOnly` in the stories) so it only fires when you flip it on —
    // toggling re-renders the story and runs the play. Tests still run regardless
    // (they set `__vitest_browser__`), so this is dev-UI-only.
    runPlay: {
      description: "Run the story's interaction test on render",
      toolbar: {
        title: "Play",
        icon: "play",
        items: [
          { value: "off", title: "Play: off" },
          { value: "on", title: "Play: on" },
        ],
        dynamicTitle: true,
      },
    },
  },

  initialGlobals: {
    shape: "nova",
    baseColor: "neutral",
    theme: "none",
    mode: "light",
    runPlay: "off",
  },

  // Apply the axes to the story root. base-color + theme set the color tokens
  // (`--primary`, …); style-* carries the recipes. Tagging the root — the
  // popover's DOM ancestor — makes the cascade reach popover content in the top
  // layer. The root paints itself with the resolved tokens so dark mode and the
  // accent are visible on the canvas.
  decorators: [
    (story, context) => {
      const { shape, baseColor, theme, mode } = context.globals as {
        shape: string
        baseColor: string
        theme: string
        mode: string
      }
      const root = story() as HTMLElement
      root.classList.add(`style-${shape}`, `base-color-${baseColor}`)
      if (theme && theme !== "none") {
        root.classList.add(`theme-${theme}`)
      }
      if (mode === "dark") {
        root.classList.add("dark")
      }
      root.style.setProperty("background", "var(--background)")
      root.style.setProperty("color", "var(--foreground)")
      root.style.setProperty("padding", "3rem")
      root.style.setProperty("border-radius", "0.5rem")
      return root
    },
  ],
}

export default preview
