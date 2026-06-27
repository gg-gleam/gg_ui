//// Integrity guard for the bundled locale data (generated from date-fns). Checks
//// a representative sample across scripts/directions that every locale has 12
//// months + 7+7 weekdays and a sane week start — so a bad parse can't ship.

import gg_base_ui/calendar/calendar
import gg_base_ui/calendar/locale/ar
import gg_base_ui/calendar/locale/en
import gg_base_ui/calendar/locale/es
import gg_base_ui/calendar/locale/he
import gg_base_ui/calendar/locale/ja
import gg_base_ui/calendar/locale/ru
import gg_base_ui/calendar/locale/th
import gg_base_ui/calendar/localization
import gleam/list
import gleeunit/should

fn check(loc: calendar.Localization) {
  list.length(loc.month_names) |> should.equal(12)
  list.length(loc.weekday_short) |> should.equal(7)
  list.length(loc.weekday_long) |> should.equal(7)
  { loc.week_starts_on >= 0 && loc.week_starts_on <= 6 } |> should.equal(True)
}

pub fn locale_shapes_test() {
  check(en.locale())
  check(es.locale())
  check(ru.locale())
  check(ar.locale())
  check(he.locale())
  check(ja.locale())
  check(th.locale())
}

pub fn direction_test() {
  en.locale().direction |> should.equal(localization.Ltr)
  ar.locale().direction |> should.equal(localization.Rtl)
  he.locale().direction |> should.equal(localization.Rtl)
}

pub fn arabic_week_start_test() {
  // Arabic weeks start on Saturday (date-fns `ar`).
  ar.locale().week_starts_on |> should.equal(6)
}
