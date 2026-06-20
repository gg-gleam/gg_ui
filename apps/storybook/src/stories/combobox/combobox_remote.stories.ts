import type { Meta, StoryObj } from "@storybook/html-vite"
import { expect, userEvent, waitFor, within } from "storybook/test"
import { mountLustre } from "../../../.storybook/lustre-mount"
import {
  mount_combobox_remote_multiple,
  mount_combobox_remote_single,
} from "./combobox_remote.gleam"

// Remote (server-driven) combobox backed by GitHub repository search: lazy fetch
// on open, debounced search, infinite-scroll pagination, and an async loading
// announcer. In the dev UI it hits the real API; under Vitest the fetch is mocked
// (`globalThis.__comboboxFetchMock`) so the play tests are deterministic.

const meta: Meta = {
  title: "Components/Combobox",
  parameters: { controls: { disable: true } },
}
export default meta
type Story = StoryObj

declare global {
  // `var` is required to augment `globalThis`; `let`/`const` don't work here.
  var __vitest_browser__: boolean | undefined
  var __comboboxFetchMock:
    | ((query: string, page: number) => Promise<unknown>)
    | undefined
}
const inVitestBrowser = (): boolean => globalThis.__vitest_browser__ === true
const testOnly =
  (fn: NonNullable<Story["play"]>): NonNullable<Story["play"]> =>
  async (context) => {
    if (inVitestBrowser() || context.globals.runPlay === "on") {
      await fn(context)
    }
  }

// A deterministic GitHub-search stand-in: 50 results over 3 pages, each repo named
// after the active query so a search is observable. Installed only for the test.
const TOTAL = 50
const PER_PAGE = 20
function fixture(query: string, page: number): Promise<unknown> {
  const scope = query.startsWith("stars:") ? "popular" : query
  const start = (page - 1) * PER_PAGE
  const count = Math.max(0, Math.min(PER_PAGE, TOTAL - start))
  const items = Array.from({ length: count }, (_, i) => ({
    full_name: `${scope}/repo-${start + i + 1}`,
  }))
  return Promise.resolve({ total_count: TOTAL, items })
}
const installFetchMock = () => {
  globalThis.__comboboxFetchMock = fixture
}

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
    installFetchMock()
    const canvas = within(canvasElement)
    const input = canvas.getByRole<HTMLInputElement>("combobox")

    // Lazy: nothing is fetched until the field is opened.
    expect(canvas.queryAllByRole("option")).toHaveLength(0)

    // Open → the default ("popular") first page loads.
    await userEvent.click(input)
    await waitFor(() => expect(isOpen(canvasElement)).toBe(true))
    await waitFor(() =>
      expect(canvas.getAllByRole("option")).toHaveLength(PER_PAGE),
    )
    // The popup opens BELOW the field, left-aligned — never thrown out to the
    // side (the `flip-start` axis-swap fallback is removed; a tall popup flips up,
    // not sideways).
    {
      const field = input.getBoundingClientRect()
      const box = popup(canvasElement).getBoundingClientRect()
      expect(box.left).toBeLessThan(field.right) // overlaps the field's column
      // A real gap below the field's border box — wide enough to clear the focus
      // ring (3px) so the popup never reads as sitting over the input.
      expect(box.top - field.bottom).toBeGreaterThanOrEqual(4)
    }
    await waitFor(() =>
      expect(canvas.getByText("popular/repo-1")).toBeVisible(),
    )

    // Type → debounced server search (250ms) replaces the list with new results.
    await userEvent.type(input, "react")
    await waitFor(() => expect(input.value).toBe("react"))
    await waitFor(
      () =>
        expect(canvas.getAllByRole("option")[0]?.textContent?.trim()).toBe(
          "react/repo-1",
        ),
      { timeout: 2000 },
    )
    await expect(canvas.queryByText("popular/repo-1")).toBeNull()
    expect(canvas.getAllByRole("option")).toHaveLength(PER_PAGE)

    // The popup has a bounded height and the list scrolls inside it — it doesn't
    // grow with the items (native `max-block-size: min(18rem, available)`).
    {
      const box = popup(canvasElement)
      const list = listbox(canvasElement)
      expect(box.getBoundingClientRect().height).toBeLessThanOrEqual(
        18 * 16 + 1,
      )
      expect(list.scrollHeight).toBeGreaterThan(list.clientHeight)
    }

    // Scroll the list to the bottom → the next page auto-appends (no click).
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

    // Pick one → fills the input, closes.
    await userEvent.click(canvas.getByText("react/repo-3"))
    await waitFor(() => expect(input.value).toBe("react/repo-3"))
    await waitFor(() => expect(isOpen(canvasElement)).toBe(false))
  }),
}

export const RemoteMultiple: Story = {
  name: "Remote (multiple)",
  render: () =>
    mountLustre((selector) => mount_combobox_remote_multiple(selector)),
  play: testOnly(async ({ canvasElement }) => {
    installFetchMock()
    const canvas = within(canvasElement)
    const input = canvas.getByRole<HTMLInputElement>("combobox")

    await userEvent.click(input)
    await waitFor(() => expect(isOpen(canvasElement)).toBe(true))
    await waitFor(() =>
      expect(canvas.getAllByRole("option")).toHaveLength(PER_PAGE),
    )

    // Pick two from the remote list → they accumulate as chips, list stays open.
    await userEvent.click(canvas.getByText("popular/repo-1"))
    await expect(isOpen(canvasElement)).toBe(true)
    await waitFor(() =>
      expect(
        canvas.getByRole("button", { name: "Remove popular/repo-1" }),
      ).toBeVisible(),
    )
    // After a multiple-pick the query clears → the default list reloads; pick
    // again from it.
    await waitFor(() =>
      expect(canvas.getAllByRole("option").length).toBeGreaterThan(0),
    )
    await userEvent.click(canvas.getByText("popular/repo-2"))
    await waitFor(() =>
      expect(canvas.getAllByRole("button", { name: /^Remove/ })).toHaveLength(
        2,
      ),
    )
  }),
}
