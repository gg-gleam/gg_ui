//// Ukrainian locale for `gg_base_ui/calendar` — month/weekday names, week start, and
//// writing direction, from date-fns' `uk` locale (the data react-day-picker
//// uses). Pure data; dual-target. Names are standalone (nominative) forms, the
//// casing date-fns ships.

import gg_base_ui/calendar/localization

pub fn locale() -> localization.Localization {
  localization.Localization(
    month_names: [
      "січень",
      "лютий",
      "березень",
      "квітень",
      "травень",
      "червень",
      "липень",
      "серпень",
      "вересень",
      "жовтень",
      "листопад",
      "грудень",
    ],
    weekday_short: ["нд", "пн", "вт", "ср", "чт", "пт", "сб"],
    weekday_long: [
      "неділя",
      "понеділок",
      "вівторок",
      "середа",
      "четвер",
      "п’ятниця",
      "субота",
    ],
    week_starts_on: 1,
    direction: localization.Ltr,
    labels: localization.Labels(
      previous_month: "Перейти до попереднього місяця",
      next_month: "Перейти до наступного місяця",
      month_dropdown: "Місяць",
      year_dropdown: "Рік",
    ),
  )
}
