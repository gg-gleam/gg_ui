import type { Meta, StoryObj } from "@storybook/html-vite"
import { mountLustre } from "../../../.storybook/lustre-mount"
import { mount_gallery } from "./gallery.gleam"

/**
 * The curated demo catalog (~20 typical UI glyphs). This is Storybook treated as
 * a real consumer: the gallery imports the concrete `gg_icons_*` sets through a
 * typed, manifest-validated catalog (see `demo_icons.gleam`) — it does NOT run
 * the CLI transformer (that's for ejected user code). Flip the **Icon set** /
 * **Icon variant** toolbar dropdowns to switch every glyph live.
 *
 * lucide is single-variant (ignores Icon variant); under Tabler + Filled the two
 * stroke-only glyphs (`menu`, `arrow-right`) fall back to outline by design.
 */
const meta: Meta = {
  title: "Icons/Gallery",
  parameters: {
    layout: "fullscreen",
    controls: { disable: true },
  },
}

export default meta

type Story = StoryObj

export const Gallery: Story = {
  render: (_args, { globals }) => {
    const { iconSet, iconVariant } = globals as {
      iconSet: string
      iconVariant: string
    }
    return mountLustre((selector) =>
      mount_gallery(selector, iconSet, iconVariant),
    )
  },
}
