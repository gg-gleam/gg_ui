//// Japanese locale for `gg_base_ui/calendar` — month/weekday names, week start, and
//// writing direction, from date-fns' `ja` locale (the data react-day-picker
//// uses). Pure data; dual-target. Names are standalone (nominative) forms, the
//// casing date-fns ships.

import gg_base_ui/calendar/localization

pub fn locale() -> localization.Localization {
  localization.Localization(
    month_names: [
      "1月",
      "2月",
      "3月",
      "4月",
      "5月",
      "6月",
      "7月",
      "8月",
      "9月",
      "10月",
      "11月",
      "12月",
    ],
    weekday_short: ["日", "月", "火", "水", "木", "金", "土"],
    weekday_long: ["日曜日", "月曜日", "火曜日", "水曜日", "木曜日", "金曜日", "土曜日"],
    week_starts_on: 0,
    direction: localization.Ltr,
    labels: localization.Labels(
      previous_month: "前の月へ",
      next_month: "次の月へ",
      month_dropdown: "月",
      year_dropdown: "年",
    ),
  )
}
