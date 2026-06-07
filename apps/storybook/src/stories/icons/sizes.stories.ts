import type { Meta, StoryObj } from "@storybook/html-vite"
import { mountLustre } from "../../../.storybook/lustre-mount"
import { mount_size_playground, mount_size_scale } from "./sizes.gleam"

const sizes = ["default", "sm", "md", "lg"] as const

interface IconSizeArgs {
  size: (typeof sizes)[number]
}

/**
 * The typed `icon.Size` scale. `icon.size(Sm|Md|Lg)` emits a `cn-icon-size-*`
 * class whose `size-` token defeats a container's `:not([class*='size-'])`
 * auto-size; `default` emits no size class, so `.cn-icon`'s own default (size-4)
 * applies. Glyphs follow the **Icon set** / **Icon variant** toolbar globals.
 */
const meta: Meta<IconSizeArgs> = {
  title: "Icons/Sizes",
  args: { size: "md" },
  argTypes: {
    size: {
      control: { type: "select" },
      options: sizes,
      description:
        "Typed icon size. 'default' applies no size class — the .cn-icon " +
        "container default (size-4) wins.",
    },
  },
}

export default meta

type Story = StoryObj<IconSizeArgs>

/** Pick a size from the control; the sample glyph re-renders at that size. */
export const Playground: Story = {
  render: ({ size }, { globals }) => {
    const { iconSet, iconVariant } = globals as {
      iconSet: string
      iconVariant: string
    }
    return mountLustre((selector) =>
      mount_size_playground(selector, size, iconSet, iconVariant),
    )
  },
}

/** The whole scale at once — default, sm, md, lg — for visual comparison. */
export const Scale: Story = {
  parameters: { controls: { disable: true } },
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
