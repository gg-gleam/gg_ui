//// French locale for `gg_base_ui/calendar` — month/weekday names, week start, and
//// writing direction, from date-fns' `fr` locale (the data react-day-picker
//// uses). Pure data; dual-target. Names are standalone (nominative) forms, the
//// casing date-fns ships.

import gg_base_ui/calendar/localization

pub fn locale() -> localization.Localization {
  localization.Localization(
    month_names: [
      "janvier",
      "février",
      "mars",
      "avril",
      "mai",
      "juin",
      "juillet",
      "août",
      "septembre",
      "octobre",
      "novembre",
      "décembre",
    ],
    weekday_short: ["di", "lu", "ma", "me", "je", "ve", "sa"],
    weekday_long: [
      "dimanche",
      "lundi",
      "mardi",
      "mercredi",
      "jeudi",
      "vendredi",
      "samedi",
    ],
    week_starts_on: 1,
    direction: localization.Ltr,
    labels: localization.Labels(
      previous_month: "Aller au mois précédent",
      next_month: "Aller au mois suivant",
      month_dropdown: "Mois",
      year_dropdown: "Année",
    ),
  )
}
