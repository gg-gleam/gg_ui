//// English (US) locale for `gg_base_ui/calendar` — the built-in default
//// (`calendar.english()` is a proxy for this). Pure data; dual-target.

import gg_base_ui/calendar/localization

pub fn locale() -> localization.Localization {
  localization.Localization(
    month_names: [
      "January", "February", "March", "April", "May", "June", "July", "August",
      "September", "October", "November", "December",
    ],
    weekday_short: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"],
    weekday_long: [
      "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday",
      "Saturday",
    ],
    week_starts_on: 0,
    direction: localization.Ltr,
    labels: localization.english_labels(),
  )
}
