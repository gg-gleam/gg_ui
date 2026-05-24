import type { Meta, StoryObj } from "@storybook/html-vite"
import { mountLustre } from "../../../.storybook/lustre-mount"
import {
  type ButtonSizeArg,
  type ButtonVariantArg,
  buttonVariantSizeArgTypes,
} from "../shared/button-controls"
import {
  mount_as_link,
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

/** Drive variant / size / disabled live from the controls panel. */
export const Playground: Story = {
  render: ({ variant, size, disabled }) =>
    mountLustre((selector) =>
      mount_playground(selector, variant, size, disabled),
    ),
}

/** Every variant at the default size. */
export const Variants: Story = {
  parameters: { controls: { disable: true } },
  render: () => mountLustre(mount_variants),
}

/** Text sizes and icon sizes. */
export const Sizes: Story = {
  parameters: { controls: { disable: true } },
  render: () => mountLustre(mount_sizes),
}

/** Icons sit inline with the label; the base class auto-sizes the `<svg>`. */
export const WithIcon: Story = {
  parameters: { controls: { disable: true } },
  render: () => mountLustre(mount_with_icon),
}

/** The `classes` recipe applied to an `<a>` — the render / asChild pattern. */
export const AsLink: Story = {
  parameters: { controls: { disable: true } },
  render: () => mountLustre(mount_as_link),
}
