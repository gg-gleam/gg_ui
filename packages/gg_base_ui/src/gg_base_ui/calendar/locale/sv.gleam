//// Swedish locale for `gg_base_ui/calendar` — month/weekday names, week start, and
//// writing direction, from date-fns' `sv` locale (the data react-day-picker
//// uses). Pure data; dual-target. Names are standalone (nominative) forms, the
//// casing date-fns ships.

import gg_base_ui/calendar/localization

pub fn locale() -> localization.Localization {
  localization.Localization(
    month_names: [
      "januari",
      "februari",
      "mars",
      "april",
      "maj",
      "juni",
      "juli",
      "augusti",
      "september",
      "oktober",
      "november",
      "december",
    ],
    weekday_short: ["sö", "må", "ti", "on", "to", "fr", "lö"],
    weekday_long: [
      "söndag",
      "måndag",
      "tisdag",
      "onsdag",
      "torsdag",
      "fredag",
      "lördag",
    ],
    week_starts_on: 1,
    direction: localization.Ltr,
    labels: localization.Labels(
      previous_month: "Gå till föregående månad",
      next_month: "Gå till nästa månad",
      month_dropdown: "Månad",
      year_dropdown: "År",
    ),
  )
}
