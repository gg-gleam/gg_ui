import type { Meta, StoryObj } from "@storybook/html-vite"
import { expect, waitFor, within } from "storybook/test"
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
// headless layer. The fallback sits behind the image and is hidden once the
// image reports data-status=loaded (so a *transparent* image doesn't reveal the
// initials behind it); on load failure the observer hides the image instead and
// the fallback shows. We add an `xs` size and a shape axis (circle / rounded /
// squircle) on top of shadcn's circle-only avatar.

declare global {
  // `var` is required to augment `globalThis`; `let`/`const` don't work here.
  var __vitest_browser__: boolean | undefined
}
const inVitestBrowser = (): boolean => globalThis.__vitest_browser__ === true
const testOnly =
  (fn: NonNullable<Story["play"]>): NonNullable<Story["play"]> =>
  async (context) => {
    if (inVitestBrowser() || context.globals.runPlay === "on") {
      await fn(context)
    }
  }

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
  // Default args = a working (and transparent-capable) image. Once it loads the
  // root flips to data-status=loaded and the fallback must be hidden — otherwise
  // its initials bleed through a transparent image (the regression this guards).
  play: testOnly(async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    const root = canvasElement.querySelector<HTMLElement>(
      "[data-slot='avatar']",
    )
    if (!root) throw new Error("avatar root not mounted")
    await waitFor(() => expect(root.dataset.status).toBe("loaded"), {
      timeout: 2000,
    })
    const fallback = canvas.getByText("CN")
    expect(fallback).not.toBeVisible()
  }),
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
