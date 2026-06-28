//// Hebrew locale for `gg_base_ui/calendar` — month/weekday names, week start, and
//// writing direction, from date-fns' `he` locale (the data react-day-picker
//// uses). Pure data; dual-target. Names are standalone (nominative) forms, the
//// casing date-fns ships.

import gg_base_ui/calendar/localization

pub fn locale() -> localization.Localization {
  localization.Localization(
    month_names: [
      "ינואר",
      "פברואר",
      "מרץ",
      "אפריל",
      "מאי",
      "יוני",
      "יולי",
      "אוגוסט",
      "ספטמבר",
      "אוקטובר",
      "נובמבר",
      "דצמבר",
    ],
    weekday_short: ["א׳", "ב׳", "ג׳", "ד׳", "ה׳", "ו׳", "ש׳"],
    weekday_long: [
      "יום ראשון",
      "יום שני",
      "יום שלישי",
      "יום רביעי",
      "יום חמישי",
      "יום שישי",
      "יום שבת",
    ],
    week_starts_on: 0,
    direction: localization.Rtl,
    labels: localization.Labels(
      previous_month: "מעבר לחודש הקודם",
      next_month: "מעבר לחודש הבא",
      month_dropdown: "חודש",
      year_dropdown: "שנה",
    ),
  )
}
