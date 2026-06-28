//// Korean locale for `gg_base_ui/calendar` — month/weekday names, week start, and
//// writing direction, from date-fns' `ko` locale (the data react-day-picker
//// uses). Pure data; dual-target. Names are standalone (nominative) forms, the
//// casing date-fns ships.

import gg_base_ui/calendar/localization

pub fn locale() -> localization.Localization {
  localization.Localization(
    month_names: [
      "1월",
      "2월",
      "3월",
      "4월",
      "5월",
      "6월",
      "7월",
      "8월",
      "9월",
      "10월",
      "11월",
      "12월",
    ],
    weekday_short: ["일", "월", "화", "수", "목", "금", "토"],
    weekday_long: ["일요일", "월요일", "화요일", "수요일", "목요일", "금요일", "토요일"],
    week_starts_on: 0,
    direction: localization.Ltr,
    labels: localization.Labels(
      previous_month: "이전 달로 이동",
      next_month: "다음 달로 이동",
      month_dropdown: "월",
      year_dropdown: "년",
    ),
  )
}
