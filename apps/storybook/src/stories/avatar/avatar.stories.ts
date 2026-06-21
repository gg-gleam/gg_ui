import type { Meta, StoryObj } from "@storybook/html-vite"
import { mountLustre } from "../../../.storybook/lustre-mount"
import {
  mount_avatar_badge,
  mount_avatar_fallbacks,
  mount_avatar_group,
  mount_avatar_menu,
  mount_avatar_playground,
  mount_avatar_shapes,
  mount_avatar_sizes,
} from "./avatar.gleam"

// Avatar — shadcn's Avatar / AvatarImage / AvatarFallback over the native-first
// headless layer. The image is stacked over the fallback; on load failure the
// observer hides it and the fallback shows through. We add an `xs` size and a
// shape axis (circle / rounded / squircle) on top of shadcn's circle-only avatar.

const sizes = ["xs", "sm", "default", "lg"] as const
const shapes = ["circle", "rounded", "squircle"] as const

type AvatarArgs = {
  size: (typeof sizes)[number]
  shape: (typeof shapes)[number]
  broken: boolean
  initials: string
}

const meta: Meta<AvatarArgs> = {
  title: "Components/Avatar",
  args: { size: "default", shape: "circle", broken: false, initials: "CN" },
  argTypes: {
    size: { control: { type: "select" }, options: sizes },
    shape: { control: { type: "select" }, options: shapes },
    broken: { control: { type: "boolean" } },
    initials: { control: { type: "text" } },
  },
}
export default meta
type Story = StoryObj<AvatarArgs>

// Controls-driven: pick size + shape, toggle `broken` to force the fallback.
export const Playground: Story = {
  render: ({ size, shape, broken, initials }) =>
    mountLustre((selector) =>
      mount_avatar_playground(selector, size, shape, broken, initials),
    ),
}

export const Sizes: Story = {
  parameters: { controls: { disable: true } },
  render: () => mountLustre(mount_avatar_sizes),
}

export const Shapes: Story = {
  parameters: { controls: { disable: true } },
  render: () => mountLustre(mount_avatar_shapes),
}

export const Fallbacks: Story = {
  parameters: { controls: { disable: true } },
  render: () => mountLustre(mount_avatar_fallbacks),
}

export const Badge: Story = {
  parameters: { controls: { disable: true } },
  render: () => mountLustre(mount_avatar_badge),
}

export const Group: Story = {
  parameters: { controls: { disable: true } },
  render: () => mountLustre(mount_avatar_group),
}

export const Menu: Story = {
  name: "Avatar + popover",
  parameters: { controls: { disable: true } },
  render: () => mountLustre(mount_avatar_menu),
}
