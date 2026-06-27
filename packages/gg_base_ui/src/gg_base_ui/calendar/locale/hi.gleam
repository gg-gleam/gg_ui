//// Hindi locale for `gg_base_ui/calendar` — month/weekday names, week start, and
//// writing direction, from date-fns' `hi` locale (the data react-day-picker
//// uses). Pure data; dual-target. Names are standalone (nominative) forms, the
//// casing date-fns ships.

import gg_base_ui/calendar/localization

pub fn locale() -> localization.Localization {
  localization.Localization(
    month_names: [
      "जनवरी",
      "फ़रवरी",
      "मार्च",
      "अप्रैल",
      "मई",
      "जून",
      "जुलाई",
      "अगस्त",
      "सितंबर",
      "अक्टूबर",
      "नवंबर",
      "दिसंबर",
    ],
    weekday_short: ["र", "सो", "मं", "बु", "गु", "शु", "श"],
    weekday_long: ["रविवार", "सोमवार", "मंगलवार", "बुधवार", "गुरुवार", "शुक्रवार", "शनिवार"],
    week_starts_on: 0,
    direction: localization.Ltr,
    labels: localization.Labels(
      previous_month: "पिछले महीने पर जाएँ",
      next_month: "अगले महीने पर जाएँ",
      month_dropdown: "महीना",
      year_dropdown: "वर्ष",
    ),
  )
}
