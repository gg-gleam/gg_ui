# calendar

The `calendar` is a date grid — **one or more months**, each a header with
month/year + prev/next nav, a weekday row, and a 7-column grid of day buttons you
navigate by keyboard and click to select. It supports three selection modes —
**single**, **multiple**, and **range** — with disabled-date and per-mode bounds,
and is the engine of the shadcn **date picker** (`Popover` + `Calendar`) and **date
range picker** (the same composition in `Range` mode).

This doc has two halves: a **primer on calendar/date terminology** (so the
vocabulary is unambiguous), then **how the implementation works** — ending with the
[picker compositions](#the-picker-compositions) it powers.

## Why this component is different

Every other component takes its *behaviour* from **Base UI** (rule 1). **There is
no Base UI calendar.** shadcn's Calendar is a thin `classNames` skin over
[**react-day-picker** v9](https://daypicker.dev), which owns the grid, the
navigation state, the selection modes, the keyboard model and the ARIA.
react-day-picker is React-only and leans on **date-fns** — neither can ship in a
dual-target (JS + BEAM) pure-Gleam library (rule 3). So for this one component
**react-day-picker is the behaviour reference**, re-implemented in pure Gleam. There
is also no native primitive (rule 4): `<input type="date">` is the *browser's own*
popup, not a stylable inline grid.

---

## A primer on calendars

Dates are one of the most bug-prone areas in software because everyday "date" words
hide several different concepts. The terms below are the ones the code uses.

### Instant time vs civil (calendar) time

- An **instant** is an absolute point on the timeline — "1750941600 seconds since
  the Unix epoch (1970-01-01T00:00:00Z)". Unambiguous and globally unique. In Gleam
  this is `gleam/time/timestamp.Timestamp`.
- A **civil date** (a.k.a. *calendar date*, *naive date*, *wall-clock date*) is what
  a human writes on a form: a `(year, month, day)` triple like *2026-06-27*. It is
  **ambiguous without a time zone** — "June 27th" begins and ends at different
  instants in Tokyo and in Los Angeles. In Gleam this is `gleam/time/calendar.Date`.

A calendar widget deals in **civil dates**: picking "June 27 2026" means the day on
the wall calendar, not a UTC instant. This is the single most important modelling
decision — see [Time zones](#time-zones-and-why-we-avoid-them).

### The Gregorian calendar

The calendar in near-universal civil use, in effect since 1582. We use the
**proleptic** Gregorian calendar — the same rules extended backward — because it
makes date arithmetic uniform. The irregularities the code must handle:

- **Months have 28–31 days.** 30 for Apr/Jun/Sep/Nov; 31 for the rest; February is
  special.
- **Leap years.** February has 29 days in a leap year, else 28. A year is leap if
  divisible by 4, **except** centuries, **except** centuries divisible by 400. So
  2000 and 2024 are leap; 1900 and 2023 are not. (`calendar.is_leap_year`.)

### Day of the week

The weekday (Mon/Tue/…) is **not stored** in a date — it is *computed* from it. We
number weekdays **`0 = Sunday … 6 = Saturday`**, matching JavaScript's
`Date.getDay()` and react-day-picker. (Beware: ISO 8601 numbers them `1 = Monday …
7 = Sunday` — a different convention. We use the JS one throughout.) Computing a
weekday from `(y, m, d)` needs a small algorithm; we convert the date to a **serial
day number** (see [the engine](#1-date_math--the-pure-engine)) and take it modulo 7.

### Week start

Which day a *week* starts on is **locale-dependent**: Sunday in the US/Canada/Japan,
Monday in most of Europe and the ISO standard. It shifts where the columns begin and
which "outside" days pad the grid. It's a setting — `week_starts_on`, again
`0 = Sunday … 6 = Saturday`.

### The month grid and "outside" days

A month rarely starts on the first column or ends on the last, so a month grid is
padded: the first row reaches back into the **previous** month and the last forward
into the **next** to fill complete weeks. Those padding cells are **outside days**
(rendered muted, optionally hidden). A month spans **4–6 week rows** depending on its
length and start weekday. react-day-picker's default — and ours — is the *natural*
row count; some calendars force a fixed 6 rows for stable height.

### Selection modes

What "select" produces depends on the **mode** (react-day-picker's `mode`):

- **Single** — one day. The value is a `Date` (or none).
- **Multiple** — an unordered set of individual days; clicking toggles membership.
  Optionally bounded by a min/max **count**.
- **Range** — a *contiguous span* `from … to`. You click the start, then the end;
  every day between them is **in range**. The endpoints get distinct treatment:
  the **range start**, the **range end**, and the **range middle** (the days
  strictly between). A one-day range has `from == to`. Optionally bounded by a
  min/max **length** in days.

Range adds two interaction concepts:

- **Tentative end / preview** — after the first click (start chosen, end not yet),
  the day under the pointer (or the keyboard-focused day) previews the span that
  *would* be selected, so the middle highlights as you move. Picking the second day
  commits it.
- **Anchor ordering** — if the second pick lands *before* the start, the natural
  reading is "they re-anchored": start a fresh range there (react-day-picker's
  default), rather than silently swapping.

### Constraints: disabled dates and bounds

Days can be **disabled** so they're neither selectable nor focus-selectable: the
common `min`/`max` bounds, plus an arbitrary **predicate** (disable weekends,
holidays, already-booked days). Per-mode bounds shape the selection — a **min/max
count** for `Multiple`, a **min/max length** for `Range`, and `required` (the
selection can't be emptied). A disabled day renders muted + `aria-disabled` and is
skipped by selection and keyboard-commit.

### Modifiers: semantic per-day styling

Beyond the built-in states (selected, today, outside, in-range, disabled), a day can
carry **named modifiers** — react-day-picker's `modifiers`. A modifier is a
**predicate** that flags the days it matches; the flag drives an alternate look. The
canonical case is **booked**/unavailable days, which shadcn renders **struck through**
(the "already-booked slots" calendar): you pass `booked(is_booked)` and those cells
render with a line through the number. Typically you pair it with `disable` over the
same predicate — `booked` is the *look*, `disable` is the *behaviour* (can't pick) —
exactly what shadcn's booked-dates demo does.

The split that matters: **the consumer supplies only the predicate, never any
styling.** The kit owns the look — each modifier is a *semantic* name (`booked`) that
maps to a `cn-*` recipe in the shape fragments, so the strikethrough lives in `gg_ui`,
not in app code. This is why the API is a set of named constructors (`booked`, …)
rather than a free-form "here's a class for these days": adding a new modifier means
adding a constructor **and** its recipe to the kit, the same closed-catalog discipline
as button variants. (Mechanically it's open-ended — the headless will flag any named
predicate — but only the names the kit ships a recipe for get a look.)

### Caption, multiple months, week numbers

A few display options, independent of the selection model and keyboard:

- **Caption layout** — the header is a plain month-year **label** (default) or
  **dropdown** month/year `<select>`s for fast jumps (a date-of-birth picker wants
  the year dropdown). shadcn's `captionLayout`.
- **Multiple months** — render *N* months side by side; a range picker typically
  shows two, so you can span a boundary without navigating.
- **Week numbers** — an optional leading ISO **week-number** column.

### Time zones

Because a civil date is ambiguous without a zone, a calendar that produced *instants*
would have to ask "midnight in which zone?" and convert — dragging in a time-zone
database (IANA tz) and a class of off-by-one bugs (a date picked in one zone landing
on the previous day in another). react-day-picker keeps the grid civil by default and
opts into zones via a `timeZone` prop — a `@date-fns/tz` `TZDate` threaded through its
whole engine.

We reach the same capability differently: **the grid is always civil, and the zone
lives at the two edges** — computing "today" on the way *in*, and (optionally) binding
a picked date to an instant on the way *out*. No zone math runs inside the component,
which keeps the engine pure and dual-target. See
[Today and time zones at the edge](#today-and-time-zones-at-the-edge) for the
mechanism.

### Internationalization

A **locale** bundles everything locale-determined: month/weekday **names**, the
**week start**, and the writing **direction** (RTL mirrors the layout and flips the
nav chevrons). We ship a set of ready locales and let you bring your own — see
[Localization](#localization-bundled-locales-and-custom). This is a **Gregorian,
Latin-numeral** calendar by design: non-Latin numeral systems and non-Gregorian
calendars (Hijri, Persian, Hebrew, Buddhist, Ethiopic) have entirely different
structure and are separate engines — react-day-picker ships them as separate
packages — outside this component's scope.

---

## Our implementation

Three files, in the kit's standard headless-core / effectful-shell / styled-facade
shape (see [composition.md](composition.md) and
[stateful-components.md](stateful-components.md)):

```
packages/gg_base_ui/src/gg_base_ui/calendar/
  date_math.gleam      # pure date engine — no Lustre, no DOM
  calendar.gleam       # headless: pure core + effectful Lustre shell
  calendar_ffi.ts      # one FFI: roving focus
packages/gg_ui/src/gg_ui/ui/calendar.gleam        # styled facade (cn-* + lucide chevrons)
packages/gg_ui/src/gg_ui/styles/shapes/<style>/calendar.css   # the Tailwind recipe, per style
```

### Value type: `gleam_time`

The date type is **`gleam/time/calendar.Date`** from the official
[`gleam_time`](https://hexdocs.pm/gleam_time) package (a `gg_base_ui` dependency):
`Date(year, month: Month, day)`, the `Month` enum, `is_leap_year`, `is_valid_date`,
and `naive_date_compare` (→ `Order`, the backbone of all selection/range/bounds
comparisons) — pure and dual-target. It's the type **consumers** hold, so they
`import gleam/time/calendar` directly; the facade never invents its own date type.

`gleam_time` deliberately omits weekday, day arithmetic, and grid generation — exactly
what a calendar needs — so we build those.

### 1. `date_math` — the pure engine

Pure functions over `Date`, ported from react-day-picker's framework-less helpers
(`getDates`/`getWeeks`/`getDays`) and the date-fns ops they call. The risky bit is day
arithmetic across month/year/leap boundaries; we get it right with **Howard Hinnant's
`days_from_civil` / `civil_from_days`** serial-day algorithms (map any
proleptic-Gregorian date to/from a day count since 1970-01-01). With that:

- `day_of_week(date)` — `(serial + 4) mod 7` (serial 0 = Thursday → Sunday at 0).
- `add_days` / `diff_days` — arithmetic on the serial number (boundary-proof). These
  also power **range math**: the in-range test is two `naive_date_compare`s, and a
  range's length is `diff_days(from, to) + 1`.
- `add_months` — month/year arithmetic, day **clamped** to the target month's length.
- `start_of_week` / `end_of_week` — honour `week_starts_on`.
- `month_grid(year, month, week_starts_on)` — list-of-weeks grid, each cell a
  `Day(date, outside)`; natural 4–6 rows, outside days flagged.

This is where the cross-target risk concentrates, so it's **exhaustively
unit-tested** (leap years, weekday anchors, boundary arithmetic, grid shape). (The
repo's pinned `gleam_stdlib` has no `list.range`, so `date_math` carries a local
`int_range`.)

### 2. `calendar` — headless (pure core + effectful shell)

Same two-half split as combobox ([stateful-components.md](stateful-components.md)): a
**pure core** (`Config`, `Localization`, `Model`, `Model -> Model` transitions; no
DOM/effects/ARIA) and an **effectful shell** (the Lustre `Anatomy`/`Msg`/`update` +
the grid view).

#### The selection model (single · multiple · range)

One component, three modes: the **mode** picks how clicks accumulate, and a single
`Selection` value captures the result for all three.

```gleam
pub type Mode {
  Single
  Multiple   // + optional min/max count in Config
  Range      // + optional min/max length in Config
}

pub type Selection {
  Unselected
  One(Date)                            // Single
  Many(List(Date))                     // Multiple — a set, kept in click order
  Span(from: Date, to: Option(Date))   // Range — `to == None` mid-pick (preview only)
}
```

`select(model, date)` dispatches on `mode`:

- **Single** — replace with `One(date)`.
- **Multiple** — toggle `date` in/out of `Many`, respecting the max count.
- **Range** — if there's no open span (unselected, or a *complete* `Span`), open a
  new one: `Span(from: date, to: None)`. If a span is open (`to == None`): commit
  `to` when `date` is on/after `from`; **re-anchor** to `Span(from: date, to: None)`
  when it's before. A length-bounded range clamps/rejects per the configured min/max.

Each cell's appearance comes from one query — `day_state(model, date)` — so the view
never reasons about modes:

```gleam
pub type RangePosition { NotInRange  RangeStart  RangeMiddle  RangeEnd }

pub type DayState {
  DayState(
    selected: Bool,         // Single/Multiple membership, or any range endpoint
    range: RangePosition,   // for Range (incl. the live preview span)
    today: Bool, outside: Bool, disabled: Bool, focused: Bool,
  )
}
```

For range, `day_state` is computed against the **effective span** — the committed
`from..to`, or, while picking, `from..preview` where `preview` is the hovered or
keyboard-focused day. That's what makes the middle highlight track the pointer before
the second click.

#### State model

```gleam
Model(
  mode,        // Single | Multiple | Range
  displayed,   // any date in the shown month (kept at day 1)
  selection,   // the Selection above
  preview,     // Option(Date) — tentative range end (hover/focus); None outside Range
  focused,     // Option(Date) — the roving-focus day, when a day holds focus
  today,       // Option(Date) — host-supplied; drives the "today" highlight
  min, max,    // Option(Date) — selectable bounds (disabled outside)
  config,      // display + constraint options (below)
)
```

`Config` carries the display + constraint surface, all independent of the selection
model and keyboard:

```gleam
Config(
  mode,                // Single | Multiple | Range
  localization,        // names + week start + direction
  show_outside_days,
  show_week_numbers,   // the leading ISO week-number column
  caption_layout,      // Label | Dropdown
  number_of_months,    // 1+, rendered side by side
  year_range,          // #(from, to) for the year dropdown
  min_count, max_count,    // Multiple bounds
  min_length, max_length,  // Range bounds (in days)
)
```

(The `disabled` predicate and `min`/`max` date bounds aren't `Config` fields —
they're applied to the `Model` via `disable` / `disable_before` / `disable_after`.
`required` is not yet implemented.)

The subtle field is **`focused`**: only **one** day is tabbable at a time (a *roving
tabindex*, the standard grid a11y pattern). `focused` is `Some` only while a day holds
focus; the tabbable day is `focus_target(model)` — `focused`, else a sensible default
(a selected/range endpoint in view, else today, else the 1st), mirroring
react-day-picker's `calculateFocusTarget`.

Transitions: `select` (above), `previous_month`/`next_month`/`previous_year`/
`next_year` (nav buttons — change `displayed`, drop `focused`), `move_focus(nav)` (the
keyboard model — moves `focused`, scrolls `displayed` to keep it visible, and in Range
mode updates `preview` so keyboard users get the same live span), and `set_preview` /
`clear_preview` (pointer hover in Range mode).

A host reacts to a committed pick via `selection_changed(msg) -> Option(Selection)` —
the date picker reads it to fill the field and close the popover; the range picker
reads it to know when both ends are set. (Same "surface the result from `update`"
trick combobox uses.)

#### Keyboard model (WAI-ARIA date grid)

| Key | Action |
| --- | --- |
| ← / → | focus ∓1 day |
| ↑ / ↓ | focus ∓1 week |
| Home / End | focus week start / end |
| PageUp / PageDown | focus ∓1 month |
| Shift+PageUp / Shift+PageDown | focus ∓1 year |
| Enter / Space | select the focused day (per mode) |

Moving focus past the displayed month auto-navigates it, so focus is always on a
visible cell. In Range mode, moving focus while a span is open updates the preview, so
the range can be built entirely from the keyboard.

#### ARIA contract

A real `<table role="grid">` labelled by the month caption (an `aria-live="polite"`
region, so month changes announce). Weekday `<th role="columnheader" scope="col"
abbr="Sunday">`; each day in a `<td role="gridcell" aria-selected>` wrapping a
`<button>` with a full-date `aria-label` ("June 27, 2026"), the roving `tabindex`,
`aria-disabled` when out of bounds, and `data-*` state hooks the CSS styles off:
`data-today` / `data-outside` / `data-focused`, plus the selection set —
`data-selected-single` (Single/Multiple member) and `data-range-start` /
`data-range-middle` / `data-range-end` (Range, including the live preview). These
attribute names mirror shadcn's `CalendarDayButton`, so the recipe ports directly.
Active **modifiers** add a `data-<name>` flag on the cell too (e.g. `data-booked`) —
emitted by the headless from each modifier's predicate, carrying **no** style itself;
the styled layer keys the look off the flag.

#### The one FFI: roving focus

Rendering is otherwise pure HTML/CSS ("no JS where the web suffices"). The single
unavoidable bit of DOM is **moving focus**: after a keyboard move, `update` fires an
effect calling `focusDay(id)` (`calendar_ffi.ts`) to pull native focus onto that
button. It has an inert Gleam fallback, so an SSR render emits the markup with no
client effect (the rule-3 FFI pattern). Range hover-preview needs no FFI — it's a
pointer event into `update`.

### 3. `gg_ui/ui/calendar` — the styled facade

Thin skin (rule 2 facade): own `Mode`/`Config`/`Localization` with private `*_to_base`
mappings; `Model`/`Msg`/`Anatomy` are plain aliases (opaque handles the caller only
threads). It fills a `Classes` record — the seam carrying the `cn-*` slot names — and
passes the built-in **lucide** chevrons (icons aren't a public-API concern). So a
consumer imports **only** `gg_ui/ui/calendar` + `gleam/time/calendar`.

**The structural/themeable split (rule 8), as shadcn does it.** shadcn's calendar
inlines its layout into the markup (react-day-picker's `classNames` prop), keeping
the per-style CSS tiny; we match that. The facade's `Classes` strings carry each
slot's `cn-*` hook **plus the constant layout utilities raw** (e.g.
`months: "cn-calendar-months relative flex flex-col gap-4 md:flex-row"`), so they
emit into the markup and a caller could override them. The per-style
`styles/shapes/<style>/calendar.css` then holds **only four** rules: the root
`.cn-calendar` (the per-style `padding` + `--cell-radius` + `--cell-size`, the
single thing that differs between shapes), the themeable `.cn-calendar-day` /
`.cn-calendar-day-button` state colours, and `.cn-calendar-nav-button`. Layout is
constant across shapes and themes through the root vars + colour CSS vars, so
moving it raw loses no theming. (`nav-button` *must* stay a recipe: it has to
out-specify the `button` component's own recipe in the cascade — a raw utility
would lose to `.style-x .cn-button-size-icon`.)

Day state is emitted as `data-*` and styled as Tailwind variants on
`cn-calendar-day-button` — one rule per `cn-*` class (rule 7). The range visuals follow
shadcn's recipe: `data-range-start` / `data-range-end` get the primary fill + a rounded
outer edge, `data-range-middle` a muted fill with square corners and a connecting
`::after` so the band reads continuous across cell gaps. **Modifiers** are styled the
same way — the kit owns the recipe, keyed off the headless `data-<name>` flag as a
variant on the single `cn-calendar-day` class (rule 7): `booked` is
`data-[booked=true]:[&>button]:line-through`. The facade exposes a semantic
constructor per modifier (`booked(matches)`), so the consumer passes only the
predicate and never a class. The leading **week-number** column (opt-in via
`show_week_numbers`) adds a blank `cn-calendar-week-number-header` + a per-row
`cn-calendar-week-number` carrying the ISO week, both `aria-hidden`.

> **A11y note:** outside days use bare `text-muted-foreground` — **not** stacked with
> `opacity-50`, which drops contrast below 4.5:1 and fails axe on the (non-disabled)
> cells. Disabled days keep `opacity-50` because axe exempts disabled controls. (The
> real-Chromium story test enforces this.)

### Localization: bundled locales and custom

`Localization` is a **pure-data record** carrying everything locale-determined: the
12 month names (January-first), the 7 short + 7 long weekday names (Sunday-first), the
`week_starts_on` day, and the writing `direction` (`ltr`/`rtl`). **No `Intl`** — so
it's byte-identical on JS and the BEAM.

This mirrors how date-fns/shadcn localize the calendar: date-fns ships ~200 `Locale`
objects as **separately-importable submodules** (`import { es } from
"date-fns/locale"`) and shadcn's Calendar just forwards the one you pass — nothing is
bundled into the component. We follow the kit's own **icon-set precedent** (the big,
extensible data set lives outside the styled kit, not in it): the bundled locales —
generated from date-fns' data — live in the **headless** package, which is *imported,
never ejected*, so they never get dumped into an ejected app and the styled kit stays
thin. ~22 modules, one per language, each a thin function returning a `Localization`:

```
packages/gg_base_ui/src/gg_base_ui/calendar/locale/
  en.gleam  es.gleam  fr.gleam  de.gleam  pt.gleam  it.gleam  nl.gleam  pl.gleam
  ru.gleam  uk.gleam  tr.gleam  sv.gleam  id.gleam  vi.gleam      # Latin/Cyrillic
  zh.gleam  ja.gleam  ko.gleam  hi.gleam  th.gleam                # CJK / Indic / SEA
  ar.gleam  he.gleam  fa.gleam                                    # RTL
```

A consumer imports the one they need — Gleam compiles per module, so the others never
ship — and hands it to `config` (importing the locale from `gg_base_ui`, the same way
icon glyphs come from `gg_icons_*`):

```gleam
import gg_ui/ui/calendar
import gg_base_ui/calendar/locale/es

calendar.config() |> calendar.with_locale(es.locale())
```

> **Why `Localization` is an alias.** Because `gg_base_ui` can't depend on `gg_ui`,
> the locale modules return the **base** `Localization`, so `gg_ui` aliases
> `Localization`/`Direction` (rather than owning duplicate records) — a deliberate
> exception to the facade rule for these shared, stable *interface* data types, just
> like `gg_icon`'s `Size`. A base-package locale therefore flows straight into
> `with_locale`.

A **custom locale** (a language the bundle doesn't cover, or app translations) is
built with the `localization(…)` helper — no library change, and no need to import
`gg_base_ui` (the alias can't re-export the constructor, so `gg_ui` provides the
builder + `ltr`/`rtl`):

```gleam
calendar.localization(
  month_names: [...], weekday_short: [...], weekday_long: [...],
  week_starts_on: 1, direction: calendar.rtl,
)
```

**RTL** locales (ar, he, fa, …) set `direction: rtl`, which the component emits as
`dir="rtl"` on the calendar root — mirroring the grid and activating the `rtl:`
chevron-flip with no host setup. `config()` defaults to `en` (English, Sunday-start,
LTR). Use `with_week_start` to keep a locale's names but change its first day.

### Today and time zones at the edge

The calendar speaks only civil dates — but that doesn't stop you building a
timezone-correct picker. **The zone lives at the two edges, not inside the grid**,
which is simpler than and just as capable as react-day-picker's `timeZone` prop (which
threads a `@date-fns/tz` `TZDate` through its whole engine). The only two places a zone
matters:

- **Today (in).** The today-highlight is the one value needing a clock + zone, and the
  host already supplies `today: Option(Date)`. To get "today in zone *Z*," convert the
  current instant to a civil date in *Z* with `gleam_time`:

  ```gleam
  let #(today, _) = timestamp.to_calendar(timestamp.system_time(), offset)
  ```

  `offset` is `calendar.utc_offset`, `calendar.local_offset()` (the machine's zone),
  or — for a named IANA zone — an offset from a tz-database package. `gleam_time` ships
  only UTC + local on purpose; arbitrary named zones come from elsewhere, the same way
  react-day-picker tells you to bring `@date-fns/tz`.

- **Selection (out).** The calendar yields a civil `Date`. If you need an *instant* (to
  store or transmit), bind it to a time-of-day and the zone at the edge:

  ```gleam
  timestamp.from_calendar(picked, calendar.TimeOfDay(0, 0, 0, 0), offset)
  ```

So "June 27 in Tokyo" is the civil date `2026-06-27` in the grid — zone-independent, so
no two cells ever disagree about which day they are — and it becomes a specific instant
only when *you* choose to bind it, with the offset you pick. The engine stays pure and
dual-target (rule 3); the timezone database (large, constantly updated) never enters
the component. (The Storybook story fixes `today` to a constant so its play tests are
deterministic.)

---

## The picker compositions

The date picker and range picker are not new components — they are the **calendar in a
popover**, mirroring shadcn:

- **Date picker** — a `Popover` whose trigger is a `Button` showing the formatted
  selected date (or a placeholder). The popup holds the `Calendar` in `Single` mode.
  On a pick, the host reads `selection_changed`, fills the trigger label, and closes
  the popover.
- **Date range picker** — the same composition with the calendar in `Range` mode; the
  trigger shows `from – to`. It closes once the span commits (both ends set); the live
  preview means the user sees the band form as they move between the two clicks, even
  navigating across months (the selection lives in the model, so it survives nav).

Both inherit the calendar's keyboard model and ARIA wholesale; the popover supplies the
top-layer/anchor-positioning behaviour (see the popover module). The trigger's date
formatting reuses the same `Localization` the calendar carries, so the label and the
grid speak one locale.
