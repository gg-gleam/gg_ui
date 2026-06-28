import type { Meta, StoryObj } from "@storybook/html-vite"
import { expect, userEvent, waitFor, within } from "storybook/test"
import { mountLustre } from "../../../.storybook/lustre-mount"
import {
  mount_date_picker_dob,
  mount_date_picker_input,
  mount_date_picker_range,
  mount_date_picker_rtl,
  mount_date_picker_single,
  mount_date_picker_time,
} from "./date_picker.gleam"

// The date picker is a *composition*, not a packaged component: a popover whose
// trigger button shows the chosen date and whose content is a calendar. These
// stories prove the primitives compose (the popover-fit check for the picker).
const meta: Meta = {
  title: "Components/Date Picker",
}
export default meta

type Story = StoryObj

// Storybook auto-runs `play` on view; gate it like the other component stories.
declare global {
  // eslint-disable-next-line no-var
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

// The native popover content lives in the top layer; query the whole document.
const doc = () => within(document.body)
const day = (label: string): HTMLElement =>
  doc().getByRole("button", { name: label })

/** Single date picker: outline trigger ("Pick a date") opens a calendar; picking
 *  a day fills the trigger and closes the popover. */
export const Single: Story = {
  render: () => mountLustre(mount_date_picker_single),
  play: testOnly(async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    const trigger = canvas.getByRole("button", { name: /Pick a date/ })
    await userEvent.click(trigger)
    // Calendar opens (June 2026, today fixed to the 27th).
    await waitFor(() => expect(doc().getByRole("grid")).toBeVisible())

    // Pick the 10th → trigger updates, popover closes (grid gone).
    await userEvent.click(day("June 10, 2026"))
    await waitFor(() =>
      expect(
        canvas.getByRole("button", { name: /June 10, 2026/ }),
      ).toBeVisible(),
    )
    await waitFor(() => expect(doc().queryByRole("grid")).toBeNull())
  }),
}

/** Range date picker: a two-month calendar; the trigger shows "from – to" once
 *  both ends are chosen, then the popover closes. */
export const Range: Story = {
  render: () => mountLustre(mount_date_picker_range),
  play: testOnly(async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await userEvent.click(canvas.getByRole("button", { name: /Pick a date/ }))
    await waitFor(() => expect(doc().getAllByRole("grid")).toHaveLength(2))

    // Start June 10, end June 20 → trigger shows the span, popover closes.
    await userEvent.click(day("June 10, 2026"))
    await userEvent.click(day("June 20, 2026"))
    await waitFor(() =>
      expect(
        canvas.getByRole("button", {
          name: /June 10, 2026 – June 20, 2026/,
        }),
      ).toBeVisible(),
    )
    await waitFor(() => expect(doc().queryByRole("grid")).toBeNull())
  }),
}

/** Date of birth: a dropdown caption (month/year selects) + a constrained year
 *  range, closing on select. shadcn's `date-picker-dob`. */
export const DateOfBirth: Story = {
  name: "Date of birth",
  render: () => mountLustre(mount_date_picker_dob),
  play: testOnly(async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    // The trigger is associated with its field label (shadcn's `FieldLabel
    // htmlFor`), so its accessible name is "Date of birth" — not the visible
    // placeholder/value, which lives in the button's text content.
    await userEvent.click(canvas.getByRole("button", { name: /Date of birth/ }))
    // Dropdown caption: month + year selects (overlaid invisibly, so assert
    // presence/value, not visibility).
    await waitFor(() =>
      expect(doc().getByRole("combobox", { name: "Month" })).toHaveValue("6"),
    )
    await expect(doc().getByRole("combobox", { name: "Year" })).toHaveValue(
      "2026",
    )
    await userEvent.click(day("June 10, 2026"))
    // Value reflected in the trigger's text content + popover closed.
    await waitFor(() => expect(canvas.getByText("June 10, 2026")).toBeVisible())
    await waitFor(() => expect(doc().queryByRole("grid")).toBeNull())
  }),
}

/** Date + time: the date popover (dropdown caption) beside a native time field.
 *  shadcn's `date-picker-time`. */
export const DateAndTime: Story = {
  name: "Date and time",
  render: () => mountLustre(mount_date_picker_time),
  play: testOnly(async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    // The time field carries its default value.
    await expect(canvas.getByLabelText("Time")).toHaveValue("10:30:00")
    // The date picker still works.
    await userEvent.click(canvas.getByRole("button", { name: /Select date/ }))
    await waitFor(() => expect(doc().getByRole("grid")).toBeVisible())
    await userEvent.click(day("June 12, 2026"))
    await waitFor(() =>
      expect(
        canvas.getByRole("button", { name: /June 12, 2026/ }),
      ).toBeVisible(),
    )
  }),
}

/** RTL: the field flows right-to-left and the calendar mirrors via an RTL locale
 *  (Arabic). shadcn's `date-picker-rtl`. */
export const Rtl: Story = {
  name: "RTL",
  render: () => mountLustre(mount_date_picker_rtl),
  play: testOnly(async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    // The container is RTL.
    await expect(canvasElement.querySelector("[dir=rtl]")).not.toBeNull()
    // The trigger opens an (Arabic-locale) calendar.
    await userEvent.click(canvas.getByRole("button"))
    await waitFor(() => expect(doc().getByRole("grid")).toBeVisible())
  }),
}

/** Typeable: an input group whose field accepts a typed date and whose trailing
 *  button opens the calendar; picking fills the field. shadcn's `date-picker-input`. */
export const InputField: Story = {
  name: "Input (typeable)",
  render: () => mountLustre(mount_date_picker_input),
  play: testOnly(async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    const field = canvas.getByLabelText("Subscription Date")
    await expect(field).toHaveValue("June 1, 2026")

    // Open via the trailing icon button, pick a day → field updates, popover closes.
    await userEvent.click(canvas.getByRole("button", { name: "Select date" }))
    await waitFor(() => expect(doc().getByRole("grid")).toBeVisible())
    await userEvent.click(day("June 15, 2026"))
    await waitFor(() => expect(field).toHaveValue("June 15, 2026"))
    await waitFor(() => expect(doc().queryByRole("grid")).toBeNull())
  }),
}
