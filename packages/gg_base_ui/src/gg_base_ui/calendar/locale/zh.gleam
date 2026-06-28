//// Chinese (Simplified) locale for `gg_base_ui/calendar` — month/weekday names, week start, and
//// writing direction, from date-fns' `zh-CN` locale (the data react-day-picker
//// uses). Pure data; dual-target. Names are standalone (nominative) forms, the
//// casing date-fns ships.

import gg_base_ui/calendar/localization

pub fn locale() -> localization.Localization {
  localization.Localization(
    month_names: [
      "一月",
      "二月",
      "三月",
      "四月",
      "五月",
      "六月",
      "七月",
      "八月",
      "九月",
      "十月",
      "十一月",
      "十二月",
    ],
    weekday_short: ["日", "一", "二", "三", "四", "五", "六"],
    weekday_long: ["星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"],
    week_starts_on: 1,
    direction: localization.Ltr,
    labels: localization.Labels(
      previous_month: "转到上个月",
      next_month: "转到下个月",
      month_dropdown: "月",
      year_dropdown: "年",
    ),
  )
}
