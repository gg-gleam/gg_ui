//// Pure calendar date math — the engine the headless `calendar` runs on. **No
//// Lustre, no DOM, no effects**: just arithmetic over `gleam/time/calendar`'s
//// civil `Date`/`Month`. There is no native primitive *and* no Base UI source
//// for a calendar grid (shadcn's Calendar is a skin over `react-day-picker`),
//// so this is ported from react-day-picker's framework-less helpers
//// (`getDates`/`getWeeks`/`getDays`) and the date-fns ops they call, in pure
//// Gleam so it behaves identically on JS and the BEAM (rule 3).
////
//// Weekdays are integers `0 = Sunday … 6 = Saturday` (matching JS `getDay` /
//// react-day-picker). Day arithmetic goes through Howard Hinnant's
//// `days_from_civil` / `civil_from_days` serial-day algorithms — branch-correct
//// for any proleptic-Gregorian date and exact under Gleam's
//// truncate-toward-zero integer division.

import gleam/int
import gleam/list
import gleam/time/calendar.{type Date, type Month, Date}

/// One cell in a month grid: the civil `date` it represents, and whether it
/// falls `outside` the displayed month (a leading/trailing day borrowed from the
/// adjacent month, rendered muted).
pub type Day {
  Day(date: Date, outside: Bool)
}

/// The number of days in `month` of `year`, accounting for leap years (via
/// `calendar.is_leap_year`).
pub fn days_in_month(year year: Int, month month: Month) -> Int {
  case month {
    calendar.January
    | calendar.March
    | calendar.May
    | calendar.July
    | calendar.August
    | calendar.October
    | calendar.December -> 31
    calendar.April | calendar.June | calendar.September | calendar.November ->
      30
    calendar.February ->
      case calendar.is_leap_year(year) {
        True -> 29
        False -> 28
      }
  }
}

/// The weekday of `date`, `0 = Sunday … 6 = Saturday`.
pub fn day_of_week(date: Date) -> Int {
  // 1970-01-01 (serial 0) was a Thursday → `+ 4` lands Sunday at 0.
  mod7(days_from_civil(date) + 4)
}

/// `date` shifted by `n` days (negative shifts backward), crossing month/year
/// boundaries correctly.
pub fn add_days(date: Date, n: Int) -> Date {
  civil_from_days(days_from_civil(date) + n)
}

/// Whole calendar days from `from` to `to` (`to - from`); negative when `to`
/// precedes `from`.
pub fn diff_days(from from: Date, to to: Date) -> Int {
  days_from_civil(to) - days_from_civil(from)
}

/// `date` shifted by `n` months (negative shifts backward). The day is clamped
/// to the target month's length, so e.g. Jan 31 + 1 month → Feb 28/29.
pub fn add_months(date: Date, n: Int) -> Date {
  let total = date.year * 12 + { calendar.month_to_int(date.month) - 1 } + n
  let year = floor_div(total, 12)
  let month_index = floor_mod(total, 12)
  let assert Ok(month) = calendar.month_from_int(month_index + 1)
  let day = int.min(date.day, days_in_month(year:, month:))
  Date(year:, month:, day:)
}

/// The first day of `date`'s month.
pub fn start_of_month(date: Date) -> Date {
  Date(year: date.year, month: date.month, day: 1)
}

/// The last day of `date`'s month.
pub fn end_of_month(date: Date) -> Date {
  Date(
    year: date.year,
    month: date.month,
    day: days_in_month(year: date.year, month: date.month),
  )
}

/// The start of the week containing `date`, given which weekday the week starts
/// on (`week_starts_on`: `0 = Sunday … 6 = Saturday`).
pub fn start_of_week(date: Date, week_starts_on week_starts_on: Int) -> Date {
  let diff = mod7(day_of_week(date) - week_starts_on)
  add_days(date, -diff)
}

/// The end of the week containing `date` (six days after `start_of_week`).
pub fn end_of_week(date: Date, week_starts_on week_starts_on: Int) -> Date {
  add_days(start_of_week(date, week_starts_on:), 6)
}

/// The weekday numbers in display order for a header row, starting from
/// `week_starts_on` and wrapping (e.g. `1` → `[1, 2, 3, 4, 5, 6, 0]`).
pub fn weekday_order(week_starts_on week_starts_on: Int) -> List(Int) {
  int_range(0, 6)
  |> list.map(fn(i) { mod7(week_starts_on + i) })
}

/// The grid of weeks for the month of `year`/`month`, each week a list of seven
/// `Day`s. Leading days complete the first week back to `week_starts_on` and
/// trailing days complete the last — both flagged `outside`. The week count is
/// the natural 4–6 the month needs (react-day-picker's default; not fixed-6).
pub fn month_grid(
  year year: Int,
  month month: Month,
  week_starts_on week_starts_on: Int,
) -> List(List(Day)) {
  let first = Date(year:, month:, day: 1)
  let last = end_of_month(first)
  let grid_start = start_of_week(first, week_starts_on:)
  let grid_end = end_of_week(last, week_starts_on:)
  let span = diff_days(from: grid_start, to: grid_end)
  int_range(0, span)
  |> list.map(fn(offset) {
    let date = add_days(grid_start, offset)
    Day(date:, outside: date.month != month || date.year != year)
  })
  |> list.sized_chunk(into: 7)
}

// --- internal: serial-day arithmetic (Hinnant) ---------------------------

// Days from 1970-01-01 (the serial epoch) for a proleptic-Gregorian date.
fn days_from_civil(date: Date) -> Int {
  let m = calendar.month_to_int(date.month)
  let y = case m <= 2 {
    True -> date.year - 1
    False -> date.year
  }
  // Truncate-toward-zero division matches C++; the conditional handles negatives.
  let era =
    case y >= 0 {
      True -> y
      False -> y - 399
    }
    / 400
  let yoe = y - era * 400
  let mp = case m > 2 {
    True -> m - 3
    False -> m + 9
  }
  let doy = { 153 * mp + 2 } / 5 + date.day - 1
  let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
  era * 146_097 + doe - 719_468
}

// Inverse of `days_from_civil`.
fn civil_from_days(serial: Int) -> Date {
  let z = serial + 719_468
  let era =
    case z >= 0 {
      True -> z
      False -> z - 146_096
    }
    / 146_097
  let doe = z - era * 146_097
  let yoe = { doe - doe / 1460 + doe / 36_524 - doe / 146_096 } / 365
  let y = yoe + era * 400
  let doy = doe - { 365 * yoe + yoe / 4 - yoe / 100 }
  let mp = { 5 * doy + 2 } / 153
  let day = doy - { 153 * mp + 2 } / 5 + 1
  let m = case mp < 10 {
    True -> mp + 3
    False -> mp - 9
  }
  let year = case m <= 2 {
    True -> y + 1
    False -> y
  }
  let assert Ok(month) = calendar.month_from_int(m)
  Date(year:, month:, day:)
}

// Always-non-negative remainder modulo 7 (Gleam `%` follows the sign of the
// dividend, which we don't want for weekday wrap-around).
fn mod7(x: Int) -> Int {
  { x % 7 + 7 } % 7
}

fn floor_div(a: Int, b: Int) -> Int {
  let q = a / b
  case a % b != 0 && { a < 0 } != { b < 0 } {
    True -> q - 1
    False -> q
  }
}

fn floor_mod(a: Int, b: Int) -> Int {
  a - floor_div(a, b) * b
}

// Inclusive integer range `[from, to]` (empty when `from > to`). Local because
// this stdlib pin has no `list.range`; the ranges here are tiny (≤ 42).
fn int_range(from: Int, to: Int) -> List(Int) {
  case from > to {
    True -> []
    False -> [from, ..int_range(from + 1, to)]
  }
}
