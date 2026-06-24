import type { Meta, StoryObj } from "@storybook/html-vite"
import { expect, userEvent, waitFor, within } from "storybook/test"
import { mountLustre } from "../../../.storybook/lustre-mount"
import {
  type ButtonSizeArg,
  type ButtonVariantArg,
  buttonVariantSizeArgTypes,
} from "../shared/button-controls"
import {
  mount_dialog_close_button,
  mount_dialog_demo,
  mount_dialog_lazy_content,
  mount_dialog_no_close_button,
  mount_dialog_playground,
  mount_dialog_rtl,
  mount_dialog_scrollable,
  mount_dialog_sticky_footer,
} from "./dialog.gleam"

// `@vitest/browser/context` is a *virtual* module: it only exists when Vitest
// runs the story in Browser Mode (it sets `globalThis.__vitest_browser__`). The
// physical file on disk throws at import time, so a top-level import would crash
// the story in the Storybook dev UI. Load it lazily, only when that flag is set.
declare global {
  // `var` is required to augment `globalThis`; `let`/`const` don't work here.
  var __vitest_browser__: boolean | undefined
}

const inVitestBrowser = (): boolean => globalThis.__vitest_browser__ === true

async function browserUserEvent() {
  const { userEvent } = await import("@vitest/browser/context")
  return userEvent
}

const dismisses = ["light-dismiss", "close-request", "manual"] as const
const roles = ["standard", "alert"] as const

interface DialogArgs {
  text: string
  dismiss: (typeof dismisses)[number]
  role: (typeof roles)[number]
  closeButton: boolean
  variant: ButtonVariantArg
  size: ButtonSizeArg
}

const meta: Meta<DialogArgs> = {
  title: "Components/Dialog",
  // The Playground binds every `dialog.Options` field to a control: the trigger
  // label (`text`), the `closedby` policy (`dismiss`), the `role`, the built-in
  // corner ✕ (`closeButton`), and the trigger's variant/size (shared with the
  // Button stories). Trigger defaults to shadcn's outline/medium.
  args: {
    text: "Open dialog",
    dismiss: "light-dismiss",
    role: "standard",
    closeButton: true,
    variant: "outline",
    size: "default",
  },
  argTypes: {
    text: {
      control: { type: "text" },
      description: "The trigger button's label (`Options.text`).",
    },
    dismiss: {
      control: { type: "inline-radio" },
      options: dismisses,
      description:
        "Native `closedby`: light-dismiss (backdrop + Esc), close-request (Esc only), or manual (host-owned).",
    },
    role: {
      control: { type: "inline-radio" },
      options: roles,
      description:
        "`standard` <dialog> vs `alertdialog` for consequential actions.",
    },
    closeButton: {
      control: { type: "boolean" },
      description: "Render the built-in corner ✕ close button.",
    },
    ...buttonVariantSizeArgTypes,
  },
}

export default meta

type Story = StoryObj<DialogArgs>

// Storybook's Interactions addon auto-runs `play` whenever a story is *viewed*
// in the dev UI — so these would open/close the dialog on every visit. Gate them
// to run only under Vitest Browser Mode, or when the "Play" toolbar toggle is on.
const testOnly =
  (fn: NonNullable<Story["play"]>): NonNullable<Story["play"]> =>
  async (context) => {
    if (inVitestBrowser() || context.globals.runPlay === "on") {
      await fn(context)
    }
  }

function dialogEl(canvasElement: HTMLElement): HTMLDialogElement {
  const el = canvasElement.querySelector("dialog")
  if (!el) throw new Error("dialog not mounted")
  return el
}

function scrollRegion(dialog: HTMLDialogElement): HTMLElement {
  const el = dialog.querySelector<HTMLElement>(".overflow-y-auto")
  if (!el) throw new Error("scroll region not mounted")
  return el
}

// Teardown: a play that opens a modal MUST close it, or the open `<dialog>`
// lingers in the top layer (and the page stays scroll-locked via
// `:root:has(dialog:modal)`) into later stories sharing the preview iframe —
// which was flaking the popover story's AX-tree read. Deterministic `.close()`,
// not a UA-timed gesture.
async function closeDialog(dialog: HTMLDialogElement): Promise<void> {
  dialog.close()
  await waitFor(() => expect(dialog.open).toBe(false))
}

// --- shadcn examples --------------------------------------------------------

/**
 * shadcn "Dialog": an outline trigger opening a modal with a header
 * (title/description), a footer (Cancel / Save), and the built-in corner ✕.
 * Controls tune the `closedby` policy, the role, the corner ✕, and the trigger
 * look. Opening uses the native `command="show-modal"` Invoker Command — the
 * platform traps focus, renders the top-layer `::backdrop`, and locks scroll.
 */
export const Playground: Story = {
  render: ({ text, dismiss, role, closeButton, variant, size }) =>
    mountLustre((selector) =>
      mount_dialog_playground(
        selector,
        text,
        dismiss,
        role,
        closeButton,
        variant,
        size,
      ),
    ),
  play: testOnly(async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    const trigger = await canvas.findByRole("button", { name: /open dialog/i })

    // Static wiring seeded by our code: the Invoker Command association, the
    // disclosure aria, and a closed-state seed. Native invoker behavior owns
    // the live disclosure state from here.
    await expect(trigger).toHaveAttribute("command", "show-modal")
    await expect(trigger).toHaveAttribute("aria-haspopup", "dialog")
    await expect(trigger).toHaveAttribute("aria-controls")

    const dialog = dialogEl(canvasElement)
    await expect(dialog).toHaveAttribute("closedby", "any")
    await expect(dialog).toHaveAttribute("aria-labelledby")

    // Regression guard (reopen-on-first-click): while closed/closing the panel
    // is transparent to pointer events, so the fading backdrop can't swallow a
    // click on the trigger. While open it must be interactive again.
    await expect(getComputedStyle(dialog).pointerEvents).toBe("none")

    // Declarative open: clicking the Invoker Command button opens the dialog
    // modally — no JS handler of ours runs.
    await userEvent.click(trigger)
    await waitFor(() => expect(dialog.open).toBe(true))
    await expect(getComputedStyle(dialog).pointerEvents).toBe("auto")

    // Regression guard: the dialog must be CENTERED. Tailwind Preflight resets
    // the UA's `margin:auto` (which centers a modal <dialog>) to 0, pinning it
    // top-left; the recipe restores `m-auto`. Assert both the positioning stays
    // `fixed` and the box is actually centered horizontally in the viewport.
    await expect(getComputedStyle(dialog).position).toBe("fixed")
    const rect = dialog.getBoundingClientRect()
    const offset = Math.abs(rect.left + rect.width / 2 - window.innerWidth / 2)
    await expect(offset).toBeLessThan(2)

    // The built-in corner ✕ closes via `command="close"`.
    const close = await canvas.findByRole("button", { name: /close/i })
    await userEvent.click(close)
    await waitFor(() => expect(dialog.open).toBe(false))

    // Escape light-dismiss is UA behavior gated on *trusted* key events, so it
    // needs the browser-backed `userEvent` (only available under Browser Mode).
    if (!inVitestBrowser()) return
    await userEvent.click(trigger)
    await waitFor(() => expect(dialog.open).toBe(true))
    const browserUser = await browserUserEvent()
    await browserUser.keyboard("{Escape}")
    await waitFor(() => expect(dialog.open).toBe(false))
  }),
}

// --- shadcn doc examples (ui.shadcn.com/docs/components/dialog) -----------

/** shadcn "Usage" — Edit profile with a Name/Username form and Cancel/Save. */
export const Demo: Story = {
  parameters: { controls: { disable: true } },
  render: () => mountLustre(mount_dialog_demo),
  play: testOnly(async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    const trigger = await canvas.findByRole("button", { name: /open dialog/i })
    const dialog = dialogEl(canvasElement)
    await userEvent.click(trigger)
    await waitFor(() => expect(dialog.open).toBe(true))
    // The form fields are present and editable.
    await expect(canvas.getByLabelText("Name")).toHaveValue("Pedro Duarte")
    await expect(canvas.getByLabelText("Username")).toHaveValue("@peduarte")
    // Centered + content-height, not stretched. This guards the Safari/WebKit
    // failure mode: a top-layer <dialog> centered via the UA's
    // `inset:0; margin:auto` only shrinks to `fit-content` in Blink — WebKit
    // stretches it to the inset box (footer floats mid-panel). We center with
    // `position:fixed` + `translate(-50%,-50%)` instead (motion/dialog.css), so
    // both engines agree. Verified directly against Playwright WebKit.
    const rect = dialog.getBoundingClientRect()
    await expect(rect.height).toBeLessThan(window.innerHeight)
    await expect(
      Math.abs(rect.x + rect.width / 2 - window.innerWidth / 2),
    ).toBeLessThan(2)
    await expect(
      Math.abs(rect.y + rect.height / 2 - window.innerHeight / 2),
    ).toBeLessThan(2)
    await closeDialog(dialog)
  }),
}

/** shadcn "Custom Close Button" — a Share-link dialog with a read-only input. */
export const CustomCloseButton: Story = {
  name: "Custom Close Button",
  parameters: { controls: { disable: true } },
  render: () => mountLustre(mount_dialog_close_button),
  play: testOnly(async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    const trigger = await canvas.findByRole("button", { name: /share/i })
    const dialog = dialogEl(canvasElement)
    await userEvent.click(trigger)
    await waitFor(() => expect(dialog.open).toBe(true))
    await expect(canvas.getByLabelText("Link")).toHaveAttribute("readonly")
    await closeDialog(dialog)
  }),
}

/** shadcn "No Close Button" — `showCloseButton={false}`: no corner ✕. */
export const NoCloseButton: Story = {
  name: "No Close Button",
  parameters: { controls: { disable: true } },
  render: () => mountLustre(mount_dialog_no_close_button),
  play: testOnly(async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    const trigger = await canvas.findByRole("button", {
      name: /no close button/i,
    })
    const dialog = dialogEl(canvasElement)
    await userEvent.click(trigger)
    await waitFor(() => expect(dialog.open).toBe(true))
    // No corner ✕ (its accessible name is exactly "Close"; the trigger's
    // "No Close Button" wouldn't match `^close$`).
    await expect(canvas.queryByRole("button", { name: /^close$/i })).toBeNull()
    await closeDialog(dialog)
  }),
}

/** shadcn "Sticky Footer" — scroll region between header and a pinned footer. */
export const StickyFooter: Story = {
  name: "Sticky Footer",
  parameters: { controls: { disable: true } },
  render: () => mountLustre(mount_dialog_sticky_footer),
  play: testOnly(async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    const trigger = await canvas.findByRole("button", {
      name: /sticky footer/i,
    })
    const dialog = dialogEl(canvasElement)
    await userEvent.click(trigger)
    await waitFor(() => expect(dialog.open).toBe(true))
    // The scroll region overflows, and the footer Close stays out of it (the
    // footer Close + the corner ✕ both carry the name "Close").
    const scroller = scrollRegion(dialog)
    await expect(scroller.scrollHeight).toBeGreaterThan(scroller.clientHeight)
    await expect(
      canvas.getAllByRole("button", { name: /^close$/i }).length,
    ).toBeGreaterThanOrEqual(1)
    await closeDialog(dialog)
  }),
}

/** shadcn "Scrollable Content" — the scroll region, no footer. */
export const ScrollableContent: Story = {
  name: "Scrollable Content",
  parameters: { controls: { disable: true } },
  render: () => mountLustre(mount_dialog_scrollable),
  play: testOnly(async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    const trigger = await canvas.findByRole("button", {
      name: /scrollable content/i,
    })
    const dialog = dialogEl(canvasElement)
    await userEvent.click(trigger)
    await waitFor(() => expect(dialog.open).toBe(true))
    // A `max-h-[50vh] overflow-y-auto` region scrolls inside the fixed dialog.
    const scroller = scrollRegion(dialog)
    await expect(scroller.scrollHeight).toBeGreaterThan(scroller.clientHeight)
    await closeDialog(dialog)
  }),
}

/** shadcn "RTL" — the Edit-profile demo mirrored with `dir="rtl"`. */
export const Rtl: Story = {
  name: "RTL",
  parameters: { controls: { disable: true } },
  render: () => mountLustre(mount_dialog_rtl),
  play: testOnly(async ({ canvasElement }) => {
    const dialog = dialogEl(canvasElement)
    await expect(dialog).toHaveAttribute("dir", "rtl")
  }),
}

/**
 * Host-controlled, lazily-mounted body: the dialog renders its content ONLY
 * while open. Demonstrates the DOM-cost pattern — a heavy dialog body doesn't sit
 * in the DOM while closed; the native `<dialog>` shell stays mounted, we gate the
 * children. Closed → 0 body nodes; open → the form; close → the body unmounts
 * again. (The spinner-while-fetching affordance lives in the Combobox Remote
 * story, which has a real mock fetch.)
 */
export const LazyContent: Story = {
  name: "Lazy Content (host-controlled)",
  parameters: { controls: { disable: true } },
  render: () => mountLustre(mount_dialog_lazy_content),
  play: testOnly(async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    const trigger = await canvas.findByRole("button", { name: /edit profile/i })
    const dialog = dialogEl(canvasElement)

    // Closed: the body is NOT in the DOM — the <dialog> shell is empty.
    await expect(dialog.children.length).toBe(0)

    // Open → the body is rendered and the dialog is shown modally.
    await userEvent.click(trigger)
    await waitFor(() => expect(dialog.open).toBe(true))
    await waitFor(() =>
      expect(canvas.getByLabelText("Name")).toHaveValue("Pedro Duarte"),
    )

    // Close → the body unmounts again (lazy DOM): the shell is empty once more.
    await closeDialog(dialog)
    await waitFor(() => expect(dialog.children.length).toBe(0))
  }),
}
