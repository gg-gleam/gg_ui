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
//// `info_circle`. That mismatch is exactly why the placeholder carries one name
//// per set; here the typed enum hides it behind a single `Info`.

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

/// The project-wide icon set (shadcn's `iconLibrary`).
pub type IconSet {
  Lucide
  Tabler
}

/// The per-usage variant. lucide is single-variant and ignores this.
pub type IconVariant {
  Outline
  Filled
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
/// don't, and fall back to outline under a fill variant (icons.md fill caveat).
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
    _ -> Lucide
  }
}

/// Parse the raw `iconVariant` toolbar-global string. Unknown → `Outline`.
pub fn parse_variant(variant: String) -> IconVariant {
  case variant {
    "filled" -> Filled
    _ -> Outline
  }
}

/// Render a demo glyph for the active `(set, variant)`. `attrs` flow straight
/// through to the generated icon (so `icon.size(...)` / `size-*` work).
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
        Outline -> tabler_outline(which, attrs)
        Filled ->
          case fillable(which) {
            True -> tabler_filled(which, attrs)
            False -> tabler_outline(which, attrs)
          }
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
