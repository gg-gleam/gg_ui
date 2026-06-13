// Load the CSS entry (Tailwind + all base-color/theme/shape fragments +
// motion). Tailwind is processed by @tailwindcss/vite (see vite.config.ts).
import "../src/gg_ui.css"

import type { Preview } from "@storybook/html-vite"
import { BODY_ITEMS, HEADING_ITEMS, resolveBody, resolveHeading } from "./fonts"

// The axes, matching shadcn's vocabulary. The first three are classes on the
// story root; FONT sets the `--font-*` custom props directly (a real font
// family, loaded by the demo app — see ./fonts.ts):
//   SHAPE      → style-<name>        (padding / radius / density)
//   BASE COLOR → base-color-<name>   (neutral palette: bg / fg / muted / border)
//   THEME      → theme-<name>        (accent; overrides --primary). "none" = the
//                                     base color's own neutral primary.
//   FONT       → --font-sans (body) + --font-heading (heading, independent;
//                "inherit" follows the body), shadcn's body/heading split.
//   MODE       → .dark
// Keep shapes/baseColors/themes in sync with
// packages/gg_ui/src/gg_ui/styles/{shapes,base_colors,themes}; fonts in ./fonts.ts.
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
    fontBody: {
      description: "Body font family",
      toolbar: {
        title: "Font",
        icon: "paragraph",
        items: BODY_ITEMS,
        dynamicTitle: true,
      },
    },
    fontHeading: {
      description: "Heading font family (independent of body)",
      toolbar: {
        title: "Heading",
        icon: "bold",
        items: HEADING_ITEMS,
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
    // ICON SET / VARIANT — drive the demo-catalog stories (gallery, sizes,
    // button WithIcon). These are NOT static `globalTypes` toolbars: the variant
    // options depend on the selected set (which built-in toolbars can't express),
    // and a custom tool must render beside the set selector rather than in the
    // separate `globalTypes` cluster. Both selectors live in the manager addon
    // (`.storybook/manager.tsx`) — it reads/writes the `iconSet` / `iconVariant`
    // globals that stories forward into their `mount_*`, which call the typed
    // `demo_icons.render(set, variant, …)`. Their initial values live in
    // `initialGlobals` below.
    //
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
    fontBody: "geist",
    fontHeading: "inherit",
    mode: "light",
    iconSet: "lucide",
    iconVariant: "outline",
    runPlay: "off",
  },

  // Apply the axes to the story root. base-color + theme set the color tokens
  // (`--primary`, …); style-* carries the recipes. Tagging the root — the
  // popover's DOM ancestor — makes the cascade reach popover content in the top
  // layer. The root paints itself with the resolved tokens so dark mode and the
  // accent are visible on the canvas.
  decorators: [
    (story, context) => {
      const { shape, baseColor, theme, fontBody, fontHeading, mode } =
        context.globals as {
          shape: string
          baseColor: string
          theme: string
          fontBody: string
          fontHeading: string
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
      // FONT axis — override the gg_ui `--font-*` vars with the picked families
      // (null = leave the :root system-stack fallback). Body text inherits
      // --font-sans; headings opt into --font-heading via the `font-heading`
      // utility (independent — "inherit" makes it follow the body font).
      const body = resolveBody(fontBody)
      const heading = resolveHeading(fontHeading, fontBody)
      if (body) root.style.setProperty("--font-sans", body)
      if (heading) root.style.setProperty("--font-heading", heading)
      root.style.setProperty("font-family", "var(--font-sans)")
      root.style.setProperty("padding", "3rem")
      root.style.setProperty("border-radius", "0.5rem")
      return root
    },
  ],
}

export default preview
