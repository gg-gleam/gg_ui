//// Russian locale for `gg_base_ui/calendar` — month/weekday names, week start, and
//// writing direction, from date-fns' `ru` locale (the data react-day-picker
//// uses). Pure data; dual-target. Names are standalone (nominative) forms, the
//// casing date-fns ships.

import gg_base_ui/calendar/localization

pub fn locale() -> localization.Localization {
  localization.Localization(
    month_names: [
      "январь",
      "февраль",
      "март",
      "апрель",
      "май",
      "июнь",
      "июль",
      "август",
      "сентябрь",
      "октябрь",
      "ноябрь",
      "декабрь",
    ],
    weekday_short: ["вс", "пн", "вт", "ср", "чт", "пт", "сб"],
    weekday_long: [
      "воскресенье",
      "понедельник",
      "вторник",
      "среда",
      "четверг",
      "пятница",
      "суббота",
    ],
    week_starts_on: 1,
    direction: localization.Ltr,
    labels: localization.Labels(
      previous_month: "Перейти к предыдущему месяцу",
      next_month: "Перейти к следующему месяцу",
      month_dropdown: "Месяц",
      year_dropdown: "Год",
    ),
  )
}
