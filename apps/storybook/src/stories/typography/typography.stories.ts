import type { Meta, StoryObj } from "@storybook/html-vite"
import { mountLustre } from "../../../.storybook/lustre-mount"
import { mount_elements, mount_overview, mount_roles } from "./typography.gleam"

// Typography ships no component (shadcn's model) — these are showcase stories
// for the utility-class recipes. They take no args; the **Font** toolbar
// (sans / editorial / mono) plus Shape / Base color / Theme / Mode drive them.
// See dev-docs/typography.md.
const meta: Meta = {
  title: "Components/Typography",
  parameters: { controls: { disable: true } },
}

export default meta

type Story = StoryObj

/** The full specimen — every recipe in context. */
export const Overview: Story = {
  render: () => mountLustre(mount_overview),
}

/** Each block-level element, labeled, for isolated review. */
export const Elements: Story = {
  render: () => mountLustre(mount_elements),
}

/** The semantic text roles (Lead / Large / Small / Muted) — the shared scale
 *  that component internals reuse. */
export const Roles: Story = {
  render: () => mountLustre(mount_roles),
}
