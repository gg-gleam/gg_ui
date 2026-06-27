//// Render contract for the **styled** calendar (`gg_ui/ui/calendar`) — the `cn-*`
//// markup + ARIA the headless behaviour gets dressed in: the nav with built-in
//// lucide chevrons, the `aria-live` month caption, and the `role=grid` table with
//// its weekday columnheaders, gridcells, `aria-selected` / `data-*` day buttons,
//// and roving `tabindex`. The headless state machine is covered by `gg_base_ui`;
//// this pins what *this* layer adds. Dates are fixed so snapshots are stable.

import birdie

// Imported to *drive* selection states the facade deliberately doesn't expose as
// constructors (the same pattern as the combobox test); every rendered subject is
// still the styled layer's own `calendar.calendar` output.
import gg_base_ui/calendar/calendar as base_calendar
import gg_ui/ui/calendar
import gleam/option.{None, Some}
import gleam/time/calendar as time_calendar
import lustre/element

fn anatomy() -> calendar.Anatomy {
  calendar.anatomy_with_id("cal")
}

fn june(day: Int) -> time_calendar.Date {
  time_calendar.Date(2026, time_calendar.June, day)
}

// June 2026, with the 15th selected and the 27th as "today".
fn model() -> calendar.Model {
  calendar.init(
    config: calendar.config(),
    selected: Some(time_calendar.Date(2026, time_calendar.June, 15)),
    today: Some(time_calendar.Date(2026, time_calendar.June, 27)),
  )
}

pub fn calendar_markup_test() {
  calendar.calendar(anatomy(), model(), [])
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui calendar — June 2026, selected + today")
}

pub fn calendar_monday_start_test() {
  let config =
    calendar.with_locale(
      calendar.config(),
      calendar.with_week_start(calendar.english(), 1),
    )
  calendar.calendar(
    anatomy(),
    calendar.init(
      config:,
      selected: None,
      today: Some(time_calendar.Date(2026, time_calendar.June, 27)),
    ),
    [],
  )
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui calendar — June 2026, week starts Monday")
}

pub fn calendar_disabled_bounds_test() {
  // Disable everything before the 10th — those day buttons render disabled.
  calendar.calendar(
    anatomy(),
    calendar.disable_before(
      model(),
      time_calendar.Date(2026, time_calendar.June, 10),
    ),
    [],
  )
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui calendar — disabled before June 10")
}

// --- range / multiple / dropdown / multi-month ---------------------------

pub fn calendar_range_test() {
  // A committed June 10–14 range: start/middle/end visuals on the day buttons.
  let model =
    calendar.init(
      config: calendar.Config(..calendar.config(), mode: calendar.range),
      selected: None,
      today: Some(june(27)),
    )
    |> base_calendar.select(june(10))
    |> base_calendar.select(june(14))
  calendar.calendar(anatomy(), model, [])
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui calendar — range June 10–14")
}

pub fn calendar_multiple_test() {
  let model =
    calendar.init(
      config: calendar.Config(..calendar.config(), mode: calendar.multiple),
      selected: None,
      today: Some(june(27)),
    )
    |> base_calendar.select(june(10))
    |> base_calendar.select(june(12))
  calendar.calendar(anatomy(), model, [])
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui calendar — multiple (10 + 12)")
}

pub fn calendar_dropdown_caption_test() {
  // Dropdown caption with a narrow year range so the snapshot stays small.
  let config =
    calendar.Config(
      ..calendar.config(),
      caption_layout: calendar.dropdown,
      year_range: #(2025, 2027),
    )
  calendar.calendar(
    anatomy(),
    calendar.init(config:, selected: None, today: Some(june(27))),
    [],
  )
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui calendar — dropdown caption")
}

pub fn calendar_two_months_test() {
  let config = calendar.Config(..calendar.config(), number_of_months: 2)
  calendar.calendar(
    anatomy(),
    calendar.init(config:, selected: None, today: Some(june(27))),
    [],
  )
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui calendar — two months (June + July)")
}

pub fn calendar_modifier_test() {
  // A `booked` modifier on the 12th–14th: those cells get `data-booked="true"`
  // (the strikethrough recipe keys off it); other cells are untouched.
  let booked =
    calendar.booked(fn(d: time_calendar.Date) { d.day >= 12 && d.day <= 14 })
  calendar.calendar(
    anatomy(),
    calendar.init(
      config: calendar.config(),
      selected: None,
      today: Some(june(27)),
    )
      |> calendar.modifiers([booked]),
    [],
  )
  |> element.to_readable_string
  |> birdie.snap(title: "gg_ui calendar — booked modifier (12–14 struck)")
}
