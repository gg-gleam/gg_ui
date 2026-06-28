//// Italian locale for `gg_base_ui/calendar` — month/weekday names, week start, and
//// writing direction, from date-fns' `it` locale (the data react-day-picker
//// uses). Pure data; dual-target. Names are standalone (nominative) forms, the
//// casing date-fns ships.

import gg_base_ui/calendar/localization

pub fn locale() -> localization.Localization {
  localization.Localization(
    month_names: [
      "gennaio",
      "febbraio",
      "marzo",
      "aprile",
      "maggio",
      "giugno",
      "luglio",
      "agosto",
      "settembre",
      "ottobre",
      "novembre",
      "dicembre",
    ],
    weekday_short: ["dom", "lun", "mar", "mer", "gio", "ven", "sab"],
    weekday_long: [
      "domenica",
      "lunedì",
      "martedì",
      "mercoledì",
      "giovedì",
      "venerdì",
      "sabato",
    ],
    week_starts_on: 1,
    direction: localization.Ltr,
    labels: localization.Labels(
      previous_month: "Vai al mese precedente",
      next_month: "Vai al mese successivo",
      month_dropdown: "Mese",
      year_dropdown: "Anno",
    ),
  )
}
