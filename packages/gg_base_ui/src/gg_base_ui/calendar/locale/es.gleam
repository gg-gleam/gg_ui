//// Spanish locale for `gg_base_ui/calendar` — month/weekday names, week start, and
//// writing direction, from date-fns' `es` locale (the data react-day-picker
//// uses). Pure data; dual-target. Names are standalone (nominative) forms, the
//// casing date-fns ships.

import gg_base_ui/calendar/localization

pub fn locale() -> localization.Localization {
  localization.Localization(
    month_names: [
      "enero",
      "febrero",
      "marzo",
      "abril",
      "mayo",
      "junio",
      "julio",
      "agosto",
      "septiembre",
      "octubre",
      "noviembre",
      "diciembre",
    ],
    weekday_short: ["do", "lu", "ma", "mi", "ju", "vi", "sá"],
    weekday_long: [
      "domingo",
      "lunes",
      "martes",
      "miércoles",
      "jueves",
      "viernes",
      "sábado",
    ],
    week_starts_on: 1,
    direction: localization.Ltr,
    labels: localization.Labels(
      previous_month: "Ir al mes anterior",
      next_month: "Ir al mes siguiente",
      month_dropdown: "Mes",
      year_dropdown: "Año",
    ),
  )
}
