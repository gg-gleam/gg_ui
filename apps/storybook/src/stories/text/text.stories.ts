import type { Meta, StoryObj } from "@storybook/html-vite"
import { mountLustre } from "../../../.storybook/lustre-mount"
import {
  mount_as_element,
  mount_colors,
  mount_scale,
  mount_text_playground,
  mount_weights,
} from "./text.gleam"

// The styled `Text` component (gg_ui/ui/text) — gg_ui's typed, tokenized
// typography, a deliberate divergence from shadcn's no-component recipes.
// `Playground` is the kitchen sink: every tokenized axis as a control (the
// Latitude `Text` prop set, but typed). Compare with `Components/Typography`
// (the docs-only recipe page). See dev-docs/typography.md.

interface TextArgs {
  style: string
  color: string
  weight: string
  align: string
  transform: string
  decoration: string
  italic: boolean
  truncate: string
  lines: number
  whitespace: string
  wordBreak: string
  wrap: string
  opacity: string
  selectable: boolean
  content: string
}

const select = (options: readonly string[]) => ({
  control: { type: "select" } as const,
  options,
})

const meta: Meta<TextArgs> = {
  title: "Components/Text",
  args: {
    style: "s6",
    color: "foreground",
    weight: "normal",
    align: "start",
    transform: "none",
    decoration: "none",
    italic: false,
    truncate: "none",
    lines: 2,
    whitespace: "normal",
    wordBreak: "normal",
    wrap: "normal",
    opacity: "100",
    selectable: true,
    content:
      "The quick brown fox jumps over the lazy dog, and then keeps on running well past the edge of the line.",
  },
  argTypes: {
    style: select(["s1", "s2", "s3", "s4", "s5", "s6", "s7"]),
    color: select(["foreground", "muted", "primary", "destructive"]),
    weight: select(["normal", "medium", "semibold", "bold"]),
    align: select(["start", "center", "end"]),
    transform: select(["none", "uppercase", "lowercase", "capitalize"]),
    decoration: select(["none", "underline", "line-through"]),
    italic: { control: { type: "boolean" } },
    truncate: select(["none", "ellipsis", "clamp"]),
    lines: { control: { type: "range", min: 1, max: 6, step: 1 } },
    whitespace: select(["normal", "nowrap", "pre", "pre-line", "pre-wrap"]),
    wordBreak: select(["normal", "break-all", "break-word", "keep-all"]),
    wrap: select(["normal", "balance", "pretty"]),
    opacity: select(["100", "90", "80", "70", "60", "50"]),
    selectable: { control: { type: "boolean" } },
    content: { control: { type: "text" } },
  },
}

export default meta

type Story = StoryObj<TextArgs>

/** Kitchen sink — drive every tokenized axis from the controls panel. */
export const Playground: Story = {
  render: (a) =>
    mountLustre((selector) =>
      mount_text_playground(
        selector,
        a.style,
        a.color,
        a.weight,
        a.align,
        a.transform,
        a.decoration,
        a.italic,
        a.truncate,
        a.lines,
        a.whitespace,
        a.wordBreak,
        a.wrap,
        a.opacity,
        a.selectable,
        a.content,
      ),
    ),
}

/** The closed type scale — every `Style` member, labeled. */
export const Scale: Story = {
  parameters: { controls: { disable: true } },
  render: () => mountLustre(mount_scale),
}

/** The orthogonal Color axis (Foreground / Muted / Primary / Destructive). */
export const Colors: Story = {
  parameters: { controls: { disable: true } },
  render: () => mountLustre(mount_colors),
}

/** The orthogonal Weight axis — nothing is bold by default; emphasis is opt-in. */
export const Weights: Story = {
  parameters: { controls: { disable: true } },
  render: () => mountLustre(mount_weights),
}

/** Element-agnostic styling: an H1 look on a semantic `<h3>` (the asChild
 *  analogue), via `text.attributes`. */
export const AsElement: Story = {
  parameters: { controls: { disable: true } },
  render: () => mountLustre(mount_as_element),
}
