//// The calendar's locale data types — extracted into their own dependency-free
//// module so the bundled locale modules (`calendar/locale/*`) can own their data
//// and `calendar` can still depend on them (e.g. `english()` is `en.locale()`)
//// without an import cycle. `calendar` re-exports `Localization`/`Direction`, so
//// consumers never name this module directly.

/// Writing direction. `Rtl` mirrors the grid and flips the nav chevrons.
pub type Direction {
  Ltr
  Rtl
}

/// Everything a locale determines, as plain data so it works identically on JS
/// and the BEAM (no `Intl` FFI). `month_names` is 12 long, January-first;
/// `weekday_short`/`weekday_long` are 7 long, **Sunday-first** (indexed by the
/// `0 = Sunday … 6 = Saturday` weekday number from `date_math`). `week_starts_on`
/// is the locale's first weekday; `direction` is its writing direction.
pub type Localization {
  Localization(
    month_names: List(String),
    weekday_short: List(String),
    weekday_long: List(String),
    week_starts_on: Int,
    direction: Direction,
    labels: Labels,
  )
}

/// The translatable UI strings (aria-labels). Part of the locale (a locale fully
/// describes its behaviour), but its own record because, unlike the names, these
/// aren't in any date library's data — the bundled non-English locales default
/// them to English (`english_labels`) until translated; override freely.
pub type Labels {
  Labels(
    previous_month: String,
    next_month: String,
    month_dropdown: String,
    year_dropdown: String,
  )
}

/// The default English UI labels.
pub fn english_labels() -> Labels {
  Labels(
    previous_month: "Go to the previous month",
    next_month: "Go to the next month",
    month_dropdown: "Month",
    year_dropdown: "Year",
  )
}
