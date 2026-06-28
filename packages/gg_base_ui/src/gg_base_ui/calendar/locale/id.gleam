//// Indonesian locale for `gg_base_ui/calendar` — month/weekday names, week start, and
//// writing direction, from date-fns' `id` locale (the data react-day-picker
//// uses). Pure data; dual-target. Names are standalone (nominative) forms, the
//// casing date-fns ships.

import gg_base_ui/calendar/localization

pub fn locale() -> localization.Localization {
  localization.Localization(
    month_names: [
      "Januari",
      "Februari",
      "Maret",
      "April",
      "Mei",
      "Juni",
      "Juli",
      "Agustus",
      "September",
      "Oktober",
      "November",
      "Desember",
    ],
    weekday_short: ["Min", "Sen", "Sel", "Rab", "Kam", "Jum", "Sab"],
    weekday_long: [
      "Minggu",
      "Senin",
      "Selasa",
      "Rabu",
      "Kamis",
      "Jumat",
      "Sabtu",
    ],
    week_starts_on: 1,
    direction: localization.Ltr,
    labels: localization.Labels(
      previous_month: "Ke bulan sebelumnya",
      next_month: "Ke bulan berikutnya",
      month_dropdown: "Bulan",
      year_dropdown: "Tahun",
    ),
  )
}
