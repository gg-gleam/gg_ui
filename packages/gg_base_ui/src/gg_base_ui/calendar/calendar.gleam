//// Headless calendar — a Lustre port of the **behaviour** in shadcn's Calendar.
//// Unlike every other component, there is **no Base UI source** for a calendar:
//// shadcn's Calendar is a thin `classNames` skin over `react-day-picker` v9,
//// which owns the grid, navigation, selection modes, keyboard model and ARIA. So
//// react-day-picker is the behaviour reference here, ported to pure Gleam (its
//// date logic lives in framework-less helpers over date-fns; we reimplement the
//// slice we need in [`date_math`](date_math.gleam)). See
//// [`dev-docs/calendar.md`](../../../../dev-docs/calendar.md) for the full spec and
//// [`dev-docs/stateful-components.md`](../../../../dev-docs/stateful-components.md).
////
//// Two halves, like `combobox`:
////
//// 1. **Pure core** — `Config`/`Localization`/`Model` + pure transitions
////    (`select`, `previous_month`/…, `move_focus`, `set_preview`, `go_to_month`)
////    and selectors (`weeks`, `focus_target`, `day_state`, `is_disabled`). No DOM,
////    no effects, no ARIA. Where the cross-target risk lives → exhaustively tested.
//// 2. **Effectful shell** — the Lustre component: `Anatomy`, `Msg`, `update`
////    (a core transition + the roving-focus DOM effect), and the `calendar` view
////    that renders the WAI-ARIA date-grid and wires click/keydown/hover to `Msg`.
////    The `Classes` record is the seam to the styled layer.
////
//// **Civil dates, no timezone** (react-day-picker's default): the value is a
//// `gleam/time/calendar.Date`; `today` is host-supplied, so this layer is
//// clock-free and deterministic. Three selection **modes** — `Single` /
//// `Multiple` / `Range` — share one `Selection` value and one `day_state` query.

import gg_base_ui/calendar/date_math.{type Day}
import gg_base_ui/calendar/locale/en
import gg_base_ui/calendar/localization
import gg_base_ui/helpers/id_gen/id_gen
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/time/calendar.{type Date, type Month, Date}
import lustre/attribute.{type Attribute}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

// --- Localization (pure data — no Intl, dual-target) ----------------------

/// Writing direction (re-exported from `localization`). `Rtl` mirrors the grid and
/// flips the nav chevrons.
pub type Direction =
  localization.Direction

/// Everything a locale determines (re-exported from `localization`): month/weekday
/// names, week start, and writing direction. The bundled locales own their data in
/// `calendar/locale/*`; this is just the shared type they produce.
pub type Localization =
  localization.Localization

/// The default English localization (matching shadcn's `en-US` default) — a proxy
/// for the `en` locale module, which owns the data.
pub fn english() -> Localization {
  en.locale()
}

/// The translatable UI aria-labels (re-exported from `localization`) — a separate
/// concern from the locale's names. Override on `Config` for i18n.
pub type Labels =
  localization.Labels

/// The default English UI labels.
pub fn english_labels() -> Labels {
  localization.english_labels()
}

// --- Mode / Selection -----------------------------------------------------

/// What a pick produces. `Single` replaces the day; `Multiple` toggles a set;
/// `Range` builds a contiguous span (two clicks, with a live preview between).
pub type Mode {
  Single
  Multiple
  Range
}

/// The selection value, shared across modes. `Span`'s `to` is `None` mid-pick
/// (the start is chosen, the end isn't yet).
pub type Selection {
  Unselected
  One(Date)
  Many(List(Date))
  Span(from: Date, to: Option(Date))
}

/// A day's position in the (effective) range — drives the start/middle/end visuals.
pub type RangePosition {
  NotInRange
  RangeStart
  RangeMiddle
  RangeEnd
}

/// The view's single per-cell query (`day_state`). `selected_single` is
/// `Single`/`Multiple` membership; `range` is the `Range` position (incl. the live
/// preview span). `outside` is *not* here — it's a property of the grid cell, which
/// the view already knows.
pub type DayState {
  DayState(
    selected_single: Bool,
    range: RangePosition,
    today: Bool,
    disabled: Bool,
    focused: Bool,
  )
}

// --- Config --------------------------------------------------------------

/// The header caption: a plain month-year `Label`, or `Dropdown` month/year
/// `<select>`s for fast jumps.
pub type CaptionLayout {
  Label
  Dropdown
}

/// Display + behaviour switches. `mode` is the selection axis; `show_outside_days`
/// renders adjacent-month days; `caption_layout` is label vs dropdown;
/// `number_of_months` renders N grids side-by-side; `year_range` bounds the year
/// dropdown; `localization` supplies names + week start + direction.
///
/// The bounds mirror react-day-picker's `min`/`max` (one pair per multi-pick mode;
/// `None` = unbounded):
/// - `min_count` / `max_count` — **`Multiple`**: the fewest / most days selectable.
///   At `max_count` a new pick is ignored; at `min_count` a day can't be toggled
///   off (RDP's `min` + `required`).
/// - `min_length` / `max_length` — **`Range`**: the shortest / longest span in days
///   (inclusive of both ends). An end that violates either is rejected, leaving the
///   span open for another pick.
pub type Config {
  Config(
    mode: Mode,
    localization: Localization,
    show_outside_days: Bool,
    show_week_numbers: Bool,
    caption_layout: CaptionLayout,
    number_of_months: Int,
    year_range: #(Int, Int),
    min_count: Option(Int),
    max_count: Option(Int),
    min_length: Option(Int),
    max_length: Option(Int),
  )
}

/// The defaults: single select, English (Sunday-start, LTR), outside days shown,
/// no week-number column, label caption, one month, a 1970–2060 year dropdown
/// range, no bounds.
pub fn config() -> Config {
  Config(
    mode: Single,
    localization: english(),
    show_outside_days: True,
    show_week_numbers: False,
    caption_layout: Label,
    number_of_months: 1,
    year_range: #(1970, 2060),
    min_count: None,
    max_count: None,
    min_length: None,
    max_length: None,
  )
}

// --- Navigation ----------------------------------------------------------

/// A focus move within the grid (the keyboard model). Arrows = ±1 day / ±1 week,
/// `WeekStart`/`WeekEnd` = Home/End, `PrevMonth`/`NextMonth` = PageUp/PageDown,
/// `PrevYear`/`NextYear` = Shift+PageUp/PageDown.
pub type Nav {
  PrevDay
  NextDay
  PrevWeek
  NextWeek
  WeekStart
  WeekEnd
  PrevMonth
  NextMonth
  PrevYear
  NextYear
}

// --- Model ---------------------------------------------------------------

/// The calendar's state. `displayed` is the **first** shown month (kept at day 1);
/// `number_of_months` more follow. `selection` is the picked value; `preview` is
/// the tentative range end (hover/keyboard) while a span is open. `focused` is the
/// roving-focus day when one holds focus (`None` → fall back to `focus_target`).
/// `today` (host-supplied) drives the highlight. `min`/`max` + `disabled` (an
/// arbitrary predicate) bound what's selectable.
pub type Model {
  Model(
    displayed: Date,
    selection: Selection,
    preview: Option(Date),
    focused: Option(Date),
    today: Option(Date),
    min: Option(Date),
    max: Option(Date),
    disabled: fn(Date) -> Bool,
    modifiers: List(Modifier),
    config: Config,
  )
}

/// A fresh model. `selected` seeds a `Single` selection; the displayed month
/// anchors on it, else `today`, else the year 2000. Pass `today` (and any
/// `selected`) so the calendar opens on a sensible month.
pub fn init(
  config config: Config,
  selected selected: Option(Date),
  today today: Option(Date),
) -> Model {
  let anchor = case selected, today {
    Some(date), _ -> date
    None, Some(date) -> date
    None, None -> Date(2000, calendar.January, 1)
  }
  Model(
    displayed: date_math.start_of_month(anchor),
    selection: case selected {
      Some(date) -> One(date)
      None -> Unselected
    },
    preview: None,
    focused: None,
    today:,
    min: None,
    max: None,
    disabled: fn(_) { False },
    modifiers: [],
    config:,
  )
}

/// Bound the selectable range to dates on/after `min` (a `disabled` cell otherwise).
pub fn disable_before(model: Model, min: Date) -> Model {
  Model(..model, min: Some(min))
}

/// Bound the selectable range to dates on/before `max`.
pub fn disable_after(model: Model, max: Date) -> Model {
  Model(..model, max: Some(max))
}

/// Disable arbitrary days with a predicate (weekends, holidays, booked days). A
/// disabled day is muted, `aria-disabled`, and skipped by selection. Composes with
/// `min`/`max`.
pub fn disable(model: Model, predicate: fn(Date) -> Bool) -> Model {
  Model(..model, disabled: predicate)
}

/// A named day modifier (react-day-picker's `modifiers`): `matches` decides which
/// days carry it, and the matching cell gets `data-<name>="true"`. **State only —
/// no styling here** (the layer boundary): the styled layer keys its `cn-*` recipe
/// off the `data-<name>` flag, so the look lives in `gg_ui`, never in consumer code.
/// Modifiers are purely visual (pair with `disable` to also block selection — that's
/// shadcn's "booked" demo: struck through *and* unselectable).
pub type Modifier {
  Modifier(name: String, matches: fn(Date) -> Bool)
}

/// Attach visual modifiers (see `Modifier`). Replaces any previously set list.
pub fn modifiers(model: Model, modifiers: List(Modifier)) -> Model {
  Model(..model, modifiers:)
}

// --- Transitions (pure) --------------------------------------------------

/// Act on `date` per the configured `mode`: `Single` replaces; `Multiple` toggles
/// (respecting `max_count`); `Range` opens/commits/re-anchors a span (respecting
/// `min_length`/`max_length`). A disabled date is a no-op. Focus + the displayed
/// window move to keep the acted day visible; any range preview clears.
pub fn select(model: Model, date: Date) -> Model {
  case is_disabled(model, date) {
    True -> model
    False -> {
      let revealed = reveal_selection(model, date)
      let selection = case model.config.mode {
        Single -> One(date)
        Multiple -> toggle_multiple(model, date)
        Range -> select_range(model, date)
      }
      Model(..revealed, selection:, preview: None)
    }
  }
}

fn toggle_multiple(model: Model, date: Date) -> Selection {
  let current = case model.selection {
    Many(dates) -> dates
    One(date) -> [date]
    _ -> []
  }
  case list.contains(current, date) {
    // Toggling off, but never below `min_count`.
    True ->
      case at_min_count(model, list.length(current)) {
        True -> Many(current)
        False -> Many(list.filter(current, fn(d) { d != date }))
      }
    // Toggling on, but never above `max_count`.
    False ->
      case at_max_count(model, list.length(current)) {
        True -> Many(current)
        False -> Many(list.append(current, [date]))
      }
  }
}

fn select_range(model: Model, date: Date) -> Selection {
  case model.selection {
    // A span is open (start chosen, end not): commit, re-anchor, or reject.
    Span(from, None) ->
      case calendar.naive_date_compare(date, from) {
        order.Lt -> Span(from: date, to: None)
        _ ->
          case length_ok(model, from, date) {
            True -> Span(from:, to: Some(date))
            False -> Span(from:, to: None)
          }
      }
    // Nothing open (unselected, single, or a complete span) → start a new span.
    _ -> Span(from: date, to: None)
  }
}

/// Show the previous month (window moves by one) — focus + preview clear.
pub fn previous_month(model: Model) -> Model {
  shift_months(model, -1)
}

/// Show the next month.
pub fn next_month(model: Model) -> Model {
  shift_months(model, 1)
}

/// Show the previous year.
pub fn previous_year(model: Model) -> Model {
  shift_months(model, -12)
}

/// Show the next year.
pub fn next_year(model: Model) -> Model {
  shift_months(model, 12)
}

fn shift_months(model: Model, by: Int) -> Model {
  Model(
    ..model,
    displayed: date_math.add_months(model.displayed, by),
    focused: None,
    preview: None,
  )
}

/// Jump to a specific month (the dropdown caption). `date`'s month becomes the
/// first displayed month.
pub fn go_to_month(model: Model, date: Date) -> Model {
  Model(
    ..model,
    displayed: date_math.start_of_month(date),
    focused: None,
    preview: None,
  )
}

/// Set the tentative range end (`Range` mode, while a span is open) — drives the
/// live middle highlight on hover/keyboard. A no-op outside `Range`.
pub fn set_preview(model: Model, date: Date) -> Model {
  case model.config.mode, model.selection {
    Range, Span(_, None) -> Model(..model, preview: Some(date))
    _, _ -> model
  }
}

/// Clear the range preview (pointer left the grid).
pub fn clear_preview(model: Model) -> Model {
  Model(..model, preview: None)
}

/// Move the roving focus by `nav`, clamped to `min`/`max`, scrolling the displayed
/// window so the focused day stays visible. In `Range` mode it also advances the
/// preview, so a span can be built entirely from the keyboard.
pub fn move_focus(model: Model, nav: Nav) -> Model {
  let base = focus_target(model)
  let next = case nav {
    PrevDay -> date_math.add_days(base, -1)
    NextDay -> date_math.add_days(base, 1)
    PrevWeek -> date_math.add_days(base, -7)
    NextWeek -> date_math.add_days(base, 7)
    WeekStart ->
      date_math.start_of_week(base, model.config.localization.week_starts_on)
    WeekEnd ->
      date_math.end_of_week(base, model.config.localization.week_starts_on)
    PrevMonth -> date_math.add_months(base, -1)
    NextMonth -> date_math.add_months(base, 1)
    PrevYear -> date_math.add_months(base, -12)
    NextYear -> date_math.add_months(base, 12)
  }
  let clamped = clamp(next, model.min, model.max)
  set_preview(reveal(model, clamped), clamped)
}

// Move focus to `date` and scroll the N-month window minimally to include it.
fn reveal(model: Model, date: Date) -> Model {
  let n = model.config.number_of_months
  let first = month_ord(model.displayed)
  let target = month_ord(date)
  let displayed = case target < first, target > first + n - 1 {
    True, _ -> date_math.start_of_month(date)
    _, True -> date_math.add_months(date_math.start_of_month(date), -{ n - 1 })
    _, _ -> model.displayed
  }
  Model(..model, focused: Some(date), displayed:)
}

// Reveal for *selection* (click): if `date` is already on screen (rendered in any
// displayed grid, including as a leading/trailing outside day), DON'T scroll — the
// jarring jump the user hit when committing a range end on a visible next-month
// day. Only scroll when the day isn't visible at all. Roving focus points at the
// date only when it's an in-month cell (so a tabbable cell with an id exists);
// otherwise focus is left where it was (the click already focused the button).
fn reveal_selection(model: Model, date: Date) -> Model {
  case is_rendered(model, date) {
    True ->
      case in_window(model, Some(date)) {
        Some(_) -> Model(..model, focused: Some(date))
        None -> model
      }
    False -> reveal(model, date)
  }
}

// Whether `date` falls inside the rendered grid span (first week of the first
// displayed month … last week of the last displayed month).
fn is_rendered(model: Model, date: Date) -> Bool {
  let wso = model.config.localization.week_starts_on
  let first = model.displayed
  let last = date_math.add_months(first, model.config.number_of_months - 1)
  let lo = date_math.start_of_week(date_math.start_of_month(first), wso)
  let hi = date_math.end_of_week(date_math.end_of_month(last), wso)
  calendar.naive_date_compare(date, lo) != order.Lt
  && calendar.naive_date_compare(date, hi) != order.Gt
}

// --- Selectors (pure reads) ----------------------------------------------

/// The weeks of the **first** displayed month (each a list of seven `Day`s).
pub fn weeks(model: Model) -> List(List(Day)) {
  weeks_of(model, model.displayed)
}

fn weeks_of(model: Model, displayed: Date) -> List(List(Day)) {
  date_math.month_grid(
    displayed.year,
    displayed.month,
    model.config.localization.week_starts_on,
  )
}

/// The day that carries the roving `tabindex=0`: the `focused` day if one holds
/// focus, else a selected/range endpoint visible in the window, else today (if
/// visible), else the first of the first displayed month.
pub fn focus_target(model: Model) -> Date {
  case model.focused {
    Some(date) -> date
    None ->
      case in_window(model, primary_selected(model)) {
        Some(date) -> date
        None ->
          case in_window(model, model.today) {
            Some(date) -> date
            None -> model.displayed
          }
      }
  }
}

// The "main" selected day, for seeding focus: single value, first of a set, or a
// range's start.
fn primary_selected(model: Model) -> Option(Date) {
  case model.selection {
    One(date) -> Some(date)
    Many([first, ..]) -> Some(first)
    Span(from, _) -> Some(from)
    _ -> None
  }
}

/// Everything the view needs about one day, in one query.
pub fn day_state(model: Model, date: Date) -> DayState {
  DayState(
    selected_single: is_member(model, date),
    range: range_position(model, date),
    today: is_today(model, date),
    disabled: is_disabled(model, date),
    focused: model.focused == Some(date),
  )
}

fn is_member(model: Model, date: Date) -> Bool {
  case model.selection {
    One(d) -> d == date
    Many(dates) -> list.contains(dates, date)
    _ -> False
  }
}

fn range_position(model: Model, date: Date) -> RangePosition {
  case effective_span(model) {
    None -> NotInRange
    Some(#(lo, hi)) ->
      case lo == hi {
        True ->
          case date == lo {
            True -> RangeStart
            False -> NotInRange
          }
        False ->
          case
            calendar.naive_date_compare(date, lo),
            calendar.naive_date_compare(date, hi)
          {
            order.Eq, _ -> RangeStart
            _, order.Eq -> RangeEnd
            order.Gt, order.Lt -> RangeMiddle
            _, _ -> NotInRange
          }
      }
  }
}

// The committed range, or `from..preview` while picking (a degenerate `from..from`
// when no preview yet, so the started day still shows as the range start).
fn effective_span(model: Model) -> Option(#(Date, Date)) {
  case model.selection {
    Span(from, Some(to)) -> Some(#(from, to))
    Span(from, None) ->
      case model.preview {
        Some(preview) -> Some(order_pair(from, preview))
        None -> Some(#(from, from))
      }
    _ -> None
  }
}

/// Whether `date` is selected in any mode (drives `aria-selected`).
pub fn is_selected(model: Model, date: Date) -> Bool {
  let state = day_state(model, date)
  state.selected_single || state.range != NotInRange
}

/// Whether `date` is today (host-supplied).
pub fn is_today(model: Model, date: Date) -> Bool {
  model.today == Some(date)
}

/// Whether `date` is unselectable — outside `min`/`max`, or matched by the
/// `disabled` predicate.
pub fn is_disabled(model: Model, date: Date) -> Bool {
  let before_min = case model.min {
    Some(min) -> date_before(date, min)
    None -> False
  }
  let after_max = case model.max {
    Some(max) -> date_before(max, date)
    None -> False
  }
  before_min || after_max || model.disabled(date)
}

/// The whole selection value.
pub fn selection(model: Model) -> Selection {
  model.selection
}

/// The selected day for `Single` (convenience); `None` in other modes / unselected.
pub fn selected(model: Model) -> Option(Date) {
  case model.selection {
    One(date) -> Some(date)
    _ -> None
  }
}

/// The accessible label of the first displayed month, e.g. `"June 2026"`.
pub fn month_label(model: Model) -> String {
  month_label_of(model, model.displayed)
}

fn month_label_of(model: Model, displayed: Date) -> String {
  nth(model.config.localization.month_names, month_index(displayed.month))
  <> " "
  <> int.to_string(displayed.year)
}

// =========================================================================
// EFFECTFUL SHELL — the Lustre component (Anatomy / Msg / update / view)
// =========================================================================

// --- Anatomy -------------------------------------------------------------

/// The stable ids the parts share. Mint **once** (the `useId` analogue) and keep
/// it in the host model; never recompute per render.
pub type Anatomy {
  Anatomy(root_id: String)
}

/// Build an `Anatomy` with a fresh, collision-free base id (the default).
pub fn anatomy() -> Anatomy {
  anatomy_with_id(id_gen.generate_with_prefix("calendar"))
}

/// Build an `Anatomy` from an explicit base id — for tests / SSR pinning.
pub fn anatomy_with_id(id: String) -> Anatomy {
  Anatomy(root_id: id)
}

/// The grid id for the month block at `index` (its `aria-labelledby` target lives
/// alongside).
fn grid_id(anatomy: Anatomy, index: Int) -> String {
  anatomy.root_id <> "-grid-" <> int.to_string(index)
}

fn label_id(anatomy: Anatomy, index: Int) -> String {
  anatomy.root_id <> "-label-" <> int.to_string(index)
}

/// The stable id of an in-month day's button — the roving-focus target. Only
/// in-month cells carry it (outside duplicates across adjacent months would clash).
pub fn day_id(anatomy: Anatomy, date: Date) -> String {
  anatomy.root_id
  <> "-day-"
  <> int.to_string(
    date.year * 10_000 + month_number(date.month) * 100 + date.day,
  )
}

// --- Msg -----------------------------------------------------------------

pub type Msg {
  ShowPreviousMonth
  ShowNextMonth
  ShowPreviousYear
  ShowNextYear
  DaySelected(Date)
  DayPreviewed(Date)
  PreviewCleared
  CaptionMonthPicked(block: Int, month: Int)
  CaptionYearPicked(block: Int, year: Int)
  FocusMoved(Nav)
  Noop
}

// --- update --------------------------------------------------------------

pub fn update(
  anatomy: Anatomy,
  model: Model,
  msg: Msg,
) -> #(Model, Effect(Msg)) {
  case msg {
    ShowPreviousMonth -> #(previous_month(model), effect.none())
    ShowNextMonth -> #(next_month(model), effect.none())
    ShowPreviousYear -> #(previous_year(model), effect.none())
    ShowNextYear -> #(next_year(model), effect.none())
    DaySelected(date) -> #(select(model, date), effect.none())
    DayPreviewed(date) -> #(set_preview(model, date), effect.none())
    PreviewCleared -> #(clear_preview(model), effect.none())
    CaptionMonthPicked(block, month) -> #(
      caption_pick(model, block, fn(shown) {
        let assert Ok(m) = calendar.month_from_int(month)
        Date(shown.year, m, 1)
      }),
      effect.none(),
    )
    CaptionYearPicked(block, year) -> #(
      caption_pick(model, block, fn(shown) { Date(year, shown.month, 1) }),
      effect.none(),
    )
    FocusMoved(nav) -> {
      let next = move_focus(model, nav)
      #(next, focus_effect(anatomy, next))
    }
    Noop -> #(model, effect.none())
  }
}

// The dropdown caption for month block `block` shows `displayed + block` months.
// `pick` maps that shown month to the chosen one; we navigate so the same block
// keeps showing it.
fn caption_pick(model: Model, block: Int, pick: fn(Date) -> Date) -> Model {
  let shown = date_math.add_months(model.displayed, block)
  let target = pick(shown)
  go_to_month(model, date_math.add_months(target, -block))
}

// After a keyboard move, pull DOM focus onto the now-focused day (roving focus).
fn focus_effect(anatomy: Anatomy, model: Model) -> Effect(Msg) {
  case model.focused {
    Some(date) ->
      effect.from(fn(_dispatch) { focus_day(day_id(anatomy, date)) })
    None -> effect.none()
  }
}

/// The day a `DaySelected` acted on (for the host to react to — close a popover in
/// the date picker, etc.). `None` for any other message.
pub fn selected_date(msg: Msg) -> Option(Date) {
  case msg {
    DaySelected(date) -> Some(date)
    _ -> None
  }
}

// --- view ----------------------------------------------------------------

/// The `cn-*` class strings for every slot + the nav-chevron `Element`s. The seam
/// the styled layer fills; the headless layer holds no styling.
pub type Classes {
  Classes(
    root: String,
    months: String,
    month: String,
    nav: String,
    nav_previous: String,
    nav_next: String,
    caption: String,
    dropdowns: String,
    dropdown: String,
    dropdown_select: String,
    dropdown_label: String,
    grid: String,
    weekdays: String,
    weekday: String,
    week_number_header: String,
    week_number: String,
    week: String,
    day: String,
    day_button: String,
  )
}

/// Render the calendar: prev/next nav + `number_of_months` month blocks (each a
/// caption + WAI-ARIA date grid). `previous_icon`/`next_icon` are the chevron
/// glyphs (the styled layer passes lucide). Click/keydown/hover wire to `Msg`.
pub fn calendar(
  anatomy anatomy: Anatomy,
  model model: Model,
  classes classes: Classes,
  previous_icon previous_icon: Element(Msg),
  next_icon next_icon: Element(Msg),
  dropdown_icon dropdown_icon: Element(Msg),
  attrs attrs: List(Attribute(Msg)),
) -> Element(Msg) {
  let blocks =
    int_range(0, model.config.number_of_months - 1)
    |> list.map(fn(index) {
      month_block(anatomy, classes, model, dropdown_icon, index)
    })
  html.div(
    list.flatten([
      [
        attribute.id(anatomy.root_id),
        attribute.attribute("data-slot", "calendar"),
        attribute.class(classes.root),
      ],
      direction_attr(model),
      attrs,
    ]),
    [
      html.div(
        [attribute.class(classes.months)],
        // The single absolute nav lives in the `relative` months wrapper, inside
        // the root padding (so prev/next inset rather than hit the border corner).
        [
          nav(
            classes,
            model.config.localization.labels,
            previous_icon,
            next_icon,
          ),
          ..blocks
        ],
      ),
    ],
  )
}

fn month_block(
  anatomy: Anatomy,
  classes: Classes,
  model: Model,
  dropdown_icon: Element(Msg),
  index: Int,
) -> Element(Msg) {
  let displayed = date_math.add_months(model.displayed, index)
  html.div([attribute.class(classes.month)], [
    caption(anatomy, classes, model, dropdown_icon, displayed, index),
    grid(anatomy, classes, model, displayed, index),
  ])
}

// Emit `dir="rtl"` for RTL locales so the grid mirrors and the `rtl:` chevron-flip
// activates; LTR inherits (no attribute).
fn direction_attr(model: Model) -> List(Attribute(Msg)) {
  case model.config.localization.direction {
    localization.Rtl -> [attribute.attribute("dir", "rtl")]
    localization.Ltr -> []
  }
}

fn nav(
  classes: Classes,
  labels: localization.Labels,
  previous_icon: Element(Msg),
  next_icon: Element(Msg),
) -> Element(Msg) {
  html.div([attribute.class(classes.nav)], [
    html.button(
      [
        attribute.attribute("type", "button"),
        attribute.attribute("aria-label", labels.previous_month),
        attribute.class(classes.nav_previous),
        event.on_click(ShowPreviousMonth),
      ],
      [previous_icon],
    ),
    html.button(
      [
        attribute.attribute("type", "button"),
        attribute.attribute("aria-label", labels.next_month),
        attribute.class(classes.nav_next),
        event.on_click(ShowNextMonth),
      ],
      [next_icon],
    ),
  ])
}

fn caption(
  anatomy: Anatomy,
  classes: Classes,
  model: Model,
  dropdown_icon: Element(Msg),
  displayed: Date,
  index: Int,
) -> Element(Msg) {
  case model.config.caption_layout {
    Label ->
      html.div(
        [
          attribute.id(label_id(anatomy, index)),
          attribute.attribute("aria-live", "polite"),
          attribute.class(classes.caption),
        ],
        [html.text(month_label_of(model, displayed))],
      )
    Dropdown ->
      html.div(
        [
          attribute.id(label_id(anatomy, index)),
          attribute.attribute("aria-live", "polite"),
          attribute.class(classes.dropdowns),
        ],
        [
          month_dropdown(classes, model, dropdown_icon, displayed, index),
          year_dropdown(classes, model, dropdown_icon, displayed, index),
        ],
      )
  }
}

fn month_dropdown(
  classes: Classes,
  model: Model,
  dropdown_icon: Element(Msg),
  displayed: Date,
  index: Int,
) -> Element(Msg) {
  let options =
    int_range(1, 12)
    |> list.map(fn(m) {
      option_tag(
        int.to_string(m),
        nth(model.config.localization.month_names, m - 1),
        m == month_number(displayed.month),
      )
    })
  dropdown(
    classes,
    dropdown_icon,
    model.config.localization.labels.month_dropdown,
    nth(model.config.localization.month_names, month_index(displayed.month)),
    index,
    options,
    fn(block, value) { CaptionMonthPicked(block, value) },
  )
}

fn year_dropdown(
  classes: Classes,
  model: Model,
  dropdown_icon: Element(Msg),
  displayed: Date,
  index: Int,
) -> Element(Msg) {
  let #(from, to) = model.config.year_range
  let options =
    int_range(from, to)
    |> list.map(fn(y) {
      option_tag(int.to_string(y), int.to_string(y), y == displayed.year)
    })
  dropdown(
    classes,
    dropdown_icon,
    model.config.localization.labels.year_dropdown,
    int.to_string(displayed.year),
    index,
    options,
    fn(block, value) { CaptionYearPicked(block, value) },
  )
}

// shadcn's dropdown: a styled label (the value + a small chevron) with the real
// `<select>` overlaid `opacity-0` on top — so it's borderless text, not a boxed
// native select, while the select still owns keyboard/a11y/interaction.
fn dropdown(
  classes: Classes,
  dropdown_icon: Element(Msg),
  label: String,
  value: String,
  index: Int,
  options: List(Element(Msg)),
  to_msg: fn(Int, Int) -> Msg,
) -> Element(Msg) {
  html.div([attribute.class(classes.dropdown)], [
    html.select(
      [
        attribute.attribute("aria-label", label),
        attribute.class(classes.dropdown_select),
        event.on("change", dropdown_decoder(index, to_msg)),
      ],
      options,
    ),
    html.span(
      [
        attribute.class(classes.dropdown_label),
        attribute.attribute("aria-hidden", "true"),
      ],
      [
        html.text(value),
        dropdown_icon,
      ],
    ),
  ])
}

fn dropdown_decoder(
  index: Int,
  to_msg: fn(Int, Int) -> Msg,
) -> decode.Decoder(Msg) {
  use value <- decode.subfield(["target", "value"], decode.string)
  case int.parse(value) {
    Ok(parsed) -> decode.success(to_msg(index, parsed))
    Error(_) -> decode.success(Noop)
  }
}

fn option_tag(value: String, label: String, selected: Bool) -> Element(Msg) {
  html.option(
    list.flatten([
      [attribute.value(value)],
      case selected {
        True -> [attribute.attribute("selected", "")]
        False -> []
      },
    ]),
    label,
  )
}

fn grid(
  anatomy: Anatomy,
  classes: Classes,
  model: Model,
  displayed: Date,
  index: Int,
) -> Element(Msg) {
  html.table(
    [
      attribute.id(grid_id(anatomy, index)),
      attribute.attribute("role", "grid"),
      attribute.attribute("aria-labelledby", label_id(anatomy, index)),
      attribute.class(classes.grid),
    ],
    [
      html.thead([], [
        html.tr(
          [
            attribute.attribute("role", "row"),
            attribute.class(classes.weekdays),
          ],
          list.flatten([
            week_number_header(classes, model),
            list.map(
              date_math.weekday_order(model.config.localization.week_starts_on),
              fn(wd) { weekday_header(classes, model, wd) },
            ),
          ]),
        ),
      ]),
      html.tbody(
        [],
        list.map(weeks_of(model, displayed), fn(week) {
          week_row(anatomy, classes, model, week)
        }),
      ),
    ],
  )
}

// A week row. The range "track" rounds at each row segment's ends — computed here
// (not in CSS) so it's correct whatever the outside-days setting: a cell is a
// left/right cap when it's in-range and its in-row neighbour on that side isn't.
fn week_row(
  anatomy: Anatomy,
  classes: Classes,
  model: Model,
  week: List(Day),
) -> Element(Msg) {
  let flags = list.map(week, fn(day) { cell_in_range(model, day) })
  html.tr(
    [attribute.attribute("role", "row"), attribute.class(classes.week)],
    list.flatten([
      week_number_cell(classes, model, week),
      list.index_map(week, fn(day, i) {
        let here = at_bool(flags, i)
        day_cell(
          anatomy,
          classes,
          model,
          day,
          here && !at_bool(flags, i - 1),
          here && !at_bool(flags, i + 1),
        )
      }),
    ]),
  )
}

// The leading ISO week-number column (shadcn's `showWeekNumber`), opt-in via
// `Config.show_week_numbers`. The header is a blank spacer cell; each row carries
// the ISO week number of its first day (ISO weeks are Monday-based, so this is
// the date-fns/react-day-picker convention). Hidden from a11y — it's a visual
// aid, not part of the date-grid semantics.
fn week_number_header(classes: Classes, model: Model) -> List(Element(Msg)) {
  case model.config.show_week_numbers {
    False -> []
    True -> [
      html.th(
        [
          attribute.attribute("scope", "col"),
          attribute.attribute("aria-hidden", "true"),
          attribute.class(classes.week_number_header),
        ],
        [],
      ),
    ]
  }
}

fn week_number_cell(
  classes: Classes,
  model: Model,
  week: List(Day),
) -> List(Element(Msg)) {
  case model.config.show_week_numbers, week {
    True, [first, ..] -> [
      html.td(
        [
          attribute.attribute("aria-hidden", "true"),
          attribute.class(classes.week_number),
        ],
        [html.text(int.to_string(date_math.iso_week_number(first.date)))],
      ),
    ]
    _, _ -> []
  }
}

// A *rendered* cell that's part of the range — contributes to the row's track.
fn cell_in_range(model: Model, day: Day) -> Bool {
  let rendered = !day.outside || model.config.show_outside_days
  rendered && day_state(model, day.date).range != NotInRange
}

fn at_bool(flags: List(Bool), index: Int) -> Bool {
  case index >= 0, list.drop(flags, index) {
    True, [first, ..] -> first
    _, _ -> False
  }
}

fn weekday_header(
  classes: Classes,
  model: Model,
  weekday: Int,
) -> Element(Msg) {
  html.th(
    [
      attribute.attribute("role", "columnheader"),
      attribute.attribute("scope", "col"),
      attribute.attribute(
        "abbr",
        nth(model.config.localization.weekday_long, weekday),
      ),
      attribute.class(classes.weekday),
    ],
    [html.text(nth(model.config.localization.weekday_short, weekday))],
  )
}

fn day_cell(
  anatomy: Anatomy,
  classes: Classes,
  model: Model,
  day: Day,
  left_cap: Bool,
  right_cap: Bool,
) -> Element(Msg) {
  let date = day.date
  case day.outside && !model.config.show_outside_days {
    True ->
      html.td(
        [
          attribute.attribute("role", "gridcell"),
          attribute.attribute("aria-hidden", "true"),
          attribute.class(classes.day),
        ],
        [],
      )
    False -> {
      let state = day_state(model, date)
      // Active modifiers each flag the cell with `data-<name>="true"`; the styled
      // layer's `cn-calendar-day` recipe keys its look off that flag (no style here).
      let active = list.filter(model.modifiers, fn(m) { m.matches(date) })
      // Range state is mirrored on the cell: the muted *track* lives on the `td`,
      // with the endpoint pill on the button on top (shadcn's two-layer visual).
      // `data-range-cap-*` round the track at each row segment's ends.
      html.td(
        list.flatten([
          [
            attribute.attribute("role", "gridcell"),
            attribute.attribute(
              "aria-selected",
              bool_attr(is_selected(model, date)),
            ),
            attribute.class(classes.day),
          ],
          list.map(active, fn(m) {
            attribute.attribute("data-" <> m.name, "true")
          }),
          range_attrs(state.range),
          state_attr("data-range-cap-left", left_cap),
          state_attr("data-range-cap-right", right_cap),
          // `today` lives on the cell (not the button) so its muted highlight
          // never fights the selected pill's text colour — shadcn's split.
          // `data-today-pill` rounds it only when *not* in a range, so a today
          // that's a range end keeps the track's square inner edge (rounding
          // there is owned by the range caps).
          state_attr("data-today", state.today),
          state_attr(
            "data-today-pill",
            state.today && state.range == NotInRange,
          ),
        ]),
        [day_button(anatomy, classes, model, day, state)],
      )
    }
  }
}

fn day_button(
  anatomy: Anatomy,
  classes: Classes,
  model: Model,
  day: Day,
  state: DayState,
) -> Element(Msg) {
  let date = day.date
  // The same date appears as an in-month cell in one month and an *outside* cell in
  // an adjacent one. Only the in-month cell is the roving-focus target — it alone
  // gets the id (duplicate ids would clash), the `tabindex=0`, and `data-focused`.
  let in_month = !day.outside
  let tabbable = in_month && !state.disabled && date == focus_target(model)
  let identity = case in_month {
    True -> [attribute.id(day_id(anatomy, date))]
    False -> []
  }
  let base = [
    attribute.attribute("type", "button"),
    attribute.attribute("data-slot", "calendar-day"),
    attribute.attribute("aria-label", day_label(model, date)),
    attribute.attribute("tabindex", case tabbable {
      True -> "0"
      False -> "-1"
    }),
    attribute.class(classes.day_button),
  ]
  let data =
    state_attr("data-selected-single", state.selected_single)
    |> list.append(range_attrs(state.range))
    |> list.append(state_attr("data-outside", day.outside))
    |> list.append(state_attr("data-focused", state.focused && in_month))
  let behaviour = case state.disabled {
    True -> [
      attribute.disabled(True),
      attribute.attribute("aria-disabled", "true"),
    ]
    False ->
      list.flatten([
        [
          event.on_click(DaySelected(date)),
          event.advanced("keydown", day_keydown_handler(date)),
        ],
        // Range hover preview — only meaningful while a span is open, but harmless
        // otherwise (the transition self-guards on mode/selection).
        case model.config.mode {
          Range -> [event.on_mouse_enter(DayPreviewed(date))]
          _ -> []
        },
      ])
  }
  html.button(list.flatten([identity, base, data, behaviour]), [
    html.text(int.to_string(date.day)),
  ])
}

fn range_attrs(range: RangePosition) -> List(Attribute(msg)) {
  case range {
    NotInRange -> []
    RangeStart -> [attribute.attribute("data-range-start", "true")]
    RangeMiddle -> [attribute.attribute("data-range-middle", "true")]
    RangeEnd -> [attribute.attribute("data-range-end", "true")]
  }
}

fn day_keydown_handler(date: Date) -> decode.Decoder(event.Handler(Msg)) {
  use key <- decode.field("key", decode.string)
  use shift <- decode.optional_field("shiftKey", False, decode.bool)
  case key {
    "ArrowLeft" -> decode.success(nav_handler(FocusMoved(PrevDay)))
    "ArrowRight" -> decode.success(nav_handler(FocusMoved(NextDay)))
    "ArrowUp" -> decode.success(nav_handler(FocusMoved(PrevWeek)))
    "ArrowDown" -> decode.success(nav_handler(FocusMoved(NextWeek)))
    "Home" -> decode.success(nav_handler(FocusMoved(WeekStart)))
    "End" -> decode.success(nav_handler(FocusMoved(WeekEnd)))
    "PageUp" ->
      decode.success(
        nav_handler(
          FocusMoved(case shift {
            True -> PrevYear
            False -> PrevMonth
          }),
        ),
      )
    "PageDown" ->
      decode.success(
        nav_handler(
          FocusMoved(case shift {
            True -> NextYear
            False -> NextMonth
          }),
        ),
      )
    "Enter" | " " -> decode.success(nav_handler(DaySelected(date)))
    _ -> decode.failure(nav_handler(Noop), "calendar-ignored-key")
  }
}

fn nav_handler(msg: Msg) -> event.Handler(Msg) {
  event.handler(dispatch: msg, prevent_default: True, stop_propagation: False)
}

// --- FFI -----------------------------------------------------------------
//
// JS-only roving focus; the Erlang fallback never runs (effects are client-side),
// so an SSR render produces the markup with no client effect.

@external(javascript, "./calendar_ffi.ts", "focusDay")
fn focus_day(_day_id: String) -> Nil {
  Nil
}

// --- internal helpers ----------------------------------------------------

fn clamp(date: Date, min: Option(Date), max: Option(Date)) -> Date {
  let date = case min {
    Some(m) ->
      case calendar.naive_date_compare(date, m) {
        order.Lt -> m
        _ -> date
      }
    None -> date
  }
  case max {
    Some(m) ->
      case calendar.naive_date_compare(date, m) {
        order.Gt -> m
        _ -> date
      }
    None -> date
  }
}

// True when `a` is strictly before `b`.
fn date_before(a: Date, b: Date) -> Bool {
  calendar.naive_date_compare(a, b) == order.Lt
}

fn order_pair(a: Date, b: Date) -> #(Date, Date) {
  case calendar.naive_date_compare(a, b) {
    order.Gt -> #(b, a)
    _ -> #(a, b)
  }
}

// Months since year 0 — a total order over (year, month) for window math.
fn month_ord(date: Date) -> Int {
  date.year * 12 + month_index(date.month)
}

fn in_window(model: Model, date: Option(Date)) -> Option(Date) {
  case date {
    Some(d) -> {
      let first = month_ord(model.displayed)
      let ord = month_ord(d)
      case ord >= first && ord < first + model.config.number_of_months {
        True -> Some(d)
        False -> None
      }
    }
    None -> None
  }
}

fn at_max_count(model: Model, current: Int) -> Bool {
  case model.config.max_count {
    Some(max) -> current >= max
    None -> False
  }
}

fn at_min_count(model: Model, current: Int) -> Bool {
  case model.config.min_count {
    Some(min) -> current <= min
    None -> False
  }
}

fn length_ok(model: Model, from: Date, to: Date) -> Bool {
  let len = date_math.diff_days(from:, to:) + 1
  let min_ok = case model.config.min_length {
    Some(min) -> len >= min
    None -> True
  }
  let max_ok = case model.config.max_length {
    Some(max) -> len <= max
    None -> True
  }
  min_ok && max_ok
}

fn day_label(model: Model, date: Date) -> String {
  nth(model.config.localization.month_names, month_index(date.month))
  <> " "
  <> int.to_string(date.day)
  <> ", "
  <> int.to_string(date.year)
}

fn month_index(month: Month) -> Int {
  calendar.month_to_int(month) - 1
}

fn month_number(month: Month) -> Int {
  calendar.month_to_int(month)
}

fn state_attr(name: String, on: Bool) -> List(Attribute(msg)) {
  case on {
    True -> [attribute.attribute(name, "true")]
    False -> []
  }
}

fn bool_attr(value: Bool) -> String {
  case value {
    True -> "true"
    False -> "false"
  }
}

fn nth(items: List(String), index: Int) -> String {
  case list.drop(items, index) {
    [first, ..] -> first
    [] -> ""
  }
}

// Inclusive integer range `[from, to]` (empty when `from > to`).
fn int_range(from: Int, to: Int) -> List(Int) {
  case from > to {
    True -> []
    False -> [from, ..int_range(from + 1, to)]
  }
}
