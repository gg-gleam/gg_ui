import type { Meta, StoryObj } from "@storybook/html-vite"
import { expect, userEvent, waitFor, within } from "storybook/test"
import { mountLustre } from "../../../.storybook/lustre-mount"
import {
  mount_calendar_blocked,
  mount_calendar_count_bounds,
  mount_calendar_disabled,
  mount_calendar_dropdown,
  mount_calendar_locale,
  mount_calendar_multiple,
  mount_calendar_playground,
  mount_calendar_range,
  mount_calendar_two_months,
  mount_calendar_with_selected,
} from "./calendar.gleam"

type WeekStartArg = "sunday" | "monday"
type ModeArg = "single" | "multiple" | "range"
type CaptionArg = "label" | "dropdown"

interface CalendarArgs {
  weekStart: WeekStartArg
  showOutside: boolean
  mode: ModeArg
  caption: CaptionArg
  months: number
  locale: string
}

const weekStarts: WeekStartArg[] = ["sunday", "monday"]
const modes: ModeArg[] = ["single", "multiple", "range"]
const captions: CaptionArg[] = ["label", "dropdown"]
// Codes match parse_locale in calendar.gleam (en + a spread of scripts + RTL).
const locales = [
  "en",
  "es",
  "fr",
  "de",
  "pt",
  "ru",
  "ja",
  "ko",
  "zh",
  "hi",
  "th",
  "ar",
  "he",
  "fa",
]

const meta: Meta<CalendarArgs> = {
  title: "Components/Calendar",
  args: {
    weekStart: "sunday",
    showOutside: true,
    mode: "single",
    caption: "label",
    months: 1,
    locale: "es",
  },
  argTypes: {
    weekStart: { control: { type: "select" }, options: weekStarts },
    showOutside: { control: { type: "boolean" } },
    mode: { control: { type: "inline-radio" }, options: modes },
    caption: { control: { type: "inline-radio" }, options: captions },
    months: { control: { type: "number", min: 1, max: 3 } },
    locale: { control: { type: "select" }, options: locales },
  },
}

export default meta

type Story = StoryObj<CalendarArgs>

// Storybook's Interactions addon auto-runs `play` whenever a story is *viewed*.
// Gate it like the combobox/popover stories: always under Vitest Browser Mode,
// and in the dev UI only when the "Play" toolbar toggle is on.
declare global {
  // `var` is required to augment `globalThis`.
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

const day = (canvas: ReturnType<typeof within>, label: string): HTMLElement =>
  canvas.getByRole("button", { name: label })

/** Single-date calendar with all controls (mode / caption / months / week-start /
 *  outside days). Click to select, full keyboard nav (arrows cross month
 *  boundaries and move DOM focus via the roving tabindex). */
export const Playground: Story = {
  render: ({ weekStart, showOutside, mode, caption, months }) =>
    mountLustre((selector) =>
      mount_calendar_playground(
        selector,
        weekStart,
        showOutside,
        mode,
        caption,
        months,
      ),
    ),
  // `today` is fixed to 2026-06-27, so the grid opens on June 2026.
  play: testOnly(async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(canvas.getByRole("grid")).toBeVisible()

    // The roving tabindex starts on today (nothing selected yet).
    await expect(day(canvas, "June 27, 2026")).toHaveAttribute("tabindex", "0")

    // Click a day → selected (single) and the status line updates.
    const tenth = day(canvas, "June 10, 2026")
    await userEvent.click(tenth)
    await waitFor(() =>
      expect(tenth).toHaveAttribute("data-selected-single", "true"),
    )
    await expect(canvas.getByText("Selected: June 10, 2026")).toBeVisible()
    await expect(tenth).toHaveAttribute("tabindex", "0")

    // Keyboard: focus the selected day, arrows move DOM focus.
    tenth.focus()
    await userEvent.keyboard("{ArrowRight}")
    await waitFor(() =>
      expect(document.activeElement).toBe(day(canvas, "June 11, 2026")),
    )
    await userEvent.keyboard("{ArrowDown}")
    await waitFor(() =>
      expect(document.activeElement).toBe(day(canvas, "June 18, 2026")),
    )

    // Month nav.
    await userEvent.click(
      canvas.getByRole("button", { name: /previous month/i }),
    )
    await waitFor(() => expect(canvas.getByText("May 2026")).toBeVisible())
  }),
}

/** A calendar opened with a date already selected (June 15, 2026). */
export const WithSelected: Story = {
  parameters: { controls: { disable: true } },
  render: () => mountLustre(mount_calendar_with_selected),
  play: testOnly(async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    const fifteenth = day(canvas, "June 15, 2026")
    await expect(fifteenth).toHaveAttribute("data-selected-single", "true")
    await expect(fifteenth).toHaveAttribute("tabindex", "0")
    await expect(canvas.getByText("Selected: June 15, 2026")).toBeVisible()
  }),
}

/** Range mode: click a start, hover/keyboard previews the span, a second click
 *  commits it (start/middle/end visuals; re-anchoring if you click before start). */
export const Range: Story = {
  // Keep the outside-days control here — it's the case where the range track's
  // week-boundary rounding matters; toggle it to see the caps stay rounded.
  parameters: { controls: { include: ["showOutside"] } },
  render: ({ showOutside }) =>
    mountLustre((selector) => mount_calendar_range(selector, showOutside)),
  play: testOnly(async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    // Click the start.
    await userEvent.click(day(canvas, "June 10, 2026"))
    await waitFor(() =>
      expect(day(canvas, "June 10, 2026")).toHaveAttribute(
        "data-range-start",
        "true",
      ),
    )
    // Hover the prospective end → the middle previews.
    await userEvent.hover(day(canvas, "June 14, 2026"))
    await waitFor(() =>
      expect(day(canvas, "June 12, 2026")).toHaveAttribute(
        "data-range-middle",
        "true",
      ),
    )
    // Click to commit the end.
    await userEvent.click(day(canvas, "June 14, 2026"))
    await waitFor(() =>
      expect(day(canvas, "June 14, 2026")).toHaveAttribute(
        "data-range-end",
        "true",
      ),
    )
    await waitFor(() =>
      expect(canvasElement.textContent).toMatch(
        /Range: June 10, 2026 .+ June 14, 2026/,
      ),
    )
  }),
}

/** Multiple mode: clicking toggles days in/out of a set; picks accumulate. */
export const Multiple: Story = {
  parameters: { controls: { disable: true } },
  render: () => mountLustre(mount_calendar_multiple),
  play: testOnly(async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await userEvent.click(day(canvas, "June 10, 2026"))
    await userEvent.click(day(canvas, "June 12, 2026"))
    await waitFor(() =>
      expect(day(canvas, "June 10, 2026")).toHaveAttribute(
        "data-selected-single",
        "true",
      ),
    )
    await expect(day(canvas, "June 12, 2026")).toHaveAttribute(
      "data-selected-single",
      "true",
    )
    // Toggle the first back off.
    await userEvent.click(day(canvas, "June 10, 2026"))
    await waitFor(() =>
      expect(day(canvas, "June 10, 2026")).not.toHaveAttribute(
        "data-selected-single",
      ),
    )
  }),
}

/** Multiple with min/max count (1–3): a 4th pick is ignored, and the last day
 *  can't be toggled off (so you never drop below the minimum). */
export const MinMaxCount: Story = {
  name: "Min/max count",
  parameters: { controls: { disable: true } },
  render: () => mountLustre(mount_calendar_count_bounds),
  play: testOnly(async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    const pick = (d: number) => userEvent.click(day(canvas, `June ${d}, 2026`))
    const selected = (d: number) =>
      day(canvas, `June ${d}, 2026`).getAttribute("data-selected-single")

    await pick(10)
    await pick(11)
    await pick(12)
    await waitFor(() => expect(selected(12)).toBe("true"))
    // 4th pick is over the cap → ignored.
    await pick(13)
    await waitFor(() => expect(selected(13)).toBeNull())
    // Down to one day, then the last can't be removed (min count 1).
    await pick(10)
    await pick(11)
    await waitFor(() => expect(selected(12)).toBe("true"))
    await pick(12)
    await waitFor(() => expect(selected(12)).toBe("true"))
  }),
}

/** Two months side-by-side (range mode) — span a month boundary without nav. */
export const TwoMonths: Story = {
  name: "Two months",
  parameters: { controls: { disable: true } },
  render: () => mountLustre(mount_calendar_two_months),
  play: testOnly(async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await waitFor(() => expect(canvas.getAllByRole("grid")).toHaveLength(2))
    await expect(canvas.getByText("June 2026")).toBeVisible()
    await expect(canvas.getByText("July 2026")).toBeVisible()
  }),
}

/** Dropdown caption — month/year `<select>`s for fast jumps. */
export const Dropdown: Story = {
  parameters: { controls: { disable: true } },
  render: () => mountLustre(mount_calendar_dropdown),
  play: testOnly(async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    // The <select>s are the accessible controls (overlaid invisibly under the
    // styled label), so assert their value, not visibility. June 2026 = 6 / 2026.
    const month = canvas.getByRole("combobox", { name: "Month" })
    const year = canvas.getByRole("combobox", { name: "Year" })
    await expect(month).toHaveValue("6")
    await expect(year).toHaveValue("2026")
    // Jump to August via the month dropdown.
    await userEvent.selectOptions(month, "8")
    await waitFor(() =>
      expect(
        canvas.getByRole("button", { name: /August 1, 2026/ }),
      ).toBeVisible(),
    )
  }),
}

/** Disabled past dates (`disable_before today`) — can't be selected or focused. */
export const Disabled: Story = {
  parameters: { controls: { disable: true } },
  render: () => mountLustre(mount_calendar_disabled),
  play: testOnly(async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    // The 10th is before today (27th) → disabled.
    await expect(day(canvas, "June 10, 2026")).toBeDisabled()
    await expect(day(canvas, "June 28, 2026")).toBeEnabled()
  }),
}

/** Interactive `disable` predicate driven by local state: the host owns the set
 *  of blocked days; toggle a day's block and the disabled cells update live (and
 *  blocked days can't be selected). The realistic "already-booked slots" case. */
export const Blocked: Story = {
  name: "Blocked dates (interactive)",
  parameters: { controls: { disable: true } },
  render: () => mountLustre(mount_calendar_blocked),
  play: testOnly(async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    // 13 starts blocked (disabled); 10 starts open.
    await expect(day(canvas, "June 13, 2026")).toBeDisabled()
    await expect(day(canvas, "June 10, 2026")).toBeEnabled()
    // Blocked days are also struck through via the `booked` modifier (shadcn look):
    // the data flag lives on the gridcell.
    const cell = (label: string): HTMLElement =>
      day(canvas, label).closest("td") as HTMLElement
    await expect(cell("June 13, 2026")).toHaveAttribute("data-booked", "true")
    await expect(cell("June 10, 2026")).not.toHaveAttribute("data-booked")

    // Block the 10th → its cell becomes disabled and booked (struck through).
    await userEvent.click(canvas.getByRole("button", { name: "Block June 10" }))
    await waitFor(() => expect(day(canvas, "June 10, 2026")).toBeDisabled())
    await expect(cell("June 10, 2026")).toHaveAttribute("data-booked", "true")

    // Unblock the 13th → selectable again, no longer booked.
    await userEvent.click(
      canvas.getByRole("button", { name: "Unblock June 13" }),
    )
    await waitFor(() => expect(day(canvas, "June 13, 2026")).toBeEnabled())
    await expect(cell("June 13, 2026")).not.toHaveAttribute("data-booked")
  }),
}

/** Localized calendar — pick a locale via the control (translated month/weekday
 *  names, week start, writing direction, and aria-labels). RTL locales (ar/he/fa)
 *  mirror the whole grid. Dropdown caption so the translated names are visible. */
export const Locale: Story = {
  parameters: { controls: { include: ["locale"] } },
  render: ({ locale }) =>
    mountLustre((selector) => mount_calendar_locale(selector, locale)),
  play: testOnly(async ({ canvasElement }) => {
    // Default locale is Spanish → June 2026 shows as "junio".
    await waitFor(() => expect(canvasElement.textContent).toMatch(/junio/i))
  }),
}
