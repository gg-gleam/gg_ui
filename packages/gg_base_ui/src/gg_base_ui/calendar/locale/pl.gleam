//// Polish locale for `gg_base_ui/calendar` — month/weekday names, week start, and
//// writing direction, from date-fns' `pl` locale (the data react-day-picker
//// uses). Pure data; dual-target. Names are standalone (nominative) forms, the
//// casing date-fns ships.

import gg_base_ui/calendar/localization

pub fn locale() -> localization.Localization {
  localization.Localization(
    month_names: [
      "styczeń",
      "luty",
      "marzec",
      "kwiecień",
      "maj",
      "czerwiec",
      "lipiec",
      "sierpień",
      "wrzesień",
      "październik",
      "listopad",
      "grudzień",
    ],
    weekday_short: ["nie", "pon", "wto", "śro", "czw", "pią", "sob"],
    weekday_long: [
      "niedziela",
      "poniedziałek",
      "wtorek",
      "środa",
      "czwartek",
      "piątek",
      "sobota",
    ],
    week_starts_on: 1,
    direction: localization.Ltr,
    labels: localization.Labels(
      previous_month: "Przejdź do poprzedniego miesiąca",
      next_month: "Przejdź do następnego miesiąca",
      month_dropdown: "Miesiąc",
      year_dropdown: "Rok",
    ),
  )
}
