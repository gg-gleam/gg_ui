//// Dutch locale for `gg_base_ui/calendar` — month/weekday names, week start, and
//// writing direction, from date-fns' `nl` locale (the data react-day-picker
//// uses). Pure data; dual-target. Names are standalone (nominative) forms, the
//// casing date-fns ships.

import gg_base_ui/calendar/localization

pub fn locale() -> localization.Localization {
  localization.Localization(
    month_names: [
      "januari",
      "februari",
      "maart",
      "april",
      "mei",
      "juni",
      "juli",
      "augustus",
      "september",
      "oktober",
      "november",
      "december",
    ],
    weekday_short: ["zo", "ma", "di", "wo", "do", "vr", "za"],
    weekday_long: [
      "zondag",
      "maandag",
      "dinsdag",
      "woensdag",
      "donderdag",
      "vrijdag",
      "zaterdag",
    ],
    week_starts_on: 1,
    direction: localization.Ltr,
    labels: localization.Labels(
      previous_month: "Ga naar de vorige maand",
      next_month: "Ga naar de volgende maand",
      month_dropdown: "Maand",
      year_dropdown: "Jaar",
    ),
  )
}
