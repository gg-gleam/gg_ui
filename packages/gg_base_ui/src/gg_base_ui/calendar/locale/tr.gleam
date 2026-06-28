//// Turkish locale for `gg_base_ui/calendar` — month/weekday names, week start, and
//// writing direction, from date-fns' `tr` locale (the data react-day-picker
//// uses). Pure data; dual-target. Names are standalone (nominative) forms, the
//// casing date-fns ships.

import gg_base_ui/calendar/localization

pub fn locale() -> localization.Localization {
  localization.Localization(
    month_names: [
      "Ocak",
      "Şubat",
      "Mart",
      "Nisan",
      "Mayıs",
      "Haziran",
      "Temmuz",
      "Ağustos",
      "Eylül",
      "Ekim",
      "Kasım",
      "Aralık",
    ],
    weekday_short: ["Pz", "Pt", "Sa", "Ça", "Pe", "Cu", "Ct"],
    weekday_long: [
      "Pazar",
      "Pazartesi",
      "Salı",
      "Çarşamba",
      "Perşembe",
      "Cuma",
      "Cumartesi",
    ],
    week_starts_on: 1,
    direction: localization.Ltr,
    labels: localization.Labels(
      previous_month: "Önceki aya git",
      next_month: "Sonraki aya git",
      month_dropdown: "Ay",
      year_dropdown: "Yıl",
    ),
  )
}
