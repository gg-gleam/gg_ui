//// Story mount for the styled `Calendar` — a *stateful* story (`lustre.application`).
//// The host owns the `Model` + `Anatomy` and threads the opaque `Msg` through
//// `calendar.update`. Nav chevrons are built into the component (lucide).
////
//// `today` is **fixed to 2026-06-27** so the demo + play tests are deterministic.
//// The standalone border is opt-in at the call site (`attrs`), mirroring shadcn's
//// demo (`<Calendar className="rounded-md border shadow-sm" />`).

// Locale data lives in gg_base_ui (like the icon sets) — a real consumer imports
// the locales it wants directly; the styled API is still only `gg_ui`.
import gg_base_ui/calendar/locale/ar
import gg_base_ui/calendar/locale/de
import gg_base_ui/calendar/locale/en
import gg_base_ui/calendar/locale/es
import gg_base_ui/calendar/locale/fa
import gg_base_ui/calendar/locale/fr
import gg_base_ui/calendar/locale/he
import gg_base_ui/calendar/locale/hi
import gg_base_ui/calendar/locale/ja
import gg_base_ui/calendar/locale/ko
import gg_base_ui/calendar/locale/pt
import gg_base_ui/calendar/locale/ru
import gg_base_ui/calendar/locale/th
import gg_base_ui/calendar/locale/zh
import gg_ui/ui/button
import gg_ui/ui/calendar
import gg_ui/ui/text
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import gleam/time/calendar as time_calendar
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

type Flags {
  Flags(
    config: calendar.Config,
    selected: Option(time_calendar.Date),
    disable_past: Bool,
    hint: Option(String),
  )
}

type Model {
  Model(cal: calendar.Model, anatomy: calendar.Anatomy, hint: Option(String))
}

type Msg {
  CalendarMsg(calendar.Msg)
}

// Fixed "today" so the demo opens on a known month (June 2026) and play tests can
// reference concrete dates without depending on the wall clock.
fn today() -> time_calendar.Date {
  time_calendar.Date(2026, time_calendar.June, 27)
}

fn init(flags: Flags) -> #(Model, Effect(Msg)) {
  let anatomy = calendar.anatomy_with_id("calendar-story")
  let cal =
    calendar.init(
      config: flags.config,
      selected: flags.selected,
      today: Some(today()),
    )
  let cal = case flags.disable_past {
    True -> calendar.disable_before(cal, today())
    False -> cal
  }
  #(Model(cal:, anatomy:, hint: flags.hint), effect.none())
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    CalendarMsg(cal_msg) -> {
      let #(cal, eff) = calendar.update(model.anatomy, model.cal, cal_msg)
      #(Model(..model, cal:), effect.map(eff, CalendarMsg))
    }
  }
}

fn view(model: Model) -> Element(Msg) {
  // shadcn's standalone look: border on the calendar itself via attrs (not a
  // wrapper) — the component bakes in none so it sits clean inside a popover.
  let widget =
    element.map(
      calendar.calendar(model.anatomy, model.cal, [
        attribute.class("rounded-md border shadow-sm"),
      ]),
      CalendarMsg,
    )
  let hint = case model.hint {
    Some(text_) -> [text.s6([text.color(text.Muted)], [html.text(text_)])]
    None -> []
  }
  html.div(
    [attribute.class("flex flex-col items-center gap-3 text-foreground")],
    list.flatten([hint, [widget, selected_line(model)]]),
  )
}

// Dogfood the kit (rule 6): the status line is our `text` component. Reads the
// selection through the typed readers, so it works for every mode.
fn selected_line(model: Model) -> Element(Msg) {
  let label = case
    calendar.selected_range(model.cal),
    calendar.selected(model.cal),
    calendar.selected_dates(model.cal)
  {
    Some(#(from, Some(to))), _, _ ->
      "Range: " <> format_date(from) <> " – " <> format_date(to)
    Some(#(from, None)), _, _ -> "Range start: " <> format_date(from) <> " – …"
    _, Some(date), _ -> "Selected: " <> format_date(date)
    _, _, [_, ..] as dates ->
      int.to_string(list.length(dates))
      <> " selected: "
      <> string.join(list.map(dates, format_date), ", ")
    _, _, _ -> "Nothing selected"
  }
  text.s6([text.color(text.Muted)], [html.text(label)])
}

fn format_date(date: time_calendar.Date) -> String {
  time_calendar.month_to_string(date.month)
  <> " "
  <> int.to_string(date.day)
  <> ", "
  <> int.to_string(date.year)
}

// --- mount ---------------------------------------------------------------

fn start(flags: Flags, selector: String) -> Nil {
  let assert Ok(_) =
    lustre.start(lustre.application(init, update, view), selector, flags)
  Nil
}

fn flags(config: calendar.Config) -> Flags {
  Flags(config:, selected: None, disable_past: False, hint: None)
}

pub fn mount_calendar_playground(
  selector: String,
  week_start: String,
  show_outside: Bool,
  mode: String,
  caption: String,
  months: Int,
) -> Nil {
  let config =
    calendar.Config(
      ..calendar.config(),
      mode: parse_mode(mode),
      localization: calendar.with_week_start(
        calendar.english(),
        parse_week_start(week_start),
      ),
      show_outside_days: show_outside,
      caption_layout: parse_caption(caption),
      number_of_months: int.max(1, months),
    )
  start(flags(config), selector)
}

pub fn mount_calendar_with_selected(selector: String) -> Nil {
  start(
    Flags(
      ..flags(calendar.config()),
      selected: Some(time_calendar.Date(2026, time_calendar.June, 15)),
    ),
    selector,
  )
}

pub fn mount_calendar_range(selector: String, show_outside: Bool) -> Nil {
  start(
    flags(
      calendar.Config(
        ..calendar.config(),
        mode: calendar.range,
        show_outside_days: show_outside,
      ),
    ),
    selector,
  )
}

pub fn mount_calendar_count_bounds(selector: String) -> Nil {
  // Multiple selection bounded to 1–3 days: at 3 a new pick is ignored; the last
  // remaining day can't be toggled off.
  start(
    flags(
      calendar.Config(
        ..calendar.config(),
        mode: calendar.multiple,
        min_count: Some(1),
        max_count: Some(3),
      ),
    ),
    selector,
  )
}

pub fn mount_calendar_multiple(selector: String) -> Nil {
  start(
    flags(calendar.Config(..calendar.config(), mode: calendar.multiple)),
    selector,
  )
}

pub fn mount_calendar_required(selector: String, required: Bool) -> Nil {
  // Starts with June 15 selected. `required` has no resting visual — the
  // difference shows when you click the *already-selected* day: OFF clears it
  // (RDP toggle-off), ON keeps it. The hint + status line make that observable.
  let hint = case required {
    True -> "Required is ON — click June 15 (selected): it stays selected."
    False -> "Required is OFF — click June 15 (selected): it clears."
  }
  start(
    Flags(
      ..flags(calendar.with_required(calendar.config(), required)),
      selected: Some(time_calendar.Date(2026, time_calendar.June, 15)),
      hint: Some(hint),
    ),
    selector,
  )
}

pub fn mount_calendar_week_numbers(selector: String) -> Nil {
  // The leading ISO week-number column, paired with a Monday week-start (the
  // natural pairing — ISO weeks are Monday-based).
  start(
    flags(calendar.with_locale(
      calendar.with_week_numbers(calendar.config(), True),
      calendar.with_week_start(calendar.english(), 1),
    )),
    selector,
  )
}

pub fn mount_calendar_two_months(selector: String) -> Nil {
  start(
    flags(
      calendar.Config(
        ..calendar.config(),
        mode: calendar.range,
        number_of_months: 2,
      ),
    ),
    selector,
  )
}

pub fn mount_calendar_dropdown(selector: String) -> Nil {
  start(
    flags(
      calendar.Config(
        ..calendar.config(),
        caption_layout: calendar.dropdown,
        year_range: #(2015, 2035),
      ),
    ),
    selector,
  )
}

pub fn mount_calendar_disabled(selector: String) -> Nil {
  start(Flags(..flags(calendar.config()), disable_past: True), selector)
}

pub fn mount_calendar_locale(selector: String, locale: String) -> Nil {
  // Dropdown caption so the translated month names + month/year aria-labels show;
  // RTL locales (ar/he/fa) also mirror the whole grid automatically.
  start(
    flags(
      calendar.Config(
        ..calendar.config(),
        localization: parse_locale(locale),
        caption_layout: calendar.dropdown,
      ),
    ),
    selector,
  )
}

// Map the control string to a bundled locale (safe English fallback).
fn parse_locale(code: String) -> calendar.Localization {
  case code {
    "es" -> es.locale()
    "fr" -> fr.locale()
    "de" -> de.locale()
    "pt" -> pt.locale()
    "ru" -> ru.locale()
    "ja" -> ja.locale()
    "ko" -> ko.locale()
    "zh" -> zh.locale()
    "hi" -> hi.locale()
    "th" -> th.locale()
    "ar" -> ar.locale()
    "he" -> he.locale()
    "fa" -> fa.locale()
    _ -> en.locale()
  }
}

// --- interactive disabled-days demo (its own MVU loop) -------------------
//
// A realistic `disable` example: the host owns the set of blocked days in local
// state and the predicate reads it, so toggling a day's block updates the
// disabled cells live (and blocked days can't be selected). Think "already-booked
// slots". A separate app from the shared playground because it carries extra state.

const blockable_days = [10, 13, 20, 25]

type BlockedModel {
  BlockedModel(
    cal: calendar.Model,
    anatomy: calendar.Anatomy,
    blocked: List(Int),
  )
}

type BlockedMsg {
  BlockedCalendar(calendar.Msg)
  ToggleBlock(Int)
}

// The predicate closes over the current blocked set (June 2026, by day-of-month).
fn block_predicate(blocked: List(Int)) -> fn(time_calendar.Date) -> Bool {
  fn(d: time_calendar.Date) {
    d.year == 2026
    && d.month == time_calendar.June
    && list.contains(blocked, d.day)
  }
}

// Apply the same predicate as both a `disable` (can't pick) and a `booked` modifier
// (strikethrough — the kit owns the look) — shadcn's booked-dates demo. Re-applied
// whenever the set changes.
fn apply_blocked(cal: calendar.Model, blocked: List(Int)) -> calendar.Model {
  let pred = block_predicate(blocked)
  cal
  |> calendar.disable(pred)
  |> calendar.modifiers([calendar.booked(pred)])
}

fn blocked_init(_flags: Nil) -> #(BlockedModel, Effect(BlockedMsg)) {
  let blocked = [13, 20]
  let cal =
    calendar.init(
      config: calendar.config(),
      selected: None,
      today: Some(today()),
    )
    |> apply_blocked(blocked)
  #(
    BlockedModel(
      cal:,
      anatomy: calendar.anatomy_with_id("calendar-blocked"),
      blocked:,
    ),
    effect.none(),
  )
}

fn blocked_update(
  model: BlockedModel,
  msg: BlockedMsg,
) -> #(BlockedModel, Effect(BlockedMsg)) {
  case msg {
    BlockedCalendar(cal_msg) -> {
      let #(cal, eff) = calendar.update(model.anatomy, model.cal, cal_msg)
      #(BlockedModel(..model, cal:), effect.map(eff, BlockedCalendar))
    }
    ToggleBlock(day) -> {
      let blocked = case list.contains(model.blocked, day) {
        True -> list.filter(model.blocked, fn(d) { d != day })
        False -> [day, ..model.blocked]
      }
      // Re-apply disable + booked modifier over the new set.
      let cal = apply_blocked(model.cal, blocked)
      #(BlockedModel(..model, cal:, blocked:), effect.none())
    }
  }
}

fn blocked_view(model: BlockedModel) -> Element(BlockedMsg) {
  let widget =
    element.map(
      calendar.calendar(model.anatomy, model.cal, [
        attribute.class("rounded-md border shadow-sm"),
      ]),
      BlockedCalendar,
    )
  html.div(
    [attribute.class("flex flex-col items-center gap-3 text-foreground")],
    [
      widget,
      html.div(
        [attribute.class("flex flex-wrap justify-center gap-2")],
        list.map(blockable_days, fn(day) {
          let on = list.contains(model.blocked, day)
          button.button(
            variant: case on {
              True -> button.Default
              False -> button.Outline
            },
            size: button.Sm,
            attrs: [event.on_click(ToggleBlock(day))],
            children: [
              html.text(case on {
                True -> "Unblock "
                False -> "Block "
              }),
              html.text("June " <> int.to_string(day)),
            ],
          )
        }),
      ),
      text.s6([text.color(text.Muted)], [
        html.text(
          "Blocked days are disabled — toggle them, then try selecting one.",
        ),
      ]),
    ],
  )
}

pub fn mount_calendar_blocked(selector: String) -> Nil {
  let assert Ok(_) =
    lustre.start(
      lustre.application(blocked_init, blocked_update, blocked_view),
      selector,
      Nil,
    )
  Nil
}

fn parse_week_start(week_start: String) -> Int {
  case week_start {
    "monday" -> 1
    _ -> 0
  }
}

fn parse_mode(mode: String) -> calendar.Mode {
  case mode {
    "multiple" -> calendar.multiple
    "range" -> calendar.range
    _ -> calendar.single
  }
}

fn parse_caption(caption: String) -> calendar.CaptionLayout {
  case caption {
    "dropdown" -> calendar.dropdown
    _ -> calendar.label
  }
}
