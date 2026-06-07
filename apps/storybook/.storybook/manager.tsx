// Manager-side addon: the "Icon set" + "Icon variant" toolbar selectors,
// rendered together as an adjacent pair. They live here (not in preview.ts
// `globalTypes`) for two reasons:
//
//   1. The variant options DEPEND on the selected set, which built-in static
//      `globalTypes` toolbars can't express:
//        lucide    → single-variant: the variant selector HIDES.
//        tabler    → outline | filled.
//        heroicons → outline | solid | mini | micro.
//   2. Custom TOOL addons render in the toolbar's left cluster, while
//      `globalTypes` toolbars render in the group after the separator — so a
//      `globalTypes` set + a custom variant tool end up far apart. Registering
//      BOTH here keeps them side by side.
//
// They read/write the same `iconSet` / `iconVariant` globals the stories thread
// into their `mount_*` (see stories/icons + preview.ts), so flipping either
// re-renders every icon-aware story live. When the active variant isn't valid
// for the selected set (e.g. you picked `micro`, then switched to tabler), the
// selector DISPLAYS the set's default — mirroring the Gleam catalog's own
// fallback-to-default in `demo_icons.render`, so toolbar and canvas always agree.

// Storybook's manager builder (esbuild) uses the CLASSIC JSX transform — JSX
// compiles to `React.createElement`, so `React` must be in scope at runtime even
// though it's never referenced by name. Biome assumes the automatic runtime and
// flags it as unused; the ignore keeps it.
// biome-ignore lint/correctness/noUnusedImports: classic JSX runtime needs React in scope
import React from "react"
import {
  IconButton,
  TooltipLinkList,
  WithTooltip,
} from "storybook/internal/components"
import { addons, types, useGlobals } from "storybook/manager-api"

const ADDON_ID = "gg-ui/icons"
const SET_TOOL_ID = `${ADDON_ID}/set`
const VARIANT_TOOL_ID = `${ADDON_ID}/variant`

type Option = { value: string; title: string }

const SETS: Option[] = [
  { value: "lucide", title: "Lucide" },
  { value: "tabler", title: "Tabler" },
  { value: "heroicons", title: "Heroicons" },
]

// Keep these in sync with each set's `icons.json` `variants` (the manifest is
// the source of truth) and with `demo_icons.IconVariant` on the Gleam side.
const VARIANTS_BY_SET: Record<string, Option[]> = {
  lucide: [{ value: "outline", title: "Outline" }],
  tabler: [
    { value: "outline", title: "Outline" },
    { value: "filled", title: "Filled" },
  ],
  heroicons: [
    { value: "outline", title: "Outline" },
    { value: "solid", title: "Solid" },
    { value: "mini", title: "Mini" },
    { value: "micro", title: "Micro" },
  ],
}

function variantsFor(set: string): Option[] {
  return VARIANTS_BY_SET[set] ?? VARIANTS_BY_SET.lucide
}

// A toolbar dropdown: a labelled button that opens a single-select link list.
function Dropdown(props: {
  id: string
  label: string
  options: Option[]
  value: string
  onSelect: (value: string) => void
}) {
  const { id, label, options, value, onSelect } = props
  const activeTitle = options.find((o) => o.value === value)?.title ?? value

  return (
    <WithTooltip
      placement="top"
      trigger="click"
      closeOnOutsideClick
      tooltip={({ onHide }: { onHide: () => void }) => (
        <TooltipLinkList
          links={options.map((o) => ({
            id: o.value,
            title: o.title,
            active: o.value === value,
            onClick: () => {
              onSelect(o.value)
              onHide()
            },
          }))}
        />
      )}
    >
      <IconButton key={id} title={label} active>
        <span style={{ fontSize: 11, fontWeight: 700 }}>
          {`${label}: ${activeTitle}`}
        </span>
      </IconButton>
    </WithTooltip>
  )
}

function IconSetTool() {
  const [globals, updateGlobals] = useGlobals()
  const set = (globals.iconSet as string) ?? "lucide"
  return (
    <Dropdown
      id={SET_TOOL_ID}
      label="Icons"
      options={SETS}
      value={set}
      onSelect={(value) => updateGlobals({ iconSet: value })}
    />
  )
}

function IconVariantTool() {
  const [globals, updateGlobals] = useGlobals()
  const set = (globals.iconSet as string) ?? "lucide"
  const variants = variantsFor(set)

  // Single-variant set → no choice to offer; hide the tool entirely.
  if (variants.length <= 1) {
    return null
  }

  const current = (globals.iconVariant as string) ?? variants[0].value
  // Display the set's default when the carried-over variant isn't valid here —
  // exactly what the Gleam render falls back to, so toolbar and canvas match.
  const active = variants.some((v) => v.value === current)
    ? current
    : variants[0].value

  return (
    <Dropdown
      id={VARIANT_TOOL_ID}
      label="Variant"
      options={variants}
      value={active}
      onSelect={(value) => updateGlobals({ iconVariant: value })}
    />
  )
}

const matchStoryOrDocs = ({ viewMode }: { viewMode?: string }) =>
  viewMode === "story" || viewMode === "docs"

addons.register(ADDON_ID, () => {
  // Registered consecutively → rendered adjacent (set first, variant next).
  addons.add(SET_TOOL_ID, {
    type: types.TOOL,
    title: "Icon set",
    match: matchStoryOrDocs,
    render: () => <IconSetTool />,
  })
  addons.add(VARIANT_TOOL_ID, {
    type: types.TOOL,
    title: "Icon variant",
    match: matchStoryOrDocs,
    render: () => <IconVariantTool />,
  })
})
