import type { Meta, StoryObj } from "@storybook/html-vite"
import { expect, userEvent, waitFor, within } from "storybook/test"
import { mountLustre } from "../../../.storybook/lustre-mount"
import {
  type ButtonSizeArg,
  type ButtonVariantArg,
  buttonVariantSizeArgTypes,
} from "../shared/button-controls"
import {
  mount_basic,
  mount_imperative,
  mount_scroll_collision,
  mount_terse,
} from "./popover.gleam"

// `@vitest/browser/context` is a *virtual* module: it only exists when Vitest
// runs the story in Browser Mode (it sets `globalThis.__vitest_browser__`). The
// physical file on disk throws at import time, so a top-level import would crash
// the story in the Storybook dev UI (which evaluates the module and runs `play`
// in the Interactions panel). Load it lazily, only when that flag is set.
declare global {
  // `var` is required to augment `globalThis`; `let`/`const` don't work here.
  var __vitest_browser__: boolean | undefined
}

const inVitestBrowser = (): boolean => globalThis.__vitest_browser__ === true

async function browserUserEvent() {
  const { userEvent } = await import("@vitest/browser/context")
  return userEvent
}

// Native Invoker Commands (`command="toggle-popover"`) reflect the trigger's
// disclosure state in the **accessibility tree** (the AX `expanded` property),
// NOT as a literal `aria-expanded` DOM attribute — that attribute stays at its
// static SSR seed value (`"false"`). The redesign deleted the old `popover_ffi`
// observer that used to mirror state onto the attribute and now trusts the
// platform; screen readers read the AX tree, so disclosure state is verified
// there, over CDP. Browser-mode only — the `@vitest/browser/context` `cdp()`
// virtual module doesn't exist in the Storybook dev UI.
interface AXNode {
  role?: { value?: string }
  name?: { value?: string }
  properties?: Array<{ name: string; value?: { value?: unknown } }>
}

interface FrameTreeNode {
  frame: { id: string }
  childFrames?: FrameTreeNode[]
}

// The AX `expanded` state for a button matching `name`. The Storybook story
// renders inside a preview iframe, and `Accessibility.getFullAXTree` is
// per-frame, so we walk every frame (main + descendants) and search each tree.
async function triggerExpanded(name: RegExp): Promise<boolean | undefined> {
  const { cdp } = await import("@vitest/browser/context")
  const session = cdp() as unknown as {
    send(method: string, params?: unknown): Promise<unknown>
  }
  await session.send("Accessibility.enable")
  await session.send("Page.enable")
  const { frameTree } = (await session.send("Page.getFrameTree")) as {
    frameTree: FrameTreeNode
  }
  const frameIds: string[] = []
  const collect = (node: FrameTreeNode) => {
    frameIds.push(node.frame.id)
    node.childFrames?.forEach(collect)
  }
  collect(frameTree)

  for (const frameId of frameIds) {
    const { nodes } = (await session.send("Accessibility.getFullAXTree", {
      frameId,
    })) as { nodes: AXNode[] }
    const node = nodes.find(
      (n) =>
        n.role?.value === "button" &&
        typeof n.name?.value === "string" &&
        name.test(n.name.value),
    )
    if (node) {
      const expanded = node.properties?.find((p) => p.name === "expanded")
      return expanded?.value?.value as boolean | undefined
    }
  }
  return undefined
}

// Mirror the Gleam `Placement` variants (`gg_ui/core/positioning`). The Gleam
// `parse_placement` lowercases these back into `Side`/`Align`.
const sides = ["top", "right", "bottom", "left"] as const
const aligns = ["start", "center", "end"] as const

interface PopoverArgs {
  side: (typeof sides)[number]
  align: (typeof aligns)[number]
  arrow: boolean
  variant: ButtonVariantArg
  size: ButtonSizeArg
}

const meta: Meta<PopoverArgs> = {
  title: "Components/Popover",
  // Trigger defaults to shadcn's outline/medium; the Basic story wires the
  // variant/size controls (shared with the Button stories) to the trigger.
  args: {
    side: "bottom",
    align: "center",
    arrow: false,
    variant: "outline",
    size: "default",
  },
  argTypes: {
    side: {
      control: { type: "select" },
      options: sides,
      description: "Which side of the trigger the panel opens on.",
    },
    align: {
      control: { type: "inline-radio" },
      options: aligns,
      description: "How the panel aligns along the trigger's cross axis.",
    },
    arrow: {
      control: { type: "boolean" },
      description: "Render the decorative arrow tail pointing at the trigger.",
    },
    ...buttonVariantSizeArgTypes,
  },
}

export default meta

type Story = StoryObj<PopoverArgs>

// Storybook's Interactions addon auto-runs `play` whenever a story is *viewed*
// in the dev UI — so these interaction tests would open/close/move the popover
// on every visit (the visible flicker). Gate them so they run only when they
// should:
//   - always under Vitest Browser Mode (`__vitest_browser__`), so tests run;
//   - in the dev UI only when the "Play" toolbar toggle is on, which lets you
//     run/replay the interaction on demand (flipping it re-renders → play runs).
// Otherwise the play is a no-op and the rendered component is left calm to look
// at and interact with by hand.
const testOnly =
  (fn: NonNullable<Story["play"]>): NonNullable<Story["play"]> =>
  async (context) => {
    if (inVitestBrowser() || context.globals.runPlay === "on") {
      await fn(context)
    }
  }

// The positioned popup is the element carrying the native `popover` attribute
// (styled `.cn-popover-positioner`); it's the node that flips to `:popover-open`
// and carries `data-side`. It lives in the DOM at its authored position (and is
// promoted to the top layer when open), so it's reachable from `canvasElement`.
const CONTENT = "[popover]"

function popup(canvasElement: HTMLElement): HTMLElement {
  const el = canvasElement.querySelector<HTMLElement>(CONTENT)
  if (!el) throw new Error("popover content not mounted")
  return el
}

// --- shadcn examples (reproduce ui.shadcn.com/docs/components/base/popover) --

/** Outline trigger + a header with title and description. */
export const Basic: Story = {
  render: ({ side, align, arrow, variant, size }, { globals }) => {
    const { iconSet, iconVariant } = globals as {
      iconSet: string
      iconVariant: string
    }
    return mountLustre((selector) =>
      mount_basic(
        selector,
        side,
        align,
        arrow,
        variant,
        size,
        iconSet,
        iconVariant,
      ),
    )
  },
  // Declarative open: clicking the Invoker Command button
  // (`command="toggle-popover"`) opens the popup and the browser flips the
  // trigger's `aria-expanded` natively — no JS observer involved. Then Escape
  // light-dismisses the `auto` popover, flipping it back. Escape light-dismiss
  // is UA behavior gated on *trusted* key events, so it needs the browser-backed
  // `userEvent` (the `storybook/test` one dispatches synthetic, untrusted keys).
  play: testOnly(async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    const trigger = await canvas.findByRole("button", {
      name: /open popover/i,
    })
    // Our code seeds the static wiring: the Invoker Command association
    // (`command="toggle-popover"`), `aria-haspopup` (the native API doesn't set
    // it), and a closed-state `aria-expanded` seed. Native invoker behavior
    // owns disclosure state from here — see `triggerExpanded`.
    await expect(trigger).toHaveAttribute("command", "toggle-popover")
    await expect(trigger).toHaveAttribute("aria-haspopup", "dialog")
    await expect(trigger).toHaveAttribute("aria-expanded", "false")

    await userEvent.click(trigger)
    const content = popup(canvasElement)
    await waitFor(() => expect(content.matches(":popover-open")).toBe(true))

    // The Escape close path and the AX-tree disclosure checks both need the
    // browser-backed APIs from `@vitest/browser/context` (trusted `userEvent`,
    // `cdp()`) — a virtual module that exists only under Vitest Browser Mode.
    // When play runs manually in the dev UI (Play: on), that module isn't
    // available, so stop here: the popover stays open for viewing.
    if (!inVitestBrowser()) return

    // Disclosure state lives in the AX tree, not the DOM attribute — the
    // platform flips it to expanded with no observer FFI present.
    await waitFor(async () =>
      expect(await triggerExpanded(/open popover/i)).toBe(true),
    )

    const browserUser = await browserUserEvent()
    await browserUser.keyboard("{Escape}")
    await waitFor(() => expect(content.matches(":popover-open")).toBe(false))
    await waitFor(async () =>
      expect(await triggerExpanded(/open popover/i)).toBe(false),
    )
  }),
}

/**
 * Terse `popover.popover` API at its simplest: just a trigger + content
 * children, everything else defaulted via `popover.options()` (auto id,
 * bottom/end placement, no arrow, light-dismiss). No controls — it's the
 * all-defaults call. Verifies the hidden wiring still produces a working
 * trigger (Invoker Command + haspopup) and that clicking it opens the content.
 */
export const TerseApi: Story = {
  name: "Terse API",
  render: ({ side, align, arrow }) =>
    mountLustre((selector) => mount_terse(selector, side, align, arrow)),
  play: testOnly(async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    const trigger = await canvas.findByRole("button", {
      name: /open popover/i,
    })
    await expect(trigger).toHaveAttribute("command", "toggle-popover")
    await expect(trigger).toHaveAttribute("aria-haspopup", "dialog")

    await userEvent.click(trigger)
    const content = popup(canvasElement)
    await waitFor(() => expect(content.matches(":popover-open")).toBe(true))
    // The content box is labelled/described by the composable title/description
    // the callback returned — proof the hidden aria wiring resolved by id.
    await expect(content).toHaveAttribute("aria-labelledby")
    await expect(content).toHaveAttribute("aria-describedby")
  }),
}

// --- reverse-engineered extras ----------------------------------------------

/**
 * Imperative capabilities on a plain native popover: external (non-trigger)
 * buttons drive the popover via the **command** effects (`popover.open` /
 * `close` / `toggle`), and the **observe** capability
 * (`on_toggle: Some(PopoverOpenChanged)`) mirrors the native `toggle` event
 * into the host's `Bool` so the label tracks real state. The pattern combobox
 * widgets use when typing or focus should open the popup.
 */
export const Imperative: Story = {
  render: ({ side, align }, { globals }) => {
    const { iconSet, iconVariant } = globals as {
      iconSet: string
      iconVariant: string
    }
    return mountLustre((selector) =>
      mount_imperative(selector, side, align, iconSet, iconVariant),
    )
  },
  // Each external button dispatches a Gleam msg whose effect calls the matching
  // FFI command — `showPopover` / `hidePopover` / `togglePopover`. Exercise all
  // three: open, close, then toggle (open) and toggle (close).
  play: testOnly(async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    const openBtn = await canvas.findByRole("button", {
      name: /open from outside/i,
    })
    const closeBtn = await canvas.findByRole("button", {
      name: /close from outside/i,
    })
    const toggleBtn = await canvas.findByRole("button", {
      name: /toggle from outside/i,
    })
    const content = await waitFor(() => popup(canvasElement))

    await userEvent.click(openBtn) // popover.open → showPopover
    await waitFor(() => expect(content.matches(":popover-open")).toBe(true))

    await userEvent.click(closeBtn) // popover.close → hidePopover
    await waitFor(() => expect(content.matches(":popover-open")).toBe(false))

    await userEvent.click(toggleBtn) // popover.toggle → togglePopover (open)
    await waitFor(() => expect(content.matches(":popover-open")).toBe(true))

    await userEvent.click(toggleBtn) // popover.toggle → togglePopover (close)
    await waitFor(() => expect(content.matches(":popover-open")).toBe(false))
  }),
}

/**
 * Arrow tail. Opening the popup fires `toggle`, which the arrow's
 * resolved-side observer (`arrow_ffi`) uses to recompute the popup's
 * `data-side` from the live trigger/popup rects. The arrow's geometry,
 * placement, and offset are all CSS keyed on that `data-side` (see
 * `styles/shapes/arrow.css`), so flipping the one attribute swaps the whole
 * caret. Forcing `side="top"` near the top of the canvas makes
 * `position-try-fallbacks` flip it to the bottom, exercising that swap.
 */
export const WithArrow: Story = {
  args: { side: "top", arrow: true },
  parameters: { controls: { disable: true } },
  render: ({ side, align, arrow, variant, size }, { globals }) => {
    const { iconSet, iconVariant } = globals as {
      iconSet: string
      iconVariant: string
    }
    return mountLustre((selector) =>
      mount_basic(
        selector,
        side,
        align,
        arrow,
        variant,
        size,
        iconSet,
        iconVariant,
      ),
    )
  },
  play: testOnly(async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    const trigger = await canvas.findByRole("button", {
      name: /open popover/i,
    })

    await userEvent.click(trigger)
    const content = popup(canvasElement)
    await waitFor(() => expect(content.matches(":popover-open")).toBe(true))

    // The arrow renders inside the popup and tracks the resolved side.
    const arrow = content.querySelector<SVGElement>("[data-arrow]")
    await expect(arrow).not.toBeNull()
    await waitFor(() =>
      expect(content.getAttribute("data-side")).toMatch(/top|bottom/),
    )
  }),
}

/**
 * Position-try collision demo: an oversized inner grid forces the Storybook
 * canvas iframe to scroll natively in both axes. The popup uses
 * `popover="manual"` so scrolling/clicking won't dismiss it; native
 * `position-try-fallbacks: flip-block, flip-inline` then flips the popup as
 * the trigger approaches each iframe edge.
 *
 * Uses `layout: 'fullscreen'` so Storybook doesn't center/flex the body
 * (which would otherwise hide the oversized content and prevent the iframe
 * from scrolling naturally).
 */
export const ScrollCollision: Story = {
  args: { side: "top", arrow: true },
  // Keep the controls panel (side / align / arrow) — this is an interactive
  // collision playground, not a fixed showcase. The `play` below runs against
  // the default `args`, so enabling controls doesn't affect the test.
  parameters: { layout: "fullscreen" },
  render: ({ side, align, arrow }, { globals }) => {
    const { iconSet, iconVariant } = globals as {
      iconSet: string
      iconVariant: string
    }
    return mountLustre((selector) =>
      mount_scroll_collision(
        selector,
        side,
        align,
        arrow,
        iconSet,
        iconVariant,
      ),
    )
  },
  play: testOnly(async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    const trigger = await canvas.findByRole("button", {
      name: /open popover/i,
    })
    // The popup opens on mount (after centering) — no click needed. Wait for the
    // open + resolved side to settle before asserting the start state.
    const content = popup(canvasElement)
    await waitFor(() => expect(content.matches(":popover-open")).toBe(true))
    await waitFor(() => expect(content).toHaveAttribute("data-side", "top"))

    const scroller = canvasElement.querySelector<HTMLElement>(
      "#story-scroll-canvas",
    )
    if (!scroller) throw new Error("scroll container not found")
    // Push the trigger to the very top of the viewport (the scroller is
    // `fixed inset-0`, so its top edge is the viewport top) so a `top` popup
    // can no longer fit and `position-try-fallbacks` must flip it to bottom.
    scroller.scrollBy({
      top: trigger.getBoundingClientRect().top - 2,
      left: 0,
    })

    await waitFor(
      () => expect(content).toHaveAttribute("data-side", "bottom"),
      { timeout: 4000 },
    )
  }),
}
