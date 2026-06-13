import type { Meta, StoryObj } from "@storybook/html-vite"
import { mountLustre } from "../../../.storybook/lustre-mount"
import { mount_as_element, mount_colors, mount_scale } from "./text.gleam"

// The styled `Text` component (gg_ui/ui/text) — gg_ui's typed, tokenized
// typography, a deliberate divergence from shadcn's no-component recipes.
// Compare with `Components/Typography` (the docs-only recipe page). No args:
// the Shape / Base color / Theme / Font / Mode toolbars drive these.
// See dev-docs/typography.md.
const meta: Meta = {
  title: "Components/Text",
  parameters: { controls: { disable: true } },
}

export default meta

type Story = StoryObj

/** The closed type scale — every `Style` member, labeled. */
export const Scale: Story = {
  render: () => mountLustre(mount_scale),
}

/** The orthogonal Color axis (Foreground / Muted / Primary / Destructive). */
export const Colors: Story = {
  render: () => mountLustre(mount_colors),
}

/** Element-agnostic styling: an H3 look on a semantic `<h2>` (the asChild
 *  analogue), via `text.attributes`. */
export const AsElement: Story = {
  render: () => mountLustre(mount_as_element),
}
