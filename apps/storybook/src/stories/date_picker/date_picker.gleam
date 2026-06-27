//// The **date picker** — shadcn's composition, not a packaged component: a
//// `popover` whose trigger is a `button` showing the chosen date, with a
//// `calendar` as the popup content. Mirrors the `examples/base/date-picker-*`
//// set: demo (single), dob (dropdown caption), time (+ a time `input`), rtl, and
//// range (two months) plus an input-driven variant (`input_group`, typeable).
////
//// The popup is **unpadded** (shadcn's `w-auto p-0`) so the calendar sizes
//// itself; the popover closes on a completed pick (single: one click; range: both
//// ends). Stateful (`lustre.application`): the host owns the calendar `Model` +
//// both `Anatomy` handles; a `DaySelected` (via `calendar.selected_date`) also
//// fires `popover.hide`. `today` is fixed to 2026-06-27 for deterministic tests.

import gg_base_ui/calendar/locale/ar
import gg_base_ui/helpers/cn
import gg_icon/icon
import gg_icons_lucide/lucide/c as lu_c
import gg_ui/positioning.{Bottom, Start}
import gg_ui/ui/button
import gg_ui/ui/calendar
import gg_ui/ui/input
import gg_ui/ui/input_group
import gg_ui/ui/popover
import gg_ui/ui/text
import gleam/int
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import gleam/time/calendar as time_calendar
import lustre
import lustre/attribute.{type Attribute}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

fn today() -> time_calendar.Date {
  time_calendar.Date(2026, time_calendar.June, 27)
}

fn format_date(date: time_calendar.Date) -> String {
  time_calendar.month_to_string(date.month)
  <> " "
  <> int.to_string(date.day)
  <> ", "
  <> int.to_string(date.year)
}

// Parse our own `format_date` output ("June 1, 2026") back to a Date — lenient,
// `Error` on anything it can't read (the input variant ignores invalid input).
fn parse_date(raw: String) -> Result(time_calendar.Date, Nil) {
  case
    raw
    |> string.replace(",", "")
    |> string.split(" ")
    |> list_compact
  {
    [month, day, year] -> {
      use month <- result.try(parse_month(month))
      use day <- result.try(int.parse(day))
      use year <- result.try(int.parse(year))
      Ok(time_calendar.Date(year, month, day))
    }
    _ -> Error(Nil)
  }
}

fn list_compact(xs: List(String)) -> List(String) {
  case xs {
    [] -> []
    ["", ..rest] -> list_compact(rest)
    [x, ..rest] -> [x, ..list_compact(rest)]
  }
}

fn parse_month(name: String) -> Result(time_calendar.Month, Nil) {
  case string.lowercase(name) {
    "january" -> Ok(time_calendar.January)
    "february" -> Ok(time_calendar.February)
    "march" -> Ok(time_calendar.March)
    "april" -> Ok(time_calendar.April)
    "may" -> Ok(time_calendar.May)
    "june" -> Ok(time_calendar.June)
    "july" -> Ok(time_calendar.July)
    "august" -> Ok(time_calendar.August)
    "september" -> Ok(time_calendar.September)
    "october" -> Ok(time_calendar.October)
    "november" -> Ok(time_calendar.November)
    "december" -> Ok(time_calendar.December)
    _ -> Error(Nil)
  }
}

// How the trigger lays out its content. `Left` packs it to the inline-start
// (`justify-start`); `Center` leaves the button's default centring; `Justified`
// spreads the label and the trailing affordance to the edges (`justify-between`).
// (`Center` rather than `None` — `None` would collide with `option.None`.)
type Align {
  Left
  Center
  Justified
}

fn align_class(align: Align) -> String {
  case align {
    Left -> "justify-start"
    Center -> ""
    Justified -> "justify-between"
  }
}

// shadcn's call-site trigger styling (app-level, not a kit recipe): an outline
// button laid out for an affordance, muted when empty. Raw utilities are the
// sanctioned "gap the kit doesn't cover". `cn` resolves the alignment — when
// `align` is `Center` the empty fragment is dropped.
fn trigger_attrs(
  width: String,
  empty: Bool,
  align: Align,
) -> List(Attribute(msg)) {
  [
    attribute.class(
      cn.cn([
        width,
        align_class(align),
        "font-normal data-[empty=true]:text-muted-foreground",
      ]),
    ),
    attribute.attribute("data-empty", case empty {
      True -> "true"
      False -> "false"
    }),
  ]
}

// A labelled control: a `<label for>` ↔ control `id` association, the label text
// dogfooding `text` (rule 6).
fn labelled(id: String, label: String, control: Element(msg)) -> Element(msg) {
  html.div([attribute.class("flex flex-col gap-1.5")], [
    html.label([attribute.for(id)], [
      text.s6([text.color(text.Muted)], [html.text(label)]),
    ]),
    control,
  ])
}

// The popover dialog needs an accessible name: `popover.content` wires
// `aria-labelledby`/`aria-describedby` at the popup's title/description, so a
// titleless calendar popup must still render them — `sr-only` keeps them in the
// a11y tree (hidden visually). Prepend to the popup's children.
fn dialog_a11y(pop: popover.Anatomy) -> Element(msg) {
  html.div([attribute.class("sr-only")], [
    popover.title(pop, [], [html.text("Choose a date")]),
    popover.description(pop, [], [html.text("Pick a day from the calendar.")]),
  ])
}

// --- single-style pickers (demo · dob · time · rtl) ----------------------
//
// All four are one date popover whose trigger shows the chosen day; they differ
// only in calendar config, trigger look, direction, and (Time) an extra field.

type Variant {
  Demo
  Dob
  Time
  Rtl
}

type SingleModel {
  SingleModel(
    cal: calendar.Model,
    cal_anatomy: calendar.Anatomy,
    pop: popover.Anatomy,
    variant: Variant,
  )
}

type SingleMsg {
  SingleCalendar(calendar.Msg)
}

fn variant_id(variant: Variant) -> String {
  case variant {
    Demo -> "demo"
    Dob -> "dob"
    Time -> "time"
    Rtl -> "rtl"
  }
}

fn single_config(variant: Variant) -> calendar.Config {
  case variant {
    Demo -> calendar.config()
    // A date of birth wants the year dropdown + a sensible past range.
    Dob ->
      calendar.Config(
        ..calendar.config(),
        caption_layout: calendar.dropdown,
        year_range: #(1925, 2026),
      )
    Time ->
      calendar.Config(..calendar.config(), caption_layout: calendar.dropdown)
    Rtl -> calendar.Config(..calendar.config(), localization: ar.locale())
  }
}

fn single_init(variant: Variant) -> #(SingleModel, Effect(SingleMsg)) {
  #(
    SingleModel(
      cal: calendar.init(
        config: single_config(variant),
        selected: None,
        today: Some(today()),
      ),
      cal_anatomy: calendar.anatomy_with_id("dp-cal-" <> variant_id(variant)),
      pop: popover.anatomy_with_id("dp-pop-" <> variant_id(variant)),
      variant:,
    ),
    effect.none(),
  )
}

fn single_update(
  model: SingleModel,
  msg: SingleMsg,
) -> #(SingleModel, Effect(SingleMsg)) {
  case msg {
    SingleCalendar(cal_msg) -> {
      let #(cal, eff) = calendar.update(model.cal_anatomy, model.cal, cal_msg)
      let close = case calendar.selected_date(cal_msg) {
        Some(_) -> popover.hide(model.pop)
        None -> effect.none()
      }
      #(
        SingleModel(..model, cal:),
        effect.batch([
          effect.map(eff, SingleCalendar),
          close,
        ]),
      )
    }
  }
}

// The placeholder shown before a date is chosen — Arabic for the RTL demo.
fn single_placeholder(variant: Variant) -> String {
  case variant {
    Rtl -> "اختر تاريخًا"
    Demo -> "Pick a date"
    _ -> "Select date"
  }
}

fn single_picker(model: SingleModel) -> Element(SingleMsg) {
  let date = calendar.selected(model.cal)
  let label = case date {
    Some(d) -> format_date(d)
    None -> single_placeholder(model.variant)
  }
  let id = "dp-trigger-" <> variant_id(model.variant)
  // Demo carries a trailing chevron; the others (shadcn) a plain text trigger.
  let children = case model.variant {
    Demo -> [html.text(label), lu_c.chevron_down([icon.size(icon.Sm)])]
    _ -> [html.text(label)]
  }
  let width = case model.variant {
    Demo | Rtl -> "w-[212px]"
    Time -> "w-32"
    Dob -> "w-44"
  }
  element.fragment([
    popover.trigger(
      model.pop,
      variant: button.Outline,
      size: button.Medium,
      attrs: [attribute.id(id), ..trigger_attrs(width, date == None, Justified)],
      children:,
    ),
    popover.content(
      model.pop,
      side: Bottom,
      align: Start,
      padding: popover.Unpadded,
      dismiss: popover.Auto,
      arrow: False,
      on_toggle: None,
      attrs: [],
      children: [
        dialog_a11y(model.pop),
        element.map(
          calendar.calendar(model.cal_anatomy, model.cal, []),
          SingleCalendar,
        ),
      ],
    ),
  ])
}

fn single_view(model: SingleModel) -> Element(SingleMsg) {
  let trigger_id = "dp-trigger-" <> variant_id(model.variant)
  case model.variant {
    // Date + a sibling time field (an uncontrolled native time input).
    Time ->
      html.div([attribute.class("flex flex-row gap-4 text-foreground")], [
        labelled("dp-date-time", "Date", single_picker(model)),
        labelled(
          "dp-time",
          "Time",
          // shadcn's date-picker-time call-site styling: same `input`, but flatten
          // the native time control — drop the OS appearance and hide the webkit
          // calendar-picker (clock) indicator so it reads as a plain field.
          input.input([
            attribute.id("dp-time"),
            attribute.type_("time"),
            attribute.attribute("step", "1"),
            attribute.value("10:30:00"),
            attribute.class(
              "w-32 appearance-none bg-background "
              <> "[&::-webkit-calendar-picker-indicator]:hidden "
              <> "[&::-webkit-calendar-picker-indicator]:appearance-none",
            ),
          ]),
        ),
      ])
    // RTL: the whole field flows right-to-left; the calendar mirrors via its locale.
    Rtl ->
      html.div(
        [attribute.attribute("dir", "rtl"), attribute.class("text-foreground")],
        [single_picker(model)],
      )
    Dob ->
      html.div([attribute.class("text-foreground")], [
        labelled(trigger_id, "Date of birth", single_picker(model)),
      ])
    Demo ->
      html.div([attribute.class("text-foreground")], [single_picker(model)])
  }
}

fn start_single(variant: Variant, selector: String) -> Nil {
  let assert Ok(_) =
    lustre.start(
      lustre.application(
        fn(_) { single_init(variant) },
        single_update,
        single_view,
      ),
      selector,
      Nil,
    )
  Nil
}

pub fn mount_date_picker_single(selector: String) -> Nil {
  start_single(Demo, selector)
}

pub fn mount_date_picker_dob(selector: String) -> Nil {
  start_single(Dob, selector)
}

pub fn mount_date_picker_time(selector: String) -> Nil {
  start_single(Time, selector)
}

pub fn mount_date_picker_rtl(selector: String) -> Nil {
  start_single(Rtl, selector)
}

// --- input-driven (input_group, typeable) --------------------------------

type InputModel {
  InputModel(
    cal: calendar.Model,
    cal_anatomy: calendar.Anatomy,
    pop: popover.Anatomy,
    value: String,
  )
}

type InputMsg {
  InputCalendar(calendar.Msg)
  InputTyped(String)
}

fn input_init(_flags: Nil) -> #(InputModel, Effect(InputMsg)) {
  let start = time_calendar.Date(2026, time_calendar.June, 1)
  #(
    InputModel(
      cal: calendar.init(
        config: calendar.config(),
        selected: Some(start),
        today: Some(today()),
      ),
      cal_anatomy: calendar.anatomy_with_id("dp-cal-input"),
      pop: popover.anatomy_with_id("dp-pop-input"),
      value: format_date(start),
    ),
    effect.none(),
  )
}

fn input_update(
  model: InputModel,
  msg: InputMsg,
) -> #(InputModel, Effect(InputMsg)) {
  case msg {
    InputTyped(raw) -> {
      // Reflect the typed text; if it parses, sync the calendar to it.
      let cal = case parse_date(raw) {
        Ok(date) -> calendar.select(model.cal, date)
        Error(_) -> model.cal
      }
      #(InputModel(..model, value: raw, cal:), effect.none())
    }
    InputCalendar(cal_msg) -> {
      let #(cal, eff) = calendar.update(model.cal_anatomy, model.cal, cal_msg)
      // Picking a day fills the input and closes the popover.
      let #(value, close) = case calendar.selected_date(cal_msg) {
        Some(date) -> #(format_date(date), popover.hide(model.pop))
        None -> #(model.value, effect.none())
      }
      #(
        InputModel(..model, cal:, value:),
        effect.batch([
          effect.map(eff, InputCalendar),
          close,
        ]),
      )
    }
  }
}

fn input_view(model: InputModel) -> Element(InputMsg) {
  html.div([attribute.class("w-56 text-foreground")], [
    labelled(
      "dp-input",
      "Subscription Date",
      input_group.input_group([], [
        input_group.input([
          attribute.id("dp-input"),
          attribute.value(model.value),
          attribute.placeholder("June 01, 2026"),
          event.on_input(InputTyped),
        ]),
        input_group.addon(input_group.InlineEnd, [], [
          input_group.button(
            input_group.IconXs,
            [
              attribute.attribute("aria-label", "Select date"),
              ..popover.trigger_attributes(model.pop)
            ],
            [lu_c.calendar([icon.size(icon.Sm)])],
          ),
          popover.content(
            model.pop,
            side: Bottom,
            align: Start,
            padding: popover.Unpadded,
            dismiss: popover.Auto,
            arrow: False,
            on_toggle: None,
            attrs: [],
            children: [
              dialog_a11y(model.pop),
              element.map(
                calendar.calendar(model.cal_anatomy, model.cal, []),
                InputCalendar,
              ),
            ],
          ),
        ]),
      ]),
    ),
  ])
}

pub fn mount_date_picker_input(selector: String) -> Nil {
  let assert Ok(_) =
    lustre.start(
      lustre.application(input_init, input_update, input_view),
      selector,
      Nil,
    )
  Nil
}

// --- range (two months) --------------------------------------------------

type RangeModel {
  RangeModel(
    cal: calendar.Model,
    cal_anatomy: calendar.Anatomy,
    pop: popover.Anatomy,
  )
}

type RangeMsg {
  RangeCalendar(calendar.Msg)
}

fn range_init(_flags: Nil) -> #(RangeModel, Effect(RangeMsg)) {
  #(
    RangeModel(
      cal: calendar.init(
        config: calendar.Config(
          ..calendar.config(),
          mode: calendar.range,
          number_of_months: 2,
        ),
        selected: None,
        today: Some(today()),
      ),
      cal_anatomy: calendar.anatomy_with_id("dp-cal-range"),
      pop: popover.anatomy_with_id("dp-pop-range"),
    ),
    effect.none(),
  )
}

fn range_update(
  model: RangeModel,
  msg: RangeMsg,
) -> #(RangeModel, Effect(RangeMsg)) {
  case msg {
    RangeCalendar(cal_msg) -> {
      let #(cal, eff) = calendar.update(model.cal_anatomy, model.cal, cal_msg)
      let close = case
        calendar.selected_date(cal_msg),
        calendar.selected_range(cal)
      {
        Some(_), Some(#(_, Some(_))) -> popover.hide(model.pop)
        _, _ -> effect.none()
      }
      #(
        RangeModel(..model, cal:),
        effect.batch([
          effect.map(eff, RangeCalendar),
          close,
        ]),
      )
    }
  }
}

fn range_label(model: RangeModel) -> String {
  case calendar.selected_range(model.cal) {
    Some(#(from, Some(to))) -> format_date(from) <> " – " <> format_date(to)
    Some(#(from, None)) -> format_date(from)
    None -> "Pick a date"
  }
}

fn range_view(model: RangeModel) -> Element(RangeMsg) {
  let empty = calendar.selected_range(model.cal) == None
  html.div([attribute.class("text-foreground")], [
    popover.trigger(
      model.pop,
      variant: button.Outline,
      size: button.Medium,
      attrs: trigger_attrs("min-w-60", empty, Left),
      children: [
        lu_c.calendar([icon.size(icon.Sm)]),
        html.text(range_label(model)),
      ],
    ),
    popover.content(
      model.pop,
      side: Bottom,
      align: Start,
      padding: popover.Unpadded,
      dismiss: popover.Auto,
      arrow: False,
      on_toggle: None,
      attrs: [],
      children: [
        dialog_a11y(model.pop),
        element.map(
          calendar.calendar(model.cal_anatomy, model.cal, []),
          RangeCalendar,
        ),
      ],
    ),
  ])
}

pub fn mount_date_picker_range(selector: String) -> Nil {
  let assert Ok(_) =
    lustre.start(
      lustre.application(range_init, range_update, range_view),
      selector,
      Nil,
    )
  Nil
}
