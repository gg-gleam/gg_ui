//// The curated demo icon catalog — dev-only, lives in the Storybook app.
////
//// Storybook is the ONE place allowed to import concrete `gg_icons_*` sets (the
//// `gg_icon` interface stays set-agnostic). This module branches over a TYPED
//// `DemoIcon` enum, so a glyph missing from any shipped `(set, variant)` is a
//// COMPILE error, not a runtime miss — the "manifest-validated catalog" the
//// icons.md design calls for, enforced by the type checker.
////
//// It is bounded to ~20 typical UI glyphs that exist across every shipped set.
//// Bounded is the point: the live set/variant switcher pulls only these ~20
//// across sets, never the whole ~6k-icon packages, so it never defeats the
//// production tree-shaking of direct icon calls.
////
//// Per icons.md: set-switching uses all ~20 (every set has them in its default
//// variant). A `filled` variant has no meaningful form for some stroke-only
//// glyphs (`menu`, `arrow_right`) — those deliberately FALL BACK to the outline
//// rendering, flagged by `fillable`, never a surprise.
////
//// Note the per-set NAME differences this proves out: lucide `info` is tabler
//// `info_circle` is heroicons `information_circle`; lucide `x`/tabler `x` is
//// heroicons `x_mark`; `search` is heroicons `magnifying_glass`; `settings` is
//// heroicons `cog_6_tooth`; `menu` is heroicons `bars_3`; `alert_triangle` is
//// heroicons `exclamation_triangle`; `external_link` is heroicons
//// `arrow_top_right_on_square`. That mismatch is exactly why the placeholder
//// carries one name per set; here the typed enum hides it behind a single name.
////
//// Variants are per-set: lucide is single-variant (one rendering); tabler ships
//// `outline` + `filled`; heroicons ships `outline` + `solid` + `mini` + `micro`.
//// A variant a set doesn't have falls back to that set's default (outline).

import lustre/attribute.{type Attribute}
import lustre/element.{type Element}

// lucide — single variant; shards a,b,c,e,h,i,m,p,s,t,u,x
import gg_icons_lucide/lucide/a as lu_a
import gg_icons_lucide/lucide/b as lu_b
import gg_icons_lucide/lucide/c as lu_c
import gg_icons_lucide/lucide/e as lu_e
import gg_icons_lucide/lucide/h as lu_h
import gg_icons_lucide/lucide/i as lu_i
import gg_icons_lucide/lucide/m as lu_m
import gg_icons_lucide/lucide/p as lu_p
import gg_icons_lucide/lucide/s as lu_s
import gg_icons_lucide/lucide/t as lu_t
import gg_icons_lucide/lucide/u as lu_u
import gg_icons_lucide/lucide/x as lu_x

// tabler · outline — the default variant; same shard spread as lucide
import gg_icons_tabler/outline/a as to_a
import gg_icons_tabler/outline/b as to_b
import gg_icons_tabler/outline/c as to_c
import gg_icons_tabler/outline/e as to_e
import gg_icons_tabler/outline/h as to_h
import gg_icons_tabler/outline/i as to_i
import gg_icons_tabler/outline/m as to_m
import gg_icons_tabler/outline/p as to_p
import gg_icons_tabler/outline/s as to_s
import gg_icons_tabler/outline/t as to_t
import gg_icons_tabler/outline/u as to_u
import gg_icons_tabler/outline/x as to_x

// tabler · filled — no `m`/`arrow_right`; those glyphs aren't filled (see render)
import gg_icons_tabler/filled/a as tf_a
import gg_icons_tabler/filled/b as tf_b
import gg_icons_tabler/filled/c as tf_c
import gg_icons_tabler/filled/e as tf_e
import gg_icons_tabler/filled/h as tf_h
import gg_icons_tabler/filled/i as tf_i
import gg_icons_tabler/filled/p as tf_p
import gg_icons_tabler/filled/s as tf_s
import gg_icons_tabler/filled/t as tf_t
import gg_icons_tabler/filled/u as tf_u
import gg_icons_tabler/filled/x as tf_x

// heroicons · outline — the default variant (24×24 stroke); shards a,b,c,e,h,i,m,p,s,t,u,x
import gg_icons_heroicons/outline/a as ho_a
import gg_icons_heroicons/outline/b as ho_b
import gg_icons_heroicons/outline/c as ho_c
import gg_icons_heroicons/outline/e as ho_e
import gg_icons_heroicons/outline/h as ho_h
import gg_icons_heroicons/outline/i as ho_i
import gg_icons_heroicons/outline/m as ho_m
import gg_icons_heroicons/outline/p as ho_p
import gg_icons_heroicons/outline/s as ho_s
import gg_icons_heroicons/outline/t as ho_t
import gg_icons_heroicons/outline/u as ho_u
import gg_icons_heroicons/outline/x as ho_x

// heroicons · solid — 24×24 solid glyph; every demo glyph has a solid form
import gg_icons_heroicons/solid/a as hs_a
import gg_icons_heroicons/solid/b as hs_b
import gg_icons_heroicons/solid/c as hs_c
import gg_icons_heroicons/solid/e as hs_e
import gg_icons_heroicons/solid/h as hs_h
import gg_icons_heroicons/solid/i as hs_i
import gg_icons_heroicons/solid/m as hs_m
import gg_icons_heroicons/solid/p as hs_p
import gg_icons_heroicons/solid/s as hs_s
import gg_icons_heroicons/solid/t as hs_t
import gg_icons_heroicons/solid/u as hs_u
import gg_icons_heroicons/solid/x as hs_x

// heroicons · mini — 20×20 solid glyph
import gg_icons_heroicons/mini/a as hmi_a
import gg_icons_heroicons/mini/b as hmi_b
import gg_icons_heroicons/mini/c as hmi_c
import gg_icons_heroicons/mini/e as hmi_e
import gg_icons_heroicons/mini/h as hmi_h
import gg_icons_heroicons/mini/i as hmi_i
import gg_icons_heroicons/mini/m as hmi_m
import gg_icons_heroicons/mini/p as hmi_p
import gg_icons_heroicons/mini/s as hmi_s
import gg_icons_heroicons/mini/t as hmi_t
import gg_icons_heroicons/mini/u as hmi_u
import gg_icons_heroicons/mini/x as hmi_x

// heroicons · micro — 16×16 solid glyph
import gg_icons_heroicons/micro/a as hmc_a
import gg_icons_heroicons/micro/b as hmc_b
import gg_icons_heroicons/micro/c as hmc_c
import gg_icons_heroicons/micro/e as hmc_e
import gg_icons_heroicons/micro/h as hmc_h
import gg_icons_heroicons/micro/i as hmc_i
import gg_icons_heroicons/micro/m as hmc_m
import gg_icons_heroicons/micro/p as hmc_p
import gg_icons_heroicons/micro/s as hmc_s
import gg_icons_heroicons/micro/t as hmc_t
import gg_icons_heroicons/micro/u as hmc_u
import gg_icons_heroicons/micro/x as hmc_x

/// The project-wide icon set (shadcn's `iconLibrary`).
pub type IconSet {
  Lucide
  Tabler
  Heroicons
}

/// The per-usage variant, union of every shipped set's variants. A set renders
/// only the variants it has; an inapplicable one falls back to its default
/// (outline). lucide is single-variant and ignores this entirely.
pub type IconVariant {
  Outline
  Filled
  Solid
  Mini
  Micro
}

/// The curated demo glyphs. Each exists in every shipped set's default variant.
pub type DemoIcon {
  ChevronDown
  ChevronRight
  Check
  Close
  Search
  Settings
  User
  Home
  Calendar
  Plus
  Trash
  Pencil
  Info
  AlertTriangle
  Star
  Heart
  Bell
  Menu
  ArrowRight
  ExternalLink
}

/// Every demo glyph, in display order (for the gallery grid).
pub fn all() -> List(DemoIcon) {
  [
    ChevronDown, ChevronRight, Check, Close, Search, Settings, User, Home,
    Calendar, Plus, Trash, Pencil, Info, AlertTriangle, Star, Heart, Bell, Menu,
    ArrowRight, ExternalLink,
  ]
}

/// A human label for the gallery (the canonical kebab name).
pub fn label(which: DemoIcon) -> String {
  case which {
    ChevronDown -> "chevron-down"
    ChevronRight -> "chevron-right"
    Check -> "check"
    Close -> "x"
    Search -> "search"
    Settings -> "settings"
    User -> "user"
    Home -> "home"
    Calendar -> "calendar"
    Plus -> "plus"
    Trash -> "trash"
    Pencil -> "pencil"
    Info -> "info"
    AlertTriangle -> "alert-triangle"
    Star -> "star"
    Heart -> "heart"
    Bell -> "bell"
    Menu -> "menu"
    ArrowRight -> "arrow-right"
    ExternalLink -> "external-link"
  }
}

/// Whether the glyph has a meaningful `filled` form. The two stroke-only glyphs
/// don't, and fall back to outline under tabler's fill variant (icons.md fill
/// caveat). Heroicons ships a solid form for every glyph, so this only gates
/// tabler `filled`.
pub fn fillable(which: DemoIcon) -> Bool {
  case which {
    Menu | ArrowRight -> False
    _ -> True
  }
}

/// Parse the raw `iconSet` toolbar-global string (Storybook hands stories raw
/// strings). Unknown → `Lucide`, the initial global. Shared by every story that
/// threads the toolbar globals into its `mount_*`.
pub fn parse_set(set: String) -> IconSet {
  case set {
    "tabler" -> Tabler
    "heroicons" -> Heroicons
    _ -> Lucide
  }
}

/// Parse the raw `iconVariant` toolbar-global string. Unknown → `Outline`.
pub fn parse_variant(variant: String) -> IconVariant {
  case variant {
    "filled" -> Filled
    "solid" -> Solid
    "mini" -> Mini
    "micro" -> Micro
    _ -> Outline
  }
}

/// Render a demo glyph for the active `(set, variant)`. `attrs` flow straight
/// through to the generated icon (so `icon.size(...)` / `size-*` work). A
/// variant the set doesn't ship falls back to its default variant.
pub fn render(
  set: IconSet,
  variant: IconVariant,
  which: DemoIcon,
  attrs: List(Attribute(msg)),
) -> Element(msg) {
  case set {
    Lucide -> lucide(which, attrs)
    Tabler ->
      case variant {
        Filled ->
          case fillable(which) {
            True -> tabler_filled(which, attrs)
            False -> tabler_outline(which, attrs)
          }
        // outline + any non-tabler variant → tabler's default (outline)
        _ -> tabler_outline(which, attrs)
      }
    Heroicons ->
      case variant {
        Solid -> heroicons_solid(which, attrs)
        Mini -> heroicons_mini(which, attrs)
        Micro -> heroicons_micro(which, attrs)
        // outline + any non-heroicons variant → heroicons' default (outline)
        _ -> heroicons_outline(which, attrs)
      }
  }
}

fn lucide(which: DemoIcon, attrs: List(Attribute(msg))) -> Element(msg) {
  case which {
    ChevronDown -> lu_c.chevron_down(attrs)
    ChevronRight -> lu_c.chevron_right(attrs)
    Check -> lu_c.check(attrs)
    Close -> lu_x.x(attrs)
    Search -> lu_s.search(attrs)
    Settings -> lu_s.settings(attrs)
    User -> lu_u.user(attrs)
    Home -> lu_h.home(attrs)
    Calendar -> lu_c.calendar(attrs)
    Plus -> lu_p.plus(attrs)
    Trash -> lu_t.trash(attrs)
    Pencil -> lu_p.pencil(attrs)
    Info -> lu_i.info(attrs)
    AlertTriangle -> lu_a.alert_triangle(attrs)
    Star -> lu_s.star(attrs)
    Heart -> lu_h.heart(attrs)
    Bell -> lu_b.bell(attrs)
    Menu -> lu_m.menu(attrs)
    ArrowRight -> lu_a.arrow_right(attrs)
    ExternalLink -> lu_e.external_link(attrs)
  }
}

fn tabler_outline(
  which: DemoIcon,
  attrs: List(Attribute(msg)),
) -> Element(msg) {
  case which {
    ChevronDown -> to_c.chevron_down(attrs)
    ChevronRight -> to_c.chevron_right(attrs)
    Check -> to_c.check(attrs)
    Close -> to_x.x(attrs)
    Search -> to_s.search(attrs)
    Settings -> to_s.settings(attrs)
    User -> to_u.user(attrs)
    Home -> to_h.home(attrs)
    Calendar -> to_c.calendar(attrs)
    Plus -> to_p.plus(attrs)
    Trash -> to_t.trash(attrs)
    Pencil -> to_p.pencil(attrs)
    Info -> to_i.info_circle(attrs)
    AlertTriangle -> to_a.alert_triangle(attrs)
    Star -> to_s.star(attrs)
    Heart -> to_h.heart(attrs)
    Bell -> to_b.bell(attrs)
    Menu -> to_m.menu(attrs)
    ArrowRight -> to_a.arrow_right(attrs)
    ExternalLink -> to_e.external_link(attrs)
  }
}

fn tabler_filled(which: DemoIcon, attrs: List(Attribute(msg))) -> Element(msg) {
  case which {
    ChevronDown -> tf_c.chevron_down(attrs)
    ChevronRight -> tf_c.chevron_right(attrs)
    Check -> tf_c.check(attrs)
    Close -> tf_x.x(attrs)
    Search -> tf_s.search(attrs)
    Settings -> tf_s.settings(attrs)
    User -> tf_u.user(attrs)
    Home -> tf_h.home(attrs)
    Calendar -> tf_c.calendar(attrs)
    Plus -> tf_p.plus(attrs)
    Trash -> tf_t.trash(attrs)
    Pencil -> tf_p.pencil(attrs)
    Info -> tf_i.info_circle(attrs)
    AlertTriangle -> tf_a.alert_triangle(attrs)
    Star -> tf_s.star(attrs)
    Heart -> tf_h.heart(attrs)
    Bell -> tf_b.bell(attrs)
    // Not fillable — render never routes these here, but the case must be total;
    // outline is the honest answer.
    Menu -> to_m.menu(attrs)
    ArrowRight -> to_a.arrow_right(attrs)
    ExternalLink -> tf_e.external_link(attrs)
  }
}

fn heroicons_outline(
  which: DemoIcon,
  attrs: List(Attribute(msg)),
) -> Element(msg) {
  case which {
    ChevronDown -> ho_c.chevron_down(attrs)
    ChevronRight -> ho_c.chevron_right(attrs)
    Check -> ho_c.check(attrs)
    Close -> ho_x.x_mark(attrs)
    Search -> ho_m.magnifying_glass(attrs)
    Settings -> ho_c.cog_6_tooth(attrs)
    User -> ho_u.user(attrs)
    Home -> ho_h.home(attrs)
    Calendar -> ho_c.calendar(attrs)
    Plus -> ho_p.plus(attrs)
    Trash -> ho_t.trash(attrs)
    Pencil -> ho_p.pencil(attrs)
    Info -> ho_i.information_circle(attrs)
    AlertTriangle -> ho_e.exclamation_triangle(attrs)
    Star -> ho_s.star(attrs)
    Heart -> ho_h.heart(attrs)
    Bell -> ho_b.bell(attrs)
    Menu -> ho_b.bars_3(attrs)
    ArrowRight -> ho_a.arrow_right(attrs)
    ExternalLink -> ho_a.arrow_top_right_on_square(attrs)
  }
}

fn heroicons_solid(
  which: DemoIcon,
  attrs: List(Attribute(msg)),
) -> Element(msg) {
  case which {
    ChevronDown -> hs_c.chevron_down(attrs)
    ChevronRight -> hs_c.chevron_right(attrs)
    Check -> hs_c.check(attrs)
    Close -> hs_x.x_mark(attrs)
    Search -> hs_m.magnifying_glass(attrs)
    Settings -> hs_c.cog_6_tooth(attrs)
    User -> hs_u.user(attrs)
    Home -> hs_h.home(attrs)
    Calendar -> hs_c.calendar(attrs)
    Plus -> hs_p.plus(attrs)
    Trash -> hs_t.trash(attrs)
    Pencil -> hs_p.pencil(attrs)
    Info -> hs_i.information_circle(attrs)
    AlertTriangle -> hs_e.exclamation_triangle(attrs)
    Star -> hs_s.star(attrs)
    Heart -> hs_h.heart(attrs)
    Bell -> hs_b.bell(attrs)
    Menu -> hs_b.bars_3(attrs)
    ArrowRight -> hs_a.arrow_right(attrs)
    ExternalLink -> hs_a.arrow_top_right_on_square(attrs)
  }
}

fn heroicons_mini(
  which: DemoIcon,
  attrs: List(Attribute(msg)),
) -> Element(msg) {
  case which {
    ChevronDown -> hmi_c.chevron_down(attrs)
    ChevronRight -> hmi_c.chevron_right(attrs)
    Check -> hmi_c.check(attrs)
    Close -> hmi_x.x_mark(attrs)
    Search -> hmi_m.magnifying_glass(attrs)
    Settings -> hmi_c.cog_6_tooth(attrs)
    User -> hmi_u.user(attrs)
    Home -> hmi_h.home(attrs)
    Calendar -> hmi_c.calendar(attrs)
    Plus -> hmi_p.plus(attrs)
    Trash -> hmi_t.trash(attrs)
    Pencil -> hmi_p.pencil(attrs)
    Info -> hmi_i.information_circle(attrs)
    AlertTriangle -> hmi_e.exclamation_triangle(attrs)
    Star -> hmi_s.star(attrs)
    Heart -> hmi_h.heart(attrs)
    Bell -> hmi_b.bell(attrs)
    Menu -> hmi_b.bars_3(attrs)
    ArrowRight -> hmi_a.arrow_right(attrs)
    ExternalLink -> hmi_a.arrow_top_right_on_square(attrs)
  }
}

fn heroicons_micro(
  which: DemoIcon,
  attrs: List(Attribute(msg)),
) -> Element(msg) {
  case which {
    ChevronDown -> hmc_c.chevron_down(attrs)
    ChevronRight -> hmc_c.chevron_right(attrs)
    Check -> hmc_c.check(attrs)
    Close -> hmc_x.x_mark(attrs)
    Search -> hmc_m.magnifying_glass(attrs)
    Settings -> hmc_c.cog_6_tooth(attrs)
    User -> hmc_u.user(attrs)
    Home -> hmc_h.home(attrs)
    Calendar -> hmc_c.calendar(attrs)
    Plus -> hmc_p.plus(attrs)
    Trash -> hmc_t.trash(attrs)
    Pencil -> hmc_p.pencil(attrs)
    Info -> hmc_i.information_circle(attrs)
    AlertTriangle -> hmc_e.exclamation_triangle(attrs)
    Star -> hmc_s.star(attrs)
    Heart -> hmc_h.heart(attrs)
    Bell -> hmc_b.bell(attrs)
    Menu -> hmc_b.bars_3(attrs)
    ArrowRight -> hmc_a.arrow_right(attrs)
    ExternalLink -> hmc_a.arrow_top_right_on_square(attrs)
  }
}
