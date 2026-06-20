import type { Meta, StoryObj } from "@storybook/html-vite"
import { expect, userEvent, waitFor, within } from "storybook/test"
import { mountLustre } from "../../../.storybook/lustre-mount"
import {
  mount_combobox_async,
  mount_combobox_grouped,
  mount_combobox_multiple,
  mount_combobox_playground,
} from "./combobox.gleam"

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

// The popup is the headless container rendered with `popover="manual"` — the
// top-layer box that flips to `:popover-open`. The `role=listbox` lives *inside*
// it (sibling to the status region). Both are reachable from `canvasElement`.
function popup(canvasElement: HTMLElement): HTMLElement {
  const el = canvasElement.querySelector<HTMLElement>("[popover]")
  if (!el) throw new Error("combobox popup not mounted")
  return el
}

function listbox(canvasElement: HTMLElement): HTMLElement {
  const el = canvasElement.querySelector<HTMLElement>("[role='listbox']")
  if (!el) throw new Error("combobox listbox not mounted")
  return el
}

const isOpen = (canvasElement: HTMLElement): boolean =>
  popup(canvasElement).matches(":popover-open")

// The single highlighted (active-descendant) option's label, or null. Base UI's
// "active index" — independent of selection — surfaces as `data-highlighted`.
const highlighted = (canvasElement: HTMLElement): string | null =>
  canvasElement
    .querySelector<HTMLElement>("[role='option'][data-highlighted]")
    ?.textContent?.trim() ?? null

// The label of the chip that currently holds DOM focus (roving chip nav), or null
// if focus isn't on a chip.
const focusedChip = (): string | null => {
  const el = document.activeElement as HTMLElement | null
  return el?.getAttribute("data-slot") === "combobox-chip"
    ? (el.textContent?.trim() ?? null)
    : null
}

// The async loading announcer specifically (the empty announcer is also
// role=status and always mounted, so match it by its data-slot).
const loadingRegion = (canvasElement: HTMLElement): HTMLElement | null =>
  canvasElement.querySelector<HTMLElement>("[data-slot='combobox-status']")

const statusRegion = (canvasElement: HTMLElement): HTMLElement => {
  const el = canvasElement.querySelector<HTMLElement>("[role='status']")
  if (!el) throw new Error("combobox status region not mounted")
  return el
}

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
    // `aria-expanded` tracks the model; the VDOM patch can trail the native
    // popover open by a frame, so wait for it rather than asserting eagerly.
    await waitFor(() => expect(input).toHaveAttribute("aria-expanded", "true"))
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
    await waitFor(() => expect(input).toHaveAttribute("aria-expanded", "false"))

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

/** Multiple-select (Base UI parity). Picks accumulate as chips and the list stays
 *  open; the active highlight is independent of selection, so Enter toggles in
 *  place and you keep arrowing. Chips are a roving-focus toolbar: ←/→ moves
 *  between them, Delete removes, Enter returns to the input; ArrowLeft from the
 *  empty input enters the chips; Backspace there pops the last one. */
export const Multiple: Story = {
  parameters: { controls: { disable: true } },
  render: ({ side, align }) =>
    mountLustre((selector) => mount_combobox_multiple(selector, side, align)),
  play: testOnly(async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    const input = () => canvas.getByRole<HTMLInputElement>("combobox")
    const selected = (name: string): string | null =>
      canvas.getByRole("option", { name }).getAttribute("aria-selected")
    const field = (): HTMLElement => {
      const el = canvasElement.querySelector<HTMLElement>(
        "[data-slot='combobox-chips']",
      )
      if (!el) throw new Error("chips field not mounted")
      return el
    }
    const emptyWidth = field().getBoundingClientRect().width

    // --- keyboard option nav: highlight is independent of selection ----------
    await userEvent.click(input())
    await waitFor(() => expect(isOpen(canvasElement)).toBe(true))
    expect(highlighted(canvasElement)).toBeNull()

    await userEvent.keyboard("{ArrowDown}") // seeds first
    await waitFor(() => expect(highlighted(canvasElement)).toBe("Next.js"))
    await userEvent.keyboard("{ArrowDown}")
    await waitFor(() => expect(highlighted(canvasElement)).toBe("SvelteKit"))

    // Enter toggles SvelteKit — highlight STAYS on it, list stays open.
    await userEvent.keyboard("{Enter}")
    await waitFor(() => expect(selected("SvelteKit")).toBe("true"))
    await expect(isOpen(canvasElement)).toBe(true)
    await expect(highlighted(canvasElement)).toBe("SvelteKit")

    // Width is unchanged by the chip (w-full fills the fixed-width container).
    expect(field().getBoundingClientRect().width).toBeCloseTo(emptyWidth, 0)

    // Keep arrowing from where we are — focus survived the chip insert (keyed
    // input), so position is not lost.
    expect(document.activeElement).toBe(input())
    await userEvent.keyboard("{ArrowDown}")
    await waitFor(() => expect(highlighted(canvasElement)).toBe("Nuxt"))
    await userEvent.keyboard("{Enter}") // toggle Nuxt on
    await waitFor(() => expect(selected("Nuxt")).toBe("true"))

    // Arrow back up and untoggle — toggle/untoggle both work mid-navigation.
    await userEvent.keyboard("{ArrowUp}")
    await waitFor(() => expect(highlighted(canvasElement)).toBe("SvelteKit"))
    await userEvent.keyboard("{Enter}")
    await waitFor(() => expect(selected("SvelteKit")).toBe("false"))

    // Mouse + keyboard interplay: click two options, keep arrowing from the click.
    await userEvent.click(canvas.getByRole("option", { name: "Phoenix" }))
    await waitFor(() => expect(highlighted(canvasElement)).toBe("Phoenix"))
    await userEvent.keyboard("{ArrowUp}")
    await waitFor(() => expect(highlighted(canvasElement)).toBe("Gleam Lustre"))
    await userEvent.click(canvas.getByRole("option", { name: "Astro" }))
    // Selection so far: Nuxt, Phoenix, Astro → three chips, each removable.
    await waitFor(() =>
      expect(canvas.getAllByRole("button", { name: /^Remove/ })).toHaveLength(
        3,
      ),
    )

    // --- chip roving focus ----------------------------------------------------
    // ArrowLeft from the empty input enters the chips at the last one.
    input().focus()
    await userEvent.keyboard("{ArrowLeft}")
    await waitFor(() => expect(focusedChip()).toBe("Astro"))
    await userEvent.keyboard("{ArrowLeft}") // → Phoenix
    await waitFor(() => expect(focusedChip()).toBe("Phoenix"))
    await userEvent.keyboard("{ArrowRight}") // → Astro
    await waitFor(() => expect(focusedChip()).toBe("Astro"))

    // Delete the focused chip — it's removed and focus lands on the new last chip.
    await userEvent.keyboard("{Delete}")
    await waitFor(() =>
      expect(canvas.queryByRole("button", { name: "Remove Astro" })).toBeNull(),
    )
    await waitFor(() => expect(focusedChip()).toBe("Phoenix"))

    // Enter on a focused chip returns focus to the input.
    await userEvent.keyboard("{Enter}")
    await waitFor(() => expect(document.activeElement).toBe(input()))

    // --- removal via the ✕ button + input Backspace --------------------------
    await userEvent.click(
      canvas.getByRole("button", { name: "Remove Phoenix" }),
    )
    await waitFor(() =>
      expect(
        canvas.queryByRole("button", { name: "Remove Phoenix" }),
      ).toBeNull(),
    )

    // Backspace in the empty input pops the last remaining chip (Nuxt).
    input().focus()
    await userEvent.keyboard("{Backspace}")
    await waitFor(() =>
      expect(canvas.queryByRole("button", { name: "Remove Nuxt" })).toBeNull(),
    )
    // Back to no chips → the field returned to its empty width.
    expect(field().getBoundingClientRect().width).toBeCloseTo(emptyWidth, 0)
  }),
}

/** A grouped list: options sit under labelled `role=group` sections; empty
 *  groups (everything filtered out) disappear. */
export const Grouped: Story = {
  parameters: { controls: { disable: true } },
  render: ({ side, align }) =>
    mountLustre((selector) => mount_combobox_grouped(selector, side, align)),
  play: testOnly(async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    const input = canvas.getByRole<HTMLInputElement>("combobox")

    await userEvent.click(input)
    await waitFor(() => expect(isOpen(canvasElement)).toBe(true))

    // Sections live inside the listbox (role=group), labelled by their headers.
    const list = within(listbox(canvasElement))
    await waitFor(() => expect(list.getAllByRole("group")).toHaveLength(4))
    await waitFor(() => expect(list.getByText("React")).toBeVisible())
    await waitFor(() =>
      expect(list.getByRole("option", { name: "Next.js" })).toBeVisible(),
    )

    // Filter to "nuxt" → only the Vue group survives; the rest drop out.
    await userEvent.type(input, "nuxt")
    await waitFor(() => expect(list.getAllByRole("group")).toHaveLength(1))
    await waitFor(() => expect(list.getByText("Vue")).toBeVisible())
  }),
}

/** Async: the button toggles the combobox's `role=status` loading announcement —
 *  a polite live region that stays mounted while its message changes. */
export const Async: Story = {
  parameters: { controls: { disable: true } },
  render: ({ side, align }) =>
    mountLustre((selector) => mount_combobox_async(selector, side, align)),
  play: testOnly(async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    // The empty announcer is always mounted (role=status); the loading announcer
    // (data-slot=combobox-status) appears only while loading.
    await expect(statusRegion(canvasElement)).toHaveAttribute(
      "aria-live",
      "polite",
    )
    await expect(loadingRegion(canvasElement)).toBeNull()

    await userEvent.click(
      canvas.getByRole("button", { name: /simulate loading/i }),
    )
    await waitFor(() => {
      const region = loadingRegion(canvasElement)
      expect(region).not.toBeNull()
      expect(region?.textContent).toContain("Loading frameworks")
    })

    // It unmounts when loading stops.
    await userEvent.click(canvas.getByRole("button", { name: /stop loading/i }))
    await waitFor(() => expect(loadingRegion(canvasElement)).toBeNull())
  }),
}
