//// German locale for `gg_base_ui/calendar` — month/weekday names, week start, and
//// writing direction, from date-fns' `de` locale (the data react-day-picker
//// uses). Pure data; dual-target. Names are standalone (nominative) forms, the
//// casing date-fns ships.

import gg_base_ui/calendar/localization

pub fn locale() -> localization.Localization {
  localization.Localization(
    month_names: [
      "Januar",
      "Februar",
      "März",
      "April",
      "Mai",
      "Juni",
      "Juli",
      "August",
      "September",
      "Oktober",
      "November",
      "Dezember",
    ],
    weekday_short: ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"],
    weekday_long: [
      "Sonntag",
      "Montag",
      "Dienstag",
      "Mittwoch",
      "Donnerstag",
      "Freitag",
      "Samstag",
    ],
    week_starts_on: 1,
    direction: localization.Ltr,
    labels: localization.Labels(
      previous_month: "Zum vorherigen Monat",
      next_month: "Zum nächsten Monat",
      month_dropdown: "Monat",
      year_dropdown: "Jahr",
    ),
  )
}
