//// Thai locale for `gg_base_ui/calendar` — month/weekday names, week start, and
//// writing direction, from date-fns' `th` locale (the data react-day-picker
//// uses). Pure data; dual-target. Names are standalone (nominative) forms, the
//// casing date-fns ships.

import gg_base_ui/calendar/localization

pub fn locale() -> localization.Localization {
  localization.Localization(
    month_names: [
      "มกราคม",
      "กุมภาพันธ์",
      "มีนาคม",
      "เมษายน",
      "พฤษภาคม",
      "มิถุนายน",
      "กรกฎาคม",
      "สิงหาคม",
      "กันยายน",
      "ตุลาคม",
      "พฤศจิกายน",
      "ธันวาคม",
    ],
    weekday_short: ["อา.", "จ.", "อ.", "พ.", "พฤ.", "ศ.", "ส."],
    weekday_long: ["อาทิตย์", "จันทร์", "อังคาร", "พุธ", "พฤหัสบดี", "ศุกร์", "เสาร์"],
    week_starts_on: 0,
    direction: localization.Ltr,
    labels: localization.Labels(
      previous_month: "ไปยังเดือนก่อนหน้า",
      next_month: "ไปยังเดือนถัดไป",
      month_dropdown: "เดือน",
      year_dropdown: "ปี",
    ),
  )
}
