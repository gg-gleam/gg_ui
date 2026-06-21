import type { Meta, StoryObj } from "@storybook/html-vite"
import { expect, userEvent, waitFor, within } from "storybook/test"
import { mountLustre } from "../../../.storybook/lustre-mount"
import {
  mount_combobox_remote_multiple,
  mount_combobox_remote_single,
} from "./combobox_remote.gleam"

// Remote (server-driven) combobox over a bundled 300-repo dataset (the `repos_ffi`
// mock server filters + paginates it with a simulated latency) — no live backend,
// so Storybook deploys static. The plays run against that real mock server (the
// dataset is deterministic), exercising lazy-open, debounced search, the top
// search spinner, and infinite-scroll pagination end to end.

const meta: Meta = {
  title: "Components/Combobox",
  parameters: { controls: { disable: true } },
}
export default meta
type Story = StoryObj

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

// Stable anchors from the dataset (300 star-sorted repos).
const FIRST_REPO = "codecrafters-io/build-your-own-x"
const PER_PAGE = 20

const popup = (canvasElement: HTMLElement): HTMLElement => {
  const el = canvasElement.querySelector<HTMLElement>("[popover]")
  if (!el) throw new Error("popup not mounted")
  return el
}
const isOpen = (canvasElement: HTMLElement): boolean =>
  popup(canvasElement).matches(":popover-open")
const listbox = (canvasElement: HTMLElement): HTMLElement => {
  const el = canvasElement.querySelector<HTMLElement>("[role='listbox']")
  if (!el) throw new Error("listbox not mounted")
  return el
}

export const Remote: Story = {
  name: "Remote (single)",
  render: () =>
    mountLustre((selector) => mount_combobox_remote_single(selector)),
  play: testOnly(async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    const input = canvas.getByRole<HTMLInputElement>("combobox")

    // Lazy: nothing is fetched until the field is opened.
    expect(canvas.queryAllByRole("option")).toHaveLength(0)

    // Open → the default "browse" first page loads (20 of 300, star-sorted).
    await userEvent.click(input)
    await waitFor(() => expect(isOpen(canvasElement)).toBe(true))
    await waitFor(
      () => expect(canvas.getAllByRole("option")).toHaveLength(PER_PAGE),
      { timeout: 2000 },
    )
    // The popup never overlaps the field (fully below, or flips fully above when
    // tight) and stays within the viewport.
    {
      const field = input.getBoundingClientRect()
      const box = popup(canvasElement).getBoundingClientRect()
      expect(box.left).toBeLessThan(field.right)
      expect(box.top >= field.bottom || box.bottom <= field.top).toBe(true)
      expect(box.bottom).toBeLessThanOrEqual(window.innerHeight + 1)
    }
    await waitFor(() => expect(canvas.getByText(FIRST_REPO)).toBeVisible())

    // The popup is height-bounded and the list scrolls inside it.
    {
      const box = popup(canvasElement)
      const list = listbox(canvasElement)
      expect(box.getBoundingClientRect().height).toBeLessThanOrEqual(
        18 * 16 + 1,
      )
      expect(list.scrollHeight).toBeGreaterThan(list.clientHeight)
    }

    // Scroll to the bottom → the next page auto-appends over the 300-repo default.
    const list = listbox(canvasElement)
    list.scrollTop = list.scrollHeight
    list.dispatchEvent(new Event("scroll", { bubbles: false }))
    await waitFor(
      () =>
        expect(canvas.getAllByRole("option").length).toBeGreaterThanOrEqual(
          2 * PER_PAGE,
        ),
      { timeout: 2000 },
    )

    // Type → value updates immediately; while the debounced search is pending the
    // loading feedback shows IN THE FIELD — the trailing chevron is swapped for a
    // spinner (role=status, data-slot=combobox-loading) — not a popup row.
    await userEvent.type(input, "react")
    await waitFor(() => expect(input.value).toBe("react"))
    await waitFor(() =>
      expect(
        canvasElement.querySelector("[data-slot='combobox-loading']"),
      ).not.toBeNull(),
    )
    // The server-filtered results replace the list — only the 4 "react" repos
    // remain (the non-matching default repo is gone). `enaqx/awesome-react` is
    // lower-starred so it appears ONLY after the search, not in the default top-40.
    await waitFor(() => expect(canvas.getAllByRole("option")).toHaveLength(4), {
      timeout: 2000,
    })
    await expect(canvas.getByText("enaqx/awesome-react")).toBeVisible()
    await expect(canvas.queryByText(FIRST_REPO)).toBeNull()
    // Settled → the spinner is gone (back to the chevron/clear).
    await waitFor(() =>
      expect(
        canvasElement.querySelector("[data-slot='combobox-loading']"),
      ).toBeNull(),
    )

    // Pick one → fills the input, closes.
    await userEvent.click(canvas.getByText("react/react"))
    await waitFor(() => expect(input.value).toBe("react/react"))
    await waitFor(() => expect(isOpen(canvasElement)).toBe(false))

    // Reopen → the input still shows the selection, but the list BROWSES the full
    // set again (not just the selected item) and loading settles — i.e. no stuck
    // spinner from the leftover label being used as a query.
    await userEvent.click(input)
    await waitFor(() => expect(isOpen(canvasElement)).toBe(true))
    await waitFor(
      () => expect(canvas.getAllByRole("option").length).toBeGreaterThan(1),
      { timeout: 2000 },
    )
    await waitFor(() =>
      expect(
        canvasElement.querySelector("[data-slot='combobox-loading']"),
      ).toBeNull(),
    )
  }),
}

export const RemoteMultiple: Story = {
  name: "Remote (multiple)",
  render: () =>
    mountLustre((selector) => mount_combobox_remote_multiple(selector)),
  play: testOnly(async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    const input = canvas.getByRole<HTMLInputElement>("combobox")

    await userEvent.click(input)
    await waitFor(() => expect(isOpen(canvasElement)).toBe(true))
    await waitFor(
      () => expect(canvas.getAllByRole("option")).toHaveLength(PER_PAGE),
      { timeout: 2000 },
    )

    // Pick two from the remote list → they accumulate as chips, list stays open.
    await userEvent.click(canvas.getByText(FIRST_REPO))
    await expect(isOpen(canvasElement)).toBe(true)
    await waitFor(() =>
      expect(
        canvas.getByRole("button", { name: `Remove ${FIRST_REPO}` }),
      ).toBeVisible(),
    )
    await userEvent.click(canvas.getByText("sindresorhus/awesome"))
    await waitFor(() =>
      expect(canvas.getAllByRole("button", { name: /^Remove/ })).toHaveLength(
        2,
      ),
    )
  }),
}
