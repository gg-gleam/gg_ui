//// shadcn-flavoured `Calendar` — the **thin** styled layer over the headless
//// `gg_base_ui/calendar`. shadcn's Calendar is itself a skin over
//// `react-day-picker`; we keep that split — behaviour + a11y live in the headless
//// layer, this layer only adds the `cn-*` class names (the Tailwind recipes live
//// in `styles/shapes/<style>/calendar.css`) and the built-in lucide chevrons.
////
//// The kit's date-grid is *stateful*: the host embeds it MVU-style (its model
//// holds a `Model` + an `Anatomy`; its update threads `Msg` through `update`).
//// It composes with `popover` into the shadcn date picker (a later step).
////
//// **Facade (rule 2).** The caller-constructed surface is gg_ui's own: `Config`
//// and `Localization` are gg_ui types mapped to the headless layer via private
//// `*_to_base`. The opaque handles the caller only *threads* — `Model`, `Msg`,
//// `Anatomy` — are plain aliases (the sanctioned exception). Selection is a
//// `gleam/time/calendar.Date`, which consumers import directly. So a
//// consumer/story imports **only `gg_ui/…`** (+ `gleam/time/calendar`).
////
//// **Icons aren't a public-API concern**: the prev/next chevrons are built in
//// from lucide (shadcn's default); the future CLI rewrites that import to the
//// app's chosen set at eject. See [`dev-docs/icons.md`](../../../../dev-docs/icons.md).

import gg_base_ui/calendar/calendar as base_calendar
import gg_base_ui/calendar/localization as base_localization
import gg_icon/icon
import gg_icons_lucide/lucide/c as lu_c
import gg_ui/ui/button
import gleam/option.{type Option}
import gleam/time/calendar.{type Date}
import lustre/attribute.{type Attribute}
import lustre/effect.{type Effect}
import lustre/element.{type Element}

// --- Handles (opaque aliases — threaded, never constructed by the caller) ---

/// The calendar state. Build it with `init`; read `selected` / `month_label`.
/// Threaded through `update` and the `calendar` view.
pub type Model =
  base_calendar.Model

/// The component's messages. The host wraps this in its own `Msg` and threads it
/// through `update`; it never constructs the variants (the view wires them).
pub type Msg =
  base_calendar.Msg

/// The stable ids the parts share. Mint once with `anatomy` and keep it in the
/// host model; never recompute per render.
pub type Anatomy =
  base_calendar.Anatomy

// --- Caller-constructed types (gg_ui's own + private *_to_base) ------------

/// Display + behaviour switches (build with `config()` then record-update what you
/// need — `Config(..config(), mode: range, number_of_months: 2)`). `mode` is the
/// selection axis; `show_outside_days` renders adjacent-month days; `caption_layout`
/// is `label` vs `dropdown`; `number_of_months` renders N grids side-by-side;
/// `year_range` bounds the year dropdown; `min_count`/`max_count` cap `multiple`,
/// `min_length`/`max_length` cap `range`; `localization` supplies the locale.
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

/// The selection axis. Use the `single` / `multiple` / `range` constants.
pub type Mode =
  base_calendar.Mode

/// One day (date picker). The default.
pub const single: Mode = base_calendar.Single

/// A toggled set of days.
pub const multiple: Mode = base_calendar.Multiple

/// A contiguous span (date range picker).
pub const range: Mode = base_calendar.Range

/// The header caption style. Use the `label` / `dropdown` constants.
pub type CaptionLayout =
  base_calendar.CaptionLayout

/// A plain month-year label (the default).
pub const label: CaptionLayout = base_calendar.Label

/// Month + year `<select>` dropdowns, for fast jumps.
pub const dropdown: CaptionLayout = base_calendar.Dropdown

/// Everything a locale determines (pure data — no `Intl`, dual-target):
/// `month_names` (12, January-first), `weekday_short`/`weekday_long` (7,
/// **Sunday-first**), `week_starts_on` (`0 = Sunday … 6 = Saturday`), and the
/// writing `direction`. The bundled locales live in `gg_base_ui/calendar/locale`
/// (a shared interface type, like the icon sets) — import the one you need and
/// pass it to `with_locale`. Build a custom one with `localization`.
pub type Localization =
  base_calendar.Localization

/// Writing direction. `rtl` mirrors the grid and flips the nav chevrons.
pub type Direction =
  base_calendar.Direction

/// Left-to-right (the default).
pub const ltr: Direction = base_localization.Ltr

/// Right-to-left (Arabic, Hebrew, Persian, …).
pub const rtl: Direction = base_localization.Rtl

/// The translatable UI aria-labels, part of a `Localization` (prev/next-month nav
/// + month/year dropdowns). Build one with `Labels(…)` or start from
/// `english_labels()`.
pub type Labels =
  base_localization.Labels

/// The default English UI labels.
pub fn english_labels() -> Labels {
  base_calendar.english_labels()
}

/// The defaults: single select, English (Sunday-start, LTR), outside days shown,
/// label caption, one month, a 1970–2060 year dropdown range, no bounds.
pub fn config() -> Config {
  Config(
    mode: single,
    localization: english(),
    show_outside_days: True,
    show_week_numbers: False,
    caption_layout: label,
    number_of_months: 1,
    year_range: #(1970, 2060),
    min_count: option.None,
    max_count: option.None,
    min_length: option.None,
    max_length: option.None,
  )
}

/// The default English localization (matching shadcn's `en-US` default).
pub fn english() -> Localization {
  base_calendar.english()
}

/// Build a custom localization — for a locale the bundle doesn't cover, or app
/// translations. `month_names` is 12 (January-first); the weekday lists are 7
/// (**Sunday-first**); `week_starts_on` is `0 = Sunday … 6 = Saturday`; `labels`
/// are the UI aria-labels (start from `english_labels()`).
pub fn localization(
  month_names month_names: List(String),
  weekday_short weekday_short: List(String),
  weekday_long weekday_long: List(String),
  week_starts_on week_starts_on: Int,
  direction direction: Direction,
  labels labels: Labels,
) -> Localization {
  base_localization.Localization(
    month_names:,
    weekday_short:,
    weekday_long:,
    week_starts_on:,
    direction:,
    labels:,
  )
}

/// Set the locale on a `Config` — e.g. `config() |> with_locale(es.locale())`.
pub fn with_locale(config: Config, localization: Localization) -> Config {
  Config(..config, localization:)
}

/// Toggle the leading ISO week-number column (shadcn's `showWeekNumber`) — e.g.
/// `config() |> with_week_numbers(True)`. Off by default.
pub fn with_week_numbers(config: Config, show: Bool) -> Config {
  Config(..config, show_week_numbers: show)
}

/// Override just the week-start day on a localization (`0 = Sunday … 6 =
/// Saturday`) — handy when you want a locale's names but a different first day.
pub fn with_week_start(localization: Localization, day: Int) -> Localization {
  base_localization.Localization(..localization, week_starts_on: day)
}

// --- Lifecycle wrappers ----------------------------------------------------

/// A fresh model. The displayed month anchors on `selected`, else `today`. Pass
/// `today` (and any `selected`) so the calendar opens on a sensible month.
pub fn init(
  config config: Config,
  selected selected: Option(Date),
  today today: Option(Date),
) -> Model {
  base_calendar.init(
    config: config_to_base(config),
    selected: selected,
    today: today,
  )
}

/// Mint an `Anatomy` with a fresh, collision-free id (the default).
pub fn anatomy() -> Anatomy {
  base_calendar.anatomy()
}

/// Mint an `Anatomy` from an explicit base id (tests / SSR pinning).
pub fn anatomy_with_id(id: String) -> Anatomy {
  base_calendar.anatomy_with_id(id)
}

/// Advance the state for a `Msg`, returning the new model + its DOM effect.
pub fn update(
  anatomy: Anatomy,
  model: Model,
  msg: Msg,
) -> #(Model, Effect(Msg)) {
  base_calendar.update(anatomy, model, msg)
}

/// Bound the selectable range to dates on/after `min` (others render disabled).
pub fn disable_before(model: Model, min: Date) -> Model {
  base_calendar.disable_before(model, min)
}

/// Bound the selectable range to dates on/before `max`.
pub fn disable_after(model: Model, max: Date) -> Model {
  base_calendar.disable_after(model, max)
}

/// Disable arbitrary days with a predicate (weekends, holidays, booked days) — a
/// disabled day is muted, `aria-disabled`, and unselectable. Composes with min/max.
pub fn disable(model: Model, predicate: fn(Date) -> Bool) -> Model {
  base_calendar.disable(model, predicate)
}

/// A semantic visual day modifier (react-day-picker's `modifiers`). The kit owns
/// the look — each modifier maps to a `cn-calendar-*` recipe in the shape
/// fragments, so consumers supply only the predicate, never a class. Threaded as an
/// opaque handle; build with a constructor like `booked`.
pub type Modifier =
  base_calendar.Modifier

/// "Booked"/unavailable days: matching days render **struck through** (shadcn's
/// booked-dates look). Purely visual — pair with `disable` to also block selection.
pub fn booked(matches: fn(Date) -> Bool) -> Modifier {
  base_calendar.Modifier(name: "booked", matches:)
}

/// Attach visual modifiers to a model (replaces any previously set).
pub fn modifiers(model: Model, modifiers: List(Modifier)) -> Model {
  base_calendar.modifiers(model, modifiers)
}

// --- Programmatic control --------------------------------------------------

/// Apply a selection for `date` as if the user picked it (per the configured
/// mode), revealing its month. For host-driven selection — a "Today" shortcut, or
/// the date-picker-input syncing a typed date into the grid.
pub fn select(model: Model, date: Date) -> Model {
  base_calendar.select(model, date)
}

/// Scroll the displayed month to `date`'s month without changing the selection —
/// e.g. follow along as a user types a date.
pub fn go_to_month(model: Model, date: Date) -> Model {
  base_calendar.go_to_month(model, date)
}

// --- Selectors -------------------------------------------------------------

/// The selected day for `single` mode, if any.
pub fn selected(model: Model) -> Option(Date) {
  base_calendar.selected(model)
}

/// The selected days for `multiple` mode, in click order (`[]` otherwise).
pub fn selected_dates(model: Model) -> List(Date) {
  case base_calendar.selection(model) {
    base_calendar.Many(dates) -> dates
    base_calendar.One(date) -> [date]
    _ -> []
  }
}

/// The selected span for `range` mode: `Some(#(from, to))` where `to` is `None`
/// until the end is picked; `None` when no span is open.
pub fn selected_range(model: Model) -> Option(#(Date, Option(Date))) {
  case base_calendar.selection(model) {
    base_calendar.Span(from, to) -> option.Some(#(from, to))
    _ -> option.None
  }
}

/// The day a `DaySelected` chose — for the host to react to (e.g. close a popover
/// in the date picker). `None` for any other message.
pub fn selected_date(msg: Msg) -> Option(Date) {
  base_calendar.selected_date(msg)
}

/// The displayed month's label, e.g. `"June 2026"`.
pub fn month_label(model: Model) -> String {
  base_calendar.month_label(model)
}

// --- View ------------------------------------------------------------------

/// Render the calendar: the prev/next nav (built-in lucide chevrons), the month
/// caption, and the WAI-ARIA date grid. Merge styling/attrs via `attrs`.
pub fn calendar(
  anatomy anatomy: Anatomy,
  model model: Model,
  attrs attrs: List(Attribute(Msg)),
) -> Element(Msg) {
  base_calendar.calendar(
    anatomy: anatomy,
    model: model,
    classes: classes(),
    previous_icon: chevron(lu_c.chevron_left),
    next_icon: chevron(lu_c.chevron_right),
    dropdown_icon: lu_c.chevron_down([icon.size(icon.Sm)]),
    attrs: attrs,
  )
}

fn chevron(glyph: fn(List(Attribute(Msg))) -> Element(Msg)) -> Element(Msg) {
  glyph([icon.size(icon.Md)])
}

// Dogfood the styled `Button` recipe for the nav (shadcn uses `buttonVariants`):
// the ghost variant supplies the hover / focus-ring / active feel, and
// `cn-calendar-nav-button` overrides only what's calendar-specific (cell size,
// cell radius, RTL chevron flip). `calendar.css` imports after `button.css`, so
// the overrides win the cascade.
fn nav_button(side: String) -> String {
  button.classes(button.Ghost, button.Icon)
  <> " cn-calendar-nav-button "
  <> side
}

// Each slot carries its `cn-*` hook **plus the constant layout utilities raw**
// (rule 8 — mirrors shadcn's inline calendar `classNames`, e.g.
// `months: "relative flex flex-col gap-4 md:flex-row"`). Only the per-style root
// and the themeable day / day-button state colors stay in the `@apply` recipes
// (`styles/shapes/<style>/calendar.css`); everything here is style-agnostic and
// themes through the root's `--cell-size` / `--cell-radius` + colour CSS vars.
// `nav_*` keep their recipe (via `nav_button`) so they out-specify `button`'s.
// `day` / `day_button` keep the recipe `cn-*` only — their layout *and* state
// colours live in the recipe (the themeable heart; not split).
fn classes() -> base_calendar.Classes {
  base_calendar.Classes(
    root: "cn-calendar w-fit",
    months: "cn-calendar-months relative flex flex-col gap-4 md:flex-row",
    month: "cn-calendar-month flex w-full flex-col gap-4",
    nav: "cn-calendar-nav absolute inset-x-0 top-0 flex items-center justify-between gap-1",
    nav_previous: nav_button("cn-calendar-nav-previous"),
    nav_next: nav_button("cn-calendar-nav-next"),
    caption: "cn-calendar-caption flex h-(--cell-size) items-center justify-center px-(--cell-size) text-sm font-medium select-none",
    dropdowns: "cn-calendar-dropdowns flex h-(--cell-size) w-full items-center justify-center gap-1.5 px-(--cell-size) text-sm font-medium",
    dropdown: "cn-calendar-dropdown relative inline-flex items-center rounded-(--cell-radius) hover:bg-muted has-[:focus-visible]:ring-3 has-[:focus-visible]:ring-ring/50",
    dropdown_select: "cn-calendar-dropdown-select absolute inset-0 z-10 cursor-pointer opacity-0",
    dropdown_label: "cn-calendar-dropdown-label inline-flex items-center gap-1 px-2 py-0.5 text-sm font-medium [&>svg]:size-3.5 [&>svg]:text-muted-foreground",
    grid: "cn-calendar-grid w-full border-collapse",
    weekdays: "cn-calendar-weekdays flex",
    weekday: "cn-calendar-weekday flex-1 rounded-(--cell-radius) text-[0.8rem] font-normal text-muted-foreground select-none",
    week_number_header: "cn-calendar-week-number-header w-(--cell-size) select-none",
    week_number: "cn-calendar-week-number flex w-(--cell-size) items-center justify-center text-[0.8rem] text-muted-foreground select-none",
    week: "cn-calendar-week mt-2 flex w-full",
    day: "cn-calendar-day",
    day_button: "cn-calendar-day-button",
  )
}

// --- facade mappings -------------------------------------------------------

// `Localization`/`Direction` are aliases of the base types (the bundled locales
// live in `gg_base_ui` and can't depend on `gg_ui`), so `Config`'s localization
// passes straight through — only `show_outside_days` is gg_ui's own field.
fn config_to_base(config: Config) -> base_calendar.Config {
  base_calendar.Config(
    mode: config.mode,
    localization: config.localization,
    show_outside_days: config.show_outside_days,
    show_week_numbers: config.show_week_numbers,
    caption_layout: config.caption_layout,
    number_of_months: config.number_of_months,
    year_range: config.year_range,
    min_count: config.min_count,
    max_count: config.max_count,
    min_length: config.min_length,
    max_length: config.max_length,
  )
}
