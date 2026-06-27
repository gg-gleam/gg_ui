//// Arabic locale for `gg_base_ui/calendar` — month/weekday names, week start, and
//// writing direction, from date-fns' `ar` locale (the data react-day-picker
//// uses). Pure data; dual-target. Names are standalone (nominative) forms, the
//// casing date-fns ships.

import gg_base_ui/calendar/localization

pub fn locale() -> localization.Localization {
  localization.Localization(
    month_names: [
      "يناير",
      "فبراير",
      "مارس",
      "أبريل",
      "مايو",
      "يونيو",
      "يوليو",
      "أغسطس",
      "سبتمبر",
      "أكتوبر",
      "نوفمبر",
      "ديسمبر",
    ],
    weekday_short: ["أحد", "اثنين", "ثلاثاء", "أربعاء", "خميس", "جمعة", "سبت"],
    weekday_long: [
      "الأحد",
      "الاثنين",
      "الثلاثاء",
      "الأربعاء",
      "الخميس",
      "الجمعة",
      "السبت",
    ],
    week_starts_on: 6,
    direction: localization.Rtl,
    labels: localization.Labels(
      previous_month: "الانتقال إلى الشهر السابق",
      next_month: "الانتقال إلى الشهر التالي",
      month_dropdown: "الشهر",
      year_dropdown: "السنة",
    ),
  )
}
