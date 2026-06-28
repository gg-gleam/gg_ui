import type { Meta, StoryObj } from "@storybook/html-vite"
import { mountLustre } from "../../../.storybook/lustre-mount"
import {
  type ButtonSizeArg,
  type ButtonVariantArg,
  buttonVariantSizeArgTypes,
} from "../shared/button-controls"
import {
  mount_as_link,
  mount_class_override,
  mount_playground,
  mount_sizes,
  mount_variants,
  mount_with_icon,
} from "./button.gleam"

interface ButtonArgs {
  variant: ButtonVariantArg
  size: ButtonSizeArg
  disabled: boolean
}

const meta: Meta<ButtonArgs> = {
  title: "Components/Button",
  args: { variant: "default", size: "default", disabled: false },
  argTypes: {
    ...buttonVariantSizeArgTypes,
    disabled: { control: { type: "boolean" } },
  },
}

export default meta

type Story = StoryObj<ButtonArgs>

/** Drive variant / size / disabled live from the controls panel. Icon-only
 *  sizes use a real catalog glyph that follows the Icon set / variant globals. */
export const Playground: Story = {
  render: ({ variant, size, disabled }, { globals }) => {
    const { iconSet, iconVariant } = globals as {
      iconSet: string
      iconVariant: string
    }
    return mountLustre((selector) =>
      mount_playground(selector, variant, size, disabled, iconSet, iconVariant),
    )
  },
}

/** Every variant at the default size. */
export const Variants: Story = {
  parameters: { controls: { disable: true } },
  render: () => mountLustre(mount_variants),
}

/** Text sizes and icon sizes. The icon-only buttons use a real catalog glyph
 *  that follows the Icon set / variant toolbar globals. */
export const Sizes: Story = {
  parameters: { controls: { disable: true } },
  render: (_args, { globals }) => {
    const { iconSet, iconVariant } = globals as {
      iconSet: string
      iconVariant: string
    }
    return mountLustre((selector) =>
      mount_sizes(selector, iconSet, iconVariant),
    )
  },
}

/**
 * Icons sit inline with the label; the base class auto-sizes the `<svg>`. The
 * glyphs come from the demo catalog and follow the **Icon set** / **Icon
 * variant** toolbar globals — flip them to switch lucide ↔ tabler live.
 */
export const WithIcon: Story = {
  parameters: { controls: { disable: true } },
  render: (_args, { globals }) => {
    const { iconSet, iconVariant } = globals as {
      iconSet: string
      iconVariant: string
    }
    return mountLustre((selector) =>
      mount_with_icon(selector, iconSet, iconVariant),
    )
  },
}

/** The `classes` recipe applied to an `<a>` — the render / asChild pattern. */
export const AsLink: Story = {
  parameters: { controls: { disable: true } },
  render: () => mountLustre(mount_as_link),
}

/**
 * A caller `class` override resolved by tailwind-merge (the shadcn
 * `cn(variants({ className }))` model): `justify-between` *removes* the
 * component's default `justify-center`, so the label and arrow spread apart.
 */
export const ClassOverride: Story = {
  parameters: { controls: { disable: true } },
  render: (_args, { globals }) => {
    const { iconSet, iconVariant } = globals as {
      iconSet: string
      iconVariant: string
    }
    return mountLustre((selector) =>
      mount_class_override(selector, iconSet, iconVariant),
    )
  },
}
