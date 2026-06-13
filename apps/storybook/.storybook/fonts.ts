// Font families for the Storybook demo — the *consumer* side of the typography
// story. The library (gg_ui) ships NO fonts; it only exposes the `--font-sans` /
// `--font-heading` / `--font-mono` custom props (tokens.css). Here, the demo app
// loads real variable faces and the Font / Heading toolbars set those vars from
// the families below. This mirrors shadcn's font-family picker (a body font + an
// independent heading font), not an abstract "type set".
//
// Loading: `@fontsource-variable/*` (self-hosted). NOTE this is *not* how
// shadcn's docs site loads fonts — that's a Next app and uses `next/font/google`
// (its `@fontsource` names are just metadata + a non-Next template). We're a
// Vite/Storybook app, so `next/font` isn't an option, and a Google-Fonts CDN
// link would break the offline/deterministic vitest-browser run. `@fontsource`
// is the standard self-hosting route here (and what shadcn's own non-Next
// template uses). Importing a package injects its `@font-face` rules; eager
// import makes every family available to CSS up front.
import "@fontsource-variable/geist"
import "@fontsource-variable/inter"
import "@fontsource-variable/dm-sans"
import "@fontsource-variable/figtree"
import "@fontsource-variable/space-grotesk"
import "@fontsource-variable/playfair-display"
import "@fontsource-variable/lora"
import "@fontsource-variable/jetbrains-mono"
import "@fontsource-variable/geist-mono"

type FontType = "sans" | "serif" | "mono"

export interface FontFamily {
  /** Toolbar value (kebab-case, matches the @fontsource package name). */
  value: string
  /** Toolbar label. */
  title: string
  type: FontType
  /** The full `font-family` stack written to the CSS var. */
  family: string
}

// Per-type generic fallback appended after the variable face.
const FALLBACK: Record<FontType, string> = {
  sans: "ui-sans-serif, system-ui, sans-serif",
  serif: "ui-serif, Georgia, serif",
  mono: "ui-monospace, SFMono-Regular, Menlo, monospace",
}

function family(name: string, type: FontType): string {
  return `'${name}', ${FALLBACK[type]}`
}

// The catalogue — a curated cross-section of shadcn's list (sans / serif / mono).
export const FONT_FAMILIES: readonly FontFamily[] = [
  {
    value: "geist",
    title: "Geist",
    type: "sans",
    family: family("Geist Variable", "sans"),
  },
  {
    value: "inter",
    title: "Inter",
    type: "sans",
    family: family("Inter Variable", "sans"),
  },
  {
    value: "dm-sans",
    title: "DM Sans",
    type: "sans",
    family: family("DM Sans Variable", "sans"),
  },
  {
    value: "figtree",
    title: "Figtree",
    type: "sans",
    family: family("Figtree Variable", "sans"),
  },
  {
    value: "space-grotesk",
    title: "Space Grotesk",
    type: "sans",
    family: family("Space Grotesk Variable", "sans"),
  },
  {
    value: "playfair-display",
    title: "Playfair Display",
    type: "serif",
    family: family("Playfair Display Variable", "serif"),
  },
  {
    value: "lora",
    title: "Lora",
    type: "serif",
    family: family("Lora Variable", "serif"),
  },
  {
    value: "jetbrains-mono",
    title: "JetBrains Mono",
    type: "mono",
    family: family("JetBrains Mono Variable", "mono"),
  },
  {
    value: "geist-mono",
    title: "Geist Mono",
    type: "mono",
    family: family("Geist Mono Variable", "mono"),
  },
] as const

// Sentinel values for the toolbars.
export const SYSTEM = "system" // body: the gg_ui :root fallback stacks
export const INHERIT = "inherit" // heading: follow the body font

const FAMILY_BY_VALUE = new Map(FONT_FAMILIES.map((f) => [f.value, f.family]))

/**
 * Resolve a Body-font toolbar value to a `font-family` string, or `null` for
 * `system` (let the gg_ui `:root` fallback win — no override).
 */
export function resolveBody(value: string): string | null {
  if (value === SYSTEM) return null
  return FAMILY_BY_VALUE.get(value) ?? null
}

/**
 * Resolve a Heading-font toolbar value. `inherit` follows the resolved body
 * font; otherwise the picked family. Returns `null` to leave the var unset.
 */
export function resolveHeading(
  value: string,
  bodyValue: string,
): string | null {
  if (value === INHERIT) return resolveBody(bodyValue)
  return FAMILY_BY_VALUE.get(value) ?? null
}

// Toolbar item lists.
export const BODY_ITEMS = [
  { value: SYSTEM, title: "System" },
  ...FONT_FAMILIES.map((f) => ({ value: f.value, title: f.title })),
]

export const HEADING_ITEMS = [
  { value: INHERIT, title: "Inherit (body)" },
  ...FONT_FAMILIES.map((f) => ({ value: f.value, title: f.title })),
]
