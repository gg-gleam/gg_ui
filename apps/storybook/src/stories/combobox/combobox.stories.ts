import type { Meta, StoryObj } from "@storybook/html-vite"
import { expect, userEvent, waitFor, within } from "storybook/test"
import { mountLustre } from "../../../.storybook/lustre-mount"
import { mount_combobox_playground } from "./combobox.gleam"

type SideArg = "top" | "right" | "bottom" | "left"
type AlignArg = "start" | "center" | "end"

interface ComboboxArgs {
  side: SideArg
  align: AlignArg
  clearable: boolean
}

const sides: SideArg[] = ["top", "right", "bottom", "left"]
const aligns: AlignArg[] = ["start", "center", "end"]

const meta: Meta<ComboboxArgs> = {
  title: "Components/Combobox",
  args: { side: "bottom", align: "start", clearable: false },
  argTypes: {
    side: { control: { type: "select" }, options: sides },
    align: { control: { type: "select" }, options: aligns },
    clearable: { control: { type: "boolean" } },
  },
}

export default meta

type Story = StoryObj<ComboboxArgs>

const render: Story["render"] = ({ side, align, clearable }) =>
  mountLustre((selector) =>
    mount_combobox_playground(selector, side, align, clearable),
  )

// Storybook's Interactions addon auto-runs `play` whenever a story is *viewed* in
// the dev UI — so these would open/filter/select the combobox on every visit (a
// visible flicker). Gate them like the popover stories: always under Vitest
// Browser Mode (so tests run), and in the dev UI only when the "Play" toolbar
// toggle is on. Otherwise the play is a no-op and the component is left calm.
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

// The popup is the headless `role=listbox` rendered with `popover="manual"`. It
// lives in the DOM under the mounted host (and is promoted to the top layer when
// open), so it's reachable from `canvasElement`.
function listbox(canvasElement: HTMLElement): HTMLElement {
  const el = canvasElement.querySelector<HTMLElement>("[role='listbox']")
  if (!el) throw new Error("combobox listbox not mounted")
  return el
}

const isOpen = (canvasElement: HTMLElement): boolean =>
  listbox(canvasElement).matches(":popover-open")

/** Type to filter, arrow/Enter to pick, click an option, Escape to dismiss.
 *  Chevron / check / clear icons are built in (lucide), not story-supplied. */
export const Playground: Story = {
  render,
  // The real single-select flow: open (and *stay* open — the `popover="manual"`
  // dismissal fix), filter as you type, keyboard-select, then dismiss.
  play: testOnly(async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    const input = canvas.getByRole<HTMLInputElement>("combobox")
    await expect(input).toHaveAttribute("aria-expanded", "false")

    // Click the input → opens. The regression guard: with `popover="manual"` the
    // same click that opens it must NOT immediately light-dismiss it.
    await userEvent.click(input)
    await waitFor(() => expect(isOpen(canvasElement)).toBe(true))
    await expect(input).toHaveAttribute("aria-expanded", "true")
    // Still open a tick later — not auto-dismissed by the opening click.
    await new Promise((r) => setTimeout(r, 50))
    await expect(isOpen(canvasElement)).toBe(true)

    // Type → filters down to the single match (`Remix`).
    await userEvent.type(input, "rem")
    await waitFor(() => expect(input.value).toBe("rem"))
    await waitFor(async () =>
      expect(await canvas.findAllByRole("option")).toHaveLength(1),
    )
    await expect(canvas.getByRole("option", { name: "Remix" })).toBeVisible()

    // ↓ highlights the match, Enter selects it → input fills, list closes.
    await userEvent.keyboard("{ArrowDown}")
    await waitFor(() =>
      expect(canvas.getByRole("option", { name: "Remix" })).toHaveAttribute(
        "data-highlighted",
      ),
    )
    await userEvent.keyboard("{Enter}")
    await waitFor(() => expect(input.value).toBe("Remix"))
    await waitFor(() => expect(isOpen(canvasElement)).toBe(false))
    await expect(input).toHaveAttribute("aria-expanded", "false")

    // Re-open, then Escape dismisses (the headless keydown handler, not native
    // light-dismiss — a `manual` popover doesn't close on Escape on its own).
    await userEvent.click(input)
    await waitFor(() => expect(isOpen(canvasElement)).toBe(true))
    await userEvent.keyboard("{Escape}")
    await waitFor(() => expect(isOpen(canvasElement)).toBe(false))
  }),
}

/** With `clearable`, picking an option swaps the chevron for a clear ✕; clicking
 *  it resets the field (selection + text) and restores the chevron. */
export const Clearable: Story = {
  args: { clearable: true },
  render,
  play: testOnly(async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    const input = canvas.getByRole<HTMLInputElement>("combobox")

    // Open via the chevron trigger, then click an option to select it.
    await userEvent.click(input)
    await waitFor(() => expect(isOpen(canvasElement)).toBe(true))
    await userEvent.click(await canvas.findByRole("option", { name: "Astro" }))
    await waitFor(() => expect(input.value).toBe("Astro"))
    await waitFor(() => expect(isOpen(canvasElement)).toBe(false))

    // A selection + `clearable` → the clear button replaces the chevron.
    const clear = await canvas.findByRole("button", {
      name: /clear selection/i,
    })
    await expect(
      canvas.queryByRole("button", { name: /toggle suggestions/i }),
    ).toBeNull()

    // Click clear → field resets and the chevron trigger comes back.
    await userEvent.click(clear)
    await waitFor(() => expect(input.value).toBe(""))
    await waitFor(() =>
      expect(
        canvas.getByRole("button", { name: /toggle suggestions/i }),
      ).toBeInTheDocument(),
    )
    await expect(
      canvas.queryByRole("button", { name: /clear selection/i }),
    ).toBeNull()
  }),
}
