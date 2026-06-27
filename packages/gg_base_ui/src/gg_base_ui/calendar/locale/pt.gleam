//// Portuguese locale for `gg_base_ui/calendar` — month/weekday names, week start, and
//// writing direction, from date-fns' `pt` locale (the data react-day-picker
//// uses). Pure data; dual-target. Names are standalone (nominative) forms, the
//// casing date-fns ships.

import gg_base_ui/calendar/localization

pub fn locale() -> localization.Localization {
  localization.Localization(
    month_names: [
      "janeiro",
      "fevereiro",
      "março",
      "abril",
      "maio",
      "junho",
      "julho",
      "agosto",
      "setembro",
      "outubro",
      "novembro",
      "dezembro",
    ],
    weekday_short: ["dom", "seg", "ter", "qua", "qui", "sex", "sáb"],
    weekday_long: [
      "domingo",
      "segunda-feira",
      "terça-feira",
      "quarta-feira",
      "quinta-feira",
      "sexta-feira",
      "sábado",
    ],
    week_starts_on: 0,
    direction: localization.Ltr,
    labels: localization.Labels(
      previous_month: "Ir para o mês anterior",
      next_month: "Ir para o próximo mês",
      month_dropdown: "Mês",
      year_dropdown: "Ano",
    ),
  )
}
