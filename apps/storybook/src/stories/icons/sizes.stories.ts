import type { Meta, StoryObj } from "@storybook/html-vite"
import { mountLustre } from "../../../.storybook/lustre-mount"
import { mount_size_scale } from "./sizes.gleam"

/**
 * The typed `icon.Size` scale — default, sm, md, lg — laid out together as
 * boxless glyphs (same treatment as the gallery). `icon.size(Sm|Md|Lg)` emits a
 * `cn-icon-size-*` class whose `size-` token defeats a container's auto-size;
 * `default` emits no size class, so `.cn-icon`'s own default (size-4) applies.
 * Hover any glyph to see its size; glyphs follow the **Icon set** / **Icon
 * variant** toolbar globals.
 */
const meta: Meta = {
  title: "Icons/Sizes",
  parameters: { controls: { disable: true } },
}

export default meta

type Story = StoryObj

export const Scale: Story = {
  render: (_args, { globals }) => {
    const { iconSet, iconVariant } = globals as {
      iconSet: string
      iconVariant: string
    }
    return mountLustre((selector) =>
      mount_size_scale(selector, iconSet, iconVariant),
    )
  },
}
