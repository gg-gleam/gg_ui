//// Tests for the headless calendar. The date engine (`date_math`) is the
//// cross-target-risky part (serial-day arithmetic, leap years, grid assembly),
//// so it gets exhaustive gleeunit unit tests; the grid + a couple of state
//// transitions get birdie snapshots.

import birdie
import gg_base_ui/calendar/calendar as cal
import gg_base_ui/calendar/date_math
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleam/time/calendar.{
  type Date, April, December, February, January, July, June, March, May,
  September,
}
import gleeunit/should

fn date(year: Int, month: calendar.Month, day: Int) -> Date {
  calendar.Date(year:, month:, day:)
}

// --- weekday anchors (0 = Sunday … 6 = Saturday) -------------------------

pub fn day_of_week_anchors_test() {
  // 1970-01-01 was a Thursday.
  date_math.day_of_week(date(1970, January, 1)) |> should.equal(4)
  // 2000-01-01 was a Saturday.
  date_math.day_of_week(date(2000, January, 1)) |> should.equal(6)
  // 2024-02-29 (leap day) was a Thursday.
  date_math.day_of_week(date(2024, February, 29)) |> should.equal(4)
  // 2026-06-27 (a Saturday — "today" in the fixtures below).
  date_math.day_of_week(date(2026, June, 27)) |> should.equal(6)
}

// --- leap years / days in month ------------------------------------------

pub fn days_in_month_test() {
  date_math.days_in_month(2024, February) |> should.equal(29)
  date_math.days_in_month(2023, February) |> should.equal(28)
  date_math.days_in_month(1900, February) |> should.equal(28)
  date_math.days_in_month(2000, February) |> should.equal(29)
  date_math.days_in_month(2026, April) |> should.equal(30)
  date_math.days_in_month(2026, December) |> should.equal(31)
}

// --- add_days across boundaries ------------------------------------------

pub fn add_days_test() {
  date_math.add_days(date(2026, January, 31), 1)
  |> should.equal(date(2026, February, 1))

  date_math.add_days(date(2026, March, 1), -1)
  |> should.equal(date(2026, February, 28))

  // Across a year boundary, backward.
  date_math.add_days(date(2026, January, 1), -1)
  |> should.equal(date(2025, December, 31))

  // Leap-day arithmetic.
  date_math.add_days(date(2024, February, 28), 1)
  |> should.equal(date(2024, February, 29))

  // Round-trip: +n then -n is identity.
  date_math.add_days(date_math.add_days(date(2026, June, 15), 400), -400)
  |> should.equal(date(2026, June, 15))
}

// --- add_months clamps the day -------------------------------------------

pub fn add_months_test() {
  // Jan 31 + 1 month → Feb 28 (2026 is not a leap year).
  date_math.add_months(date(2026, January, 31), 1)
  |> should.equal(date(2026, February, 28))

  // Across a year boundary.
  date_math.add_months(date(2026, December, 15), 1)
  |> should.equal(date(2027, January, 15))

  // Backward across a year boundary.
  date_math.add_months(date(2026, January, 15), -1)
  |> should.equal(date(2025, December, 15))
}

// --- diff_days -----------------------------------------------------------

pub fn diff_days_test() {
  date_math.diff_days(from: date(2026, June, 1), to: date(2026, June, 1))
  |> should.equal(0)
  date_math.diff_days(from: date(2026, June, 1), to: date(2026, June, 8))
  |> should.equal(7)
  date_math.diff_days(
    from: date(2025, December, 31),
    to: date(2026, January, 1),
  )
  |> should.equal(1)
}

// --- start_of_week honours week_starts_on --------------------------------

pub fn start_of_week_test() {
  // 2026-06-27 is a Saturday. Sunday-start week begins 2026-06-21.
  date_math.start_of_week(date(2026, June, 27), week_starts_on: 0)
  |> should.equal(date(2026, June, 21))
  // Monday-start week begins 2026-06-22.
  date_math.start_of_week(date(2026, June, 27), week_starts_on: 1)
  |> should.equal(date(2026, June, 22))
}

pub fn weekday_order_test() {
  date_math.weekday_order(week_starts_on: 0)
  |> should.equal([0, 1, 2, 3, 4, 5, 6])
  date_math.weekday_order(week_starts_on: 1)
  |> should.equal([1, 2, 3, 4, 5, 6, 0])
}

// --- month_grid ----------------------------------------------------------

pub fn month_grid_shape_test() {
  let weeks = date_math.month_grid(2026, June, week_starts_on: 0)
  // Every row is exactly seven days.
  list.each(weeks, fn(week) { list.length(week) |> should.equal(7) })
  // June 2026: 1st is a Monday, 30th a Tuesday → 5 weeks with a Sunday start.
  list.length(weeks) |> should.equal(5)
  // First cell is the Sunday before the 1st (2026-05-31, outside).
  let assert Ok(first_week) = list.first(weeks)
  let assert Ok(first) = list.first(first_week)
  first |> should.equal(date_math.Day(date(2026, May, 31), outside: True))
}

pub fn month_grid_leading_february_test() {
  // Feb 2026 starts on a Sunday → no leading outside days with a Sunday start.
  let weeks = date_math.month_grid(2026, February, week_starts_on: 0)
  let assert Ok(first_week) = list.first(weeks)
  let assert Ok(first) = list.first(first_week)
  first |> should.equal(date_math.Day(date(2026, February, 1), outside: False))
}

pub fn month_grid_snapshot_sunday_test() {
  render_grid(2026, June, 0)
  |> birdie.snap(title: "calendar grid — June 2026, week starts Sunday")
}

pub fn month_grid_snapshot_monday_test() {
  render_grid(2026, June, 1)
  |> birdie.snap(title: "calendar grid — June 2026, week starts Monday")
}

pub fn month_grid_snapshot_leap_february_test() {
  render_grid(2024, February, 0)
  |> birdie.snap(
    title: "calendar grid — February 2024 (leap), week starts Sunday",
  )
}

// --- headless transitions (pure core) ------------------------------------

fn model() -> cal.Model {
  // No selection; today = 2026-06-27 (a Saturday).
  cal.init(
    config: cal.config(),
    selected: None,
    today: Some(date(2026, June, 27)),
  )
}

pub fn init_anchors_on_today_test() {
  // Displayed month opens on today's month, day normalised to 1.
  model().displayed |> should.equal(date(2026, June, 1))
}

pub fn focus_target_defaults_to_today_test() {
  // With no focus or selection, the tabbable day is today (it's in the month).
  cal.focus_target(model()) |> should.equal(date(2026, June, 27))
}

pub fn select_keeps_view_when_visible_test() {
  // July 4 is a trailing day already rendered in June 2026's grid → no jump.
  let m = cal.select(model(), date(2026, July, 4))
  cal.selected(m) |> should.equal(Some(date(2026, July, 4)))
  m.displayed |> should.equal(date(2026, June, 1))
  cal.is_selected(m, date(2026, July, 4)) |> should.equal(True)
}

pub fn select_navigates_when_offscreen_test() {
  // September isn't rendered in June's grid → selecting it moves the view.
  let m = cal.select(model(), date(2026, September, 4))
  cal.selected(m) |> should.equal(Some(date(2026, September, 4)))
  m.displayed |> should.equal(date(2026, September, 1))
}

pub fn month_nav_test() {
  cal.previous_month(model()).displayed |> should.equal(date(2026, May, 1))
  cal.next_month(model()).displayed |> should.equal(date(2026, July, 1))
  cal.previous_year(model()).displayed |> should.equal(date(2025, June, 1))
  cal.next_year(model()).displayed |> should.equal(date(2027, June, 1))
}

pub fn move_focus_crosses_month_boundary_test() {
  // Focus starts on today (06-27); NextWeek lands 07-04 → the view follows.
  let m = cal.move_focus(model(), cal.NextWeek)
  cal.focus_target(m) |> should.equal(date(2026, July, 4))
  m.displayed |> should.equal(date(2026, July, 1))
}

pub fn disabled_bounds_test() {
  let m = cal.disable_before(model(), date(2026, June, 10))
  cal.is_disabled(m, date(2026, June, 9)) |> should.equal(True)
  cal.is_disabled(m, date(2026, June, 10)) |> should.equal(False)
  // A disabled day can't be selected.
  cal.selected(cal.select(m, date(2026, June, 9))) |> should.equal(None)
}

pub fn month_label_test() {
  cal.month_label(model()) |> should.equal("June 2026")
}

// --- multiple selection --------------------------------------------------

fn multi_model() -> cal.Model {
  cal.init(
    config: cal.Config(..cal.config(), mode: cal.Multiple),
    selected: None,
    today: Some(date(2026, June, 27)),
  )
}

pub fn multiple_toggle_test() {
  let m = cal.select(multi_model(), date(2026, June, 10))
  cal.selection(m) |> should.equal(cal.Many([date(2026, June, 10)]))
  // A second day appends in click order.
  let m = cal.select(m, date(2026, June, 12))
  cal.selection(m)
  |> should.equal(cal.Many([date(2026, June, 10), date(2026, June, 12)]))
  // Re-selecting toggles it back off.
  let m = cal.select(m, date(2026, June, 10))
  cal.selection(m) |> should.equal(cal.Many([date(2026, June, 12)]))
}

pub fn multiple_max_count_test() {
  let m =
    cal.init(
      config: cal.Config(..cal.config(), mode: cal.Multiple, max_count: Some(2)),
      selected: None,
      today: Some(date(2026, June, 27)),
    )
  let m = cal.select(m, date(2026, June, 1))
  let m = cal.select(m, date(2026, June, 2))
  // At the cap → the third pick is ignored.
  let m = cal.select(m, date(2026, June, 3))
  cal.selection(m)
  |> should.equal(cal.Many([date(2026, June, 1), date(2026, June, 2)]))
}

// --- range selection -----------------------------------------------------

fn range_model() -> cal.Model {
  cal.init(
    config: cal.Config(..cal.config(), mode: cal.Range),
    selected: None,
    today: Some(date(2026, June, 27)),
  )
}

pub fn range_open_then_commit_test() {
  let m = cal.select(range_model(), date(2026, June, 10))
  cal.selection(m) |> should.equal(cal.Span(date(2026, June, 10), None))
  let m = cal.select(m, date(2026, June, 14))
  cal.selection(m)
  |> should.equal(cal.Span(date(2026, June, 10), Some(date(2026, June, 14))))
}

pub fn range_reanchor_before_start_test() {
  let m = cal.select(range_model(), date(2026, June, 10))
  // A second pick before the start re-anchors a fresh span there.
  let m = cal.select(m, date(2026, June, 5))
  cal.selection(m) |> should.equal(cal.Span(date(2026, June, 5), None))
}

pub fn range_min_length_test() {
  let m =
    cal.init(
      config: cal.Config(..cal.config(), mode: cal.Range, min_length: Some(3)),
      selected: None,
      today: Some(date(2026, June, 27)),
    )
  let m = cal.select(m, date(2026, June, 10))
  // Length 2 < 3 → rejected; the span stays open for another end.
  let m = cal.select(m, date(2026, June, 11))
  cal.selection(m) |> should.equal(cal.Span(date(2026, June, 10), None))
  // Length 3 → commits.
  let m = cal.select(m, date(2026, June, 12))
  cal.selection(m)
  |> should.equal(cal.Span(date(2026, June, 10), Some(date(2026, June, 12))))
}

pub fn range_preview_positions_test() {
  let m = cal.select(range_model(), date(2026, June, 10))
  let m = cal.set_preview(m, date(2026, June, 13))
  cal.day_state(m, date(2026, June, 10)).range |> should.equal(cal.RangeStart)
  cal.day_state(m, date(2026, June, 13)).range |> should.equal(cal.RangeEnd)
  cal.day_state(m, date(2026, June, 11)).range |> should.equal(cal.RangeMiddle)
  cal.day_state(m, date(2026, June, 14)).range |> should.equal(cal.NotInRange)
}

// --- disabled predicate --------------------------------------------------

pub fn disabled_predicate_test() {
  // Disable weekends (Sunday = 0, Saturday = 6).
  let weekend = fn(d) {
    let wd = date_math.day_of_week(d)
    wd == 0 || wd == 6
  }
  let m = cal.disable(model(), weekend)
  // 2026-06-27 is a Saturday; 06-26 a Friday.
  cal.is_disabled(m, date(2026, June, 27)) |> should.equal(True)
  cal.is_disabled(m, date(2026, June, 26)) |> should.equal(False)
  // Selecting a disabled day is a no-op.
  cal.selected(cal.select(m, date(2026, June, 27))) |> should.equal(None)
}

// --- birdie snapshots of the grid model ----------------------------------

fn render_grid(
  year: Int,
  month: calendar.Month,
  week_starts_on: Int,
) -> String {
  date_math.month_grid(year, month, week_starts_on:)
  |> list.map(fn(week) {
    week
    |> list.map(fn(day) {
      let marker = case day.outside {
        True -> "~"
        False -> " "
      }
      pad2(day.date.day) <> marker
    })
    |> string.join(" ")
  })
  |> string.join("\n")
}

// Two-character, zero-padded day-of-month for stable snapshot alignment.
fn pad2(n: Int) -> String {
  case n < 10 {
    True -> "0" <> int.to_string(n)
    False -> int.to_string(n)
  }
}
