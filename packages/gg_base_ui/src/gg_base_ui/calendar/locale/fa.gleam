//// Persian locale for `gg_base_ui/calendar` — month/weekday names, week start, and
//// writing direction, from date-fns' `fa-IR` locale (the data react-day-picker
//// uses). Pure data; dual-target. Names are standalone (nominative) forms, the
//// casing date-fns ships.

import gg_base_ui/calendar/localization

pub fn locale() -> localization.Localization {
  localization.Localization(
    month_names: [
      "ژانویه",
      "فوریه",
      "مارس",
      "آپریل",
      "می",
      "جون",
      "جولای",
      "آگوست",
      "سپتامبر",
      "اکتبر",
      "نوامبر",
      "دسامبر",
    ],
    weekday_short: ["1ش", "2ش", "3ش", "4ش", "5ش", "ج", "ش"],
    weekday_long: [
      "یکشنبه",
      "دوشنبه",
      "سه‌شنبه",
      "چهارشنبه",
      "پنجشنبه",
      "جمعه",
      "شنبه",
    ],
    week_starts_on: 6,
    direction: localization.Rtl,
    labels: localization.Labels(
      previous_month: "رفتن به ماه قبل",
      next_month: "رفتن به ماه بعد",
      month_dropdown: "ماه",
      year_dropdown: "سال",
    ),
  )
}
