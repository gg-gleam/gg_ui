import type { Meta, StoryObj } from "@storybook/html-vite"
import { expect, waitFor, within } from "storybook/test"
import { mountLustre } from "../../../.storybook/lustre-mount"
import {
  type ButtonSizeArg,
  type ButtonVariantArg,
  buttonVariantSizeArgTypes,
} from "../shared/button-controls"
import {
  mount_icon,
  mount_sides,
  mount_terse,
  mount_tooltip_basic,
} from "./tooltip.gleam"

// `@vitest/browser/context` is a *virtual* module: it only exists when Vitest
// runs the story in Browser Mode (it sets `globalThis.__vitest_browser__`). A
// top-level import would crash the story in the Storybook dev UI, so load it
// lazily. Same pattern as the popover stories.
declare global {
  // `var` is required to augment `globalThis`.
  var __vitest_browser__: boolean | undefined
}

const inVitestBrowser = (): boolean => globalThis.__vitest_browser__ === true

async function browserUserEvent() {
  const { userEvent } = await import("@vitest/browser/context")
  return userEvent
}

// Interest invokers are bleeding-edge (Chromium 142+, behind no flag there but
// absent in Firefox/Safari and older Chromium). The static ARIA/wiring is always
// asserted; the *open on interest* behavior is asserted only when the running
// browser actually implements the API, so the suite stays green on engines that
// don't (the markup still renders, it just won't pop on hover).
const supportsInterestInvokers = (): boolean =>
  typeof HTMLButtonElement !== "undefined" &&
  "interestForElement" in HTMLButtonElement.prototype

const sides = ["top", "right", "bottom", "left"] as const
const aligns = ["start", "center", "end"] as const

interface TooltipArgs {
  side: (typeof sides)[number]
  align: (typeof aligns)[number]
  arrow: boolean
  delay: number
  variant: ButtonVariantArg
  size: ButtonSizeArg
}

const meta: Meta<TooltipArgs> = {
  title: "Components/Tooltip",
  args: {
    side: "top",
    align: "center",
    arrow: false,
    delay: 0,
    variant: "outline",
    size: "default",
  },
  argTypes: {
    side: {
      control: { type: "select" },
      options: sides,
      description: "Which side of the trigger the hint opens on.",
    },
    align: {
      control: { type: "inline-radio" },
      options: aligns,
      description: "How the hint aligns along the trigger's cross axis.",
    },
    arrow: {
      control: { type: "boolean" },
      description: "Render the decorative arrow pointing at the trigger.",
    },
    delay: {
      control: { type: "number", min: 0, max: 2000, step: 100 },
      description:
        "Open delay in ms (native interest-delay-start). Default 0 matches " +
        "shadcn's snappy reveal; bump it for a calmer, deliberate-hover feel.",
    },
    ...buttonVariantSizeArgTypes,
  },
}

export default meta

type Story = StoryObj<TooltipArgs>

// Gate interaction tests the same way the popover stories do: always under
// Vitest Browser Mode; in the dev UI only when the "Play" toolbar toggle is on.
const testOnly =
  (fn: NonNullable<Story["play"]>): NonNullable<Story["play"]> =>
  async (context) => {
    if (inVitestBrowser() || context.globals.runPlay === "on") {
      await fn(context)
    }
  }

// The hint is the element carrying the native `popover` attribute (styled
// `.cn-tooltip-positioner`); it flips to `:popover-open` and carries `data-side`.
const CONTENT = "[popover]"

function hint(canvasElement: HTMLElement): HTMLElement {
  const el = canvasElement.querySelector<HTMLElement>(CONTENT)
  if (!el) throw new Error("tooltip hint not mounted")
  return el
}

// Assert the static, universal wiring every tooltip emits regardless of browser
// support: the Interest Invoker association, the explicit aria-describedby that
// matches it, role="tooltip", and popover="hint".
async function expectWiring(canvasElement: HTMLElement, triggerName: RegExp) {
  const canvas = within(canvasElement)
  const trigger = await canvas.findByRole("button", { name: triggerName })
  const content = hint(canvasElement)
  await expect(trigger).toHaveAttribute("interestfor", content.id)
  await expect(trigger).toHaveAttribute("aria-describedby", content.id)
  await expect(content).toHaveAttribute("role", "tooltip")
  await expect(content).toHaveAttribute("popover", "hint")
  return trigger
}

/** Outline trigger + a short text hint. Hover or focus the trigger to show it. */
export const Basic: Story = {
  render: ({ side, align, arrow, delay, variant, size }) =>
    mountLustre((selector) =>
      mount_tooltip_basic(selector, side, align, arrow, variant, size, delay),
    ),
  play: testOnly(async ({ canvasElement }) => {
    const trigger = await expectWiring(canvasElement, /hover me/i)

    // Behavior — only where the platform implements interest invokers. Hovering
    // is "showing interest"; after the open delay the hint enters the top layer.
    if (!inVitestBrowser() || !supportsInterestInvokers()) return
    const content = hint(canvasElement)
    const user = await browserUserEvent()
    await user.hover(trigger)
    await waitFor(() => expect(content.matches(":popover-open")).toBe(true), {
      timeout: 2000,
    })
    // Moving interest away (hover the canvas backdrop) light-dismisses it.
    await user.hover(canvasElement)
    await waitFor(() => expect(content.matches(":popover-open")).toBe(false), {
      timeout: 2000,
    })
  }),
}

/**
 * Terse `tooltip.tooltip` at its simplest: a trigger label + the tip content,
 * everything else defaulted via `tooltip.options()` (auto id, top/center, Base
 * UI's 600ms delay). Verifies the hidden wiring still produces a working trigger.
 */
export const TerseApi: Story = {
  name: "Terse API",
  render: ({ side, align, arrow }) =>
    mountLustre((selector) => mount_terse(selector, side, align, arrow)),
  play: testOnly(async ({ canvasElement }) => {
    await expectWiring(canvasElement, /hover me/i)
  }),
}

/**
 * All four sides, each with an arrow. Hover any trigger — only one hint shows at
 * a time (native `popover="hint"` hides the others). The arrow's geometry is CSS
 * keyed on the resolved `data-side`, so it always points back at its trigger.
 */
export const Sides: Story = {
  parameters: { controls: { disable: true } },
  render: () => mountLustre(mount_sides),
}

/** Tooltip with the decorative arrow tail. */
export const WithArrow: Story = {
  args: { arrow: true, delay: 0 },
  parameters: { controls: { disable: true } },
  render: ({ side, align, arrow, delay, variant, size }) =>
    mountLustre((selector) =>
      mount_tooltip_basic(selector, side, align, arrow, variant, size, delay),
    ),
  play: testOnly(async ({ canvasElement }) => {
    await expectWiring(canvasElement, /hover me/i)
    // The arrow renders inside the hint and tracks the resolved side.
    const content = hint(canvasElement)
    const arrow = content.querySelector<SVGElement>("[data-arrow]")
    await expect(arrow).not.toBeNull()
  }),
}

/**
 * Icon-only trigger built from `trigger_attributes` on a small icon button — the
 * canonical "what does this do?" tooltip. The behavior attributes compose onto
 * any element, not just the styled `Button`.
 */
export const IconTrigger: Story = {
  name: "Icon trigger",
  parameters: { controls: { disable: true } },
  render: ({ side }) => mountLustre((selector) => mount_icon(selector, side)),
}
