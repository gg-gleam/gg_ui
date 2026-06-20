//// shadcn-flavoured `Combobox` — the **thin** styled layer over the headless
//// `gg_base_ui/combobox`. The kit's first *stateful* component: the host embeds
//// it MVU-style (its model holds a `Model(value)` + an `Anatomy`; its update
//// threads `Msg` through `update`). This layer adds the `cn-*` class names — the
//// Tailwind recipes live in `styles/shapes/<style>/combobox.css` — and builds the
//// input on top of `input_group`. Behaviour + a11y stay in the headless layer.
////
//// **Facade (rule 2).** The caller-constructed surface is gg_ui's own: `Item` /
//// `Group` / `Config` / `SelectionMode` are gg_ui types mapped to the headless
//// layer via private `*_to_base`. The opaque handles the caller only *threads* —
//// `Model`, `Msg`, `Anatomy` — are plain aliases (the sanctioned exception: the
//// host never constructs their variants). So a consumer/story imports **only
//// `gg_ui/…`**.
////
//// **Icons are not a public-API concern.** The structural glyphs (dropdown
//// chevron, selected check, clear ✕, chip remove ✕) are built in from **lucide** —
//// the source of truth, matching shadcn's lucide default — not passed by the
//// caller. So `gg_ui` depends on `gg_icons_lucide`; the future CLI rewrites that
//// import to the user's `components.json` icon set at eject (name-mapped), so an
//// ejected app installs only its chosen set. See [`dev-docs/icons.md`](../../../../dev-docs/icons.md).
////
//// Both selection modes are wired: `Single` (replace + close) and `Multiple`
//// (toggle + stay open, picks surfaced as chips). Grouped lists, and a polite
//// `role=status` empty/loading announcer, are supported.

import gg_base_ui/combobox/combobox as base_combobox
import gg_icon/icon
import gg_icons_lucide/lucide/c as lu_c
import gg_icons_lucide/lucide/x as lu_x
import gg_ui/helpers/cn
import gg_ui/positioning.{type Align, type Side}
import gg_ui/ui/input_group
import gleam/int
import gleam/list
import gleam/option.{type Option}
import lustre/attribute.{type Attribute}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/element/keyed

// --- Handles (opaque aliases — threaded, never constructed by the caller) ---

/// The combobox state. Build it with `init` / `init_grouped`; read `selected` /
/// `selected_values` / `input_value` / `is_open`. Threaded through `update` and
/// the view parts.
pub type Model(value) =
  base_combobox.Model(value)

/// The component's messages. The host wraps this in its own `Msg` and threads it
/// through `update`; it never constructs the variants (the view parts wire them).
pub type Msg =
  base_combobox.Msg

/// The stable ids the parts share. Mint once with `anatomy` and keep it in the
/// host model; never recompute per render.
pub type Anatomy =
  base_combobox.Anatomy

// --- Caller-constructed types (gg_ui's own + private *_to_base) ------------

/// One option: the `value` selected, the `label` shown + filtered, and whether
/// it's `disabled`.
pub type Item(value) {
  Item(value: value, label: String, disabled: Bool)
}

/// A labelled section of the list (for `init_grouped`): a `label` over its
/// `items`. Empty groups (everything filtered out) hide automatically.
pub type Group(value) {
  Group(label: String, items: List(Item(value)))
}

/// Behaviour switches (Base UI's defaults via `config`). `loop` wraps arrow
/// navigation; `auto_highlight` highlights the first match as you type; `mode`
/// is the selection axis.
pub type Config {
  Config(loop: Bool, auto_highlight: Bool, mode: SelectionMode)
}

/// Selection mode. `Single` replaces the selection and closes on pick; `Multiple`
/// toggles membership, keeps the list open, and renders the picks as chips.
pub type SelectionMode {
  Single
  Multiple
}

/// Base UI's defaults: looping navigation, no auto-highlight, single-select.
pub fn config() -> Config {
  Config(loop: True, auto_highlight: False, mode: Single)
}

// --- Lifecycle wrappers ----------------------------------------------------

/// A fresh, closed, empty-query model over a flat `items` list.
pub fn init(
  items items: List(Item(value)),
  config config: Config,
) -> Model(value) {
  base_combobox.init(
    items: list.map(items, item_to_base),
    config: config_to_base(config),
  )
}

/// A fresh model over **grouped** items — one `Group` per labelled section.
pub fn init_grouped(
  groups groups: List(Group(value)),
  config config: Config,
) -> Model(value) {
  base_combobox.init_grouped(
    groups: list.map(groups, group_to_base),
    config: config_to_base(config),
  )
}

/// Mint an `Anatomy` with a fresh, collision-free id (the default).
pub fn anatomy() -> Anatomy {
  base_combobox.anatomy()
}

/// Mint an `Anatomy` from an explicit base id (tests / SSR pinning).
pub fn anatomy_with_id(id: String) -> Anatomy {
  base_combobox.anatomy_with_id(id)
}

/// Advance the state for a `Msg`, returning the new model + its DOM effect.
pub fn update(
  anatomy: Anatomy,
  model: Model(value),
  msg: Msg,
) -> #(Model(value), Effect(Msg)) {
  base_combobox.update(anatomy, model, msg)
}

/// Toggle the async loading state — drives the `status` live-region announcement.
pub fn set_loading(model: Model(value), loading: Bool) -> Model(value) {
  base_combobox.set_loading(model, loading)
}

/// The sole selected value, if any (single-select convenience — the first of the
/// selection in multiple mode).
pub fn selected(model: Model(value)) -> Option(value) {
  base_combobox.selected_value(model)
}

/// All selected values, in selection order (the chips, in multiple mode).
pub fn selected_values(model: Model(value)) -> List(value) {
  base_combobox.selected_values(model)
}

/// The text shown in the input (the typed query, or the chosen label).
pub fn input_value(model: Model(value)) -> String {
  model.input_value
}

/// Whether the list is open.
pub fn is_open(model: Model(value)) -> Bool {
  model.open
}

// --- Styled parts ----------------------------------------------------------

/// The field. In `Single` mode it's shadcn's `ComboboxInput`: an `input_group`
/// (carrying `cn-combobox-input w-auto`) around the headless `role=combobox`
/// input, with a trailing chevron `trigger` — or, when `clearable` and a value is
/// set, a clear ✕. In `Multiple` mode it's shadcn's `ComboboxChips`: a bordered
/// `cn-combobox-chips` container holding the chips followed by a bare
/// `cn-combobox-chip-input` (no addon/trigger — you deselect via the chips).
/// `placeholder` is the hint; the positioning anchor sits on the field so the
/// popup's `anchor-size(width)` matches it.
pub fn input(
  anatomy: Anatomy,
  model: Model(value),
  placeholder placeholder: String,
  clearable clearable: Bool,
  attrs attrs: List(Attribute(Msg)),
) -> Element(Msg) {
  case base_combobox.selection_mode(model) {
    base_combobox.Multiple -> chips_field(anatomy, model, placeholder, attrs)
    base_combobox.Single ->
      single_field(anatomy, model, placeholder, clearable, attrs)
  }
}

// Single-select field — shadcn's `ComboboxInput` (InputGroup + trailing
// trigger/clear). `cn-combobox-input` (`w-auto`) rides on the group, the inner
// input is a plain `input-group-control`.
fn single_field(
  anatomy: Anatomy,
  model: Model(value),
  placeholder: String,
  clearable: Bool,
  attrs: List(Attribute(Msg)),
) -> Element(Msg) {
  input_group.input_group(
    [
      base_combobox.anchor(anatomy),
      attribute.class(cn.cn(["cn-combobox-input"])),
      ..attrs
    ],
    [
      base_combobox.input(anatomy, model, [
        attribute.class(cn.cn(["cn-input-group-input"])),
        attribute.attribute("data-slot", "input-group-control"),
        attribute.placeholder(placeholder),
      ]),
      input_group.addon(
        input_group.InlineEnd,
        [],
        end_affordance(model, clearable),
      ),
    ],
  )
}

// Multiple-select field — shadcn's `ComboboxChips`: a bordered container of chips
// + a bare chip-input. The container is the positioning anchor.
//
// Children are **keyed** so the chip-input keeps a stable DOM identity as chips
// are added/removed: Base UI keeps focus on the one input (virtual focus). With
// an unkeyed list, Lustre diffs by position and recreates the trailing input
// node when a chip appears — dropping focus, which would lose the keyboard
// highlight position after a toggle. A constant key for the input (chips keyed by
// index) makes Lustre patch it in place, so focus + active-descendant survive.
fn chips_field(
  anatomy: Anatomy,
  model: Model(value),
  placeholder: String,
  attrs: List(Attribute(Msg)),
) -> Element(Msg) {
  let items = base_combobox.selected_items(model)
  let chip_count = list.length(items)
  let chips =
    list.index_map(items, fn(item, index) {
      #("chip-" <> int.to_string(index), chip(anatomy, item, index, chip_count))
    })
  let field_input =
    base_combobox.input(anatomy, model, [
      attribute.class(cn.cn(["cn-combobox-chip-input"])),
      attribute.attribute("data-slot", "combobox-chip-input"),
      attribute.placeholder(placeholder),
    ])
  keyed.div(
    [
      base_combobox.anchor(anatomy),
      // `w-full` keeps the field the width of its container (shadcn's example sets
      // `w-full` on `ComboboxChips`): chips then wrap onto new rows within that
      // fixed width — the field grows in height, never sideways with content.
      attribute.class(cn.cn(["cn-combobox-chips"])),
      attribute.class("w-full"),
      attribute.attribute("data-slot", "combobox-chips"),
      // Base UI sets exactly `role="toolbar"` on the chips container (and no
      // aria-label) — keeps NVDA in focus mode while arrowing between chips.
      attribute.attribute("role", "toolbar"),
      ..attrs
    ],
    list.append(chips, [#("combobox-input", field_input)]),
  )
}

// One chip (shadcn's `ComboboxChip`): the label text directly, then a built-in
// lucide ✕ remove button. The remove button is a ghost icon-xs button (shadcn
// renders `ComboboxChipRemove` as `<Button variant=ghost size=icon-xs>`); built
// here from the button recipe's `cn-*` names so the single `data-slot=combobox-
// chip-remove` wins (the chip's `has-data-[slot=combobox-chip-remove]:pr-0`).
fn chip(
  anatomy: Anatomy,
  item: base_combobox.Item(value),
  index: Int,
  chip_count: Int,
) -> Element(Msg) {
  html.div(
    list.flatten([
      [
        attribute.class(cn.cn(["cn-combobox-chip"])),
        attribute.attribute("data-slot", "combobox-chip"),
      ],
      // Roving-focus keydown behaviour (←/→, Delete, Enter → input).
      base_combobox.chip_attributes(anatomy, index, chip_count),
    ]),
    [
      html.text(item.label),
      html.button(
        list.append(base_combobox.chip_remove_attributes(index, item.label), [
          attribute.attribute("data-slot", "combobox-chip-remove"),
          attribute.class(
            cn.cn([
              "cn-button",
              "cn-button-variant-ghost",
              "cn-button-size-icon-xs",
              "cn-combobox-chip-remove",
            ]),
          ),
        ]),
        [chip_remove_glyph()],
      ),
    ],
  )
}

// The trailing affordance: a clear button when `clearable` and a value is set
// (shadcn replaces the chevron with clear), otherwise the decorative chevron.
// Both are ghost icon-xs InputGroupButtons in shadcn; built here from the button
// + input-group-button recipe `cn-*` names (rather than `input_group.button`) so
// each carries a single `data-slot` — shadcn gets one via Base UI render-prop
// merge, which we don't have, and triple `data-slot` is invalid HTML.
fn end_affordance(model: Model(value), clearable: Bool) -> List(Element(Msg)) {
  case clearable && base_combobox.has_selection(model) {
    True -> [
      affordance_button(
        "combobox-clear",
        "cn-combobox-clear",
        list.append(base_combobox.clear_attributes(), [
          attribute.attribute("aria-label", "Clear selection"),
        ]),
        clear_glyph(),
      ),
    ]
    False -> [
      // The chevron is a real trigger button (shadcn's ComboboxTrigger) — clicking
      // it toggles the list; behaviour from the headless `trigger_attributes`.
      affordance_button(
        "combobox-trigger",
        "cn-combobox-trigger",
        base_combobox.trigger_attributes(),
        chevron_glyph(),
      ),
    ]
  }
}

fn affordance_button(
  slot: String,
  recipe: String,
  behavior: List(Attribute(Msg)),
  glyph: Element(Msg),
) -> Element(Msg) {
  html.button(
    list.append(behavior, [
      attribute.attribute("data-slot", slot),
      attribute.class(
        cn.cn([
          "cn-button",
          "cn-button-variant-ghost",
          "cn-button-size-icon-xs",
          "cn-input-group-button",
          recipe,
        ]),
      ),
    ]),
    [glyph],
  )
}

// --- Built-in lucide glyphs (the source of truth; CLI-swappable at eject) -----
//
// Each carries an explicit `icon.size` so the button's `[&_svg:not([class*='size-
// '])]` default (size-3 on icon-xs) doesn't shrink them — the icons.md idiom.

fn chevron_glyph() -> Element(msg) {
  lu_c.chevron_down([
    icon.size(icon.Md),
    attribute.class("cn-combobox-trigger-icon"),
  ])
}

fn check_glyph() -> Element(msg) {
  lu_c.check([icon.size(icon.Md)])
}

fn clear_glyph() -> Element(msg) {
  lu_x.x([icon.size(icon.Md)])
}

fn chip_remove_glyph() -> Element(msg) {
  lu_x.x([icon.size(icon.Sm)])
}

/// The popup: the native-popover container (`cn-combobox-content`, carrying the
/// `group/combobox-content` marker + `data-empty` when nothing matches) holding
/// the always-mounted empty/loading announcers and the `role=listbox`. The list
/// holds the visible options — flat, or re-sectioned under `role=group` headers
/// for a grouped list. `aria-multiselectable` is set in `Multiple` mode.
pub fn content(
  anatomy: Anatomy,
  model: Model(value),
  side side: Side,
  align align: Align,
  empty_label empty_label: String,
  loading_label loading_label: String,
) -> Element(Msg) {
  let empty = base_combobox.is_empty(model)
  let body = case base_combobox.visible_groups(model) {
    [] -> flat_options(anatomy, model)
    groups -> grouped_options(anatomy, model, groups)
  }
  base_combobox.popup(
    anatomy,
    positioning.to_base(side, align),
    6,
    list.flatten([
      [
        attribute.class(cn.cn(["cn-combobox-content"])),
        attribute.class("group/combobox-content"),
        attribute.attribute("data-slot", "combobox-content"),
      ],
      empty_marker(empty),
    ]),
    list.flatten([
      announcers(model, empty_label, loading_label),
      [
        base_combobox.list(
          anatomy,
          base_combobox.selection_mode(model),
          list.flatten([
            [
              attribute.class(cn.cn(["cn-combobox-list"])),
              attribute.attribute("data-slot", "combobox-list"),
            ],
            empty_marker(empty),
          ]),
          body,
        ),
      ],
    ]),
  )
}

// `data-empty` on the content + list (shadcn's `data-empty:p-0` / the empty's
// `group-data-empty/combobox-content:flex` reveal). Empty value, present-or-absent.
fn empty_marker(empty: Bool) -> List(Attribute(msg)) {
  case empty {
    True -> [attribute.attribute("data-empty", "")]
    False -> []
  }
}

// The empty + loading announcers — Base UI's `Empty`/`Status`: always mounted
// (so the announcement fires consistently) and `role=status aria-live`. The empty
// message is CSS-hidden unless the content carries `data-empty`; the loading line
// shows only while `set_loading` is on (our async extension).
fn announcers(
  model: Model(value),
  empty_label: String,
  loading_label: String,
) -> List(Element(Msg)) {
  let loading = case model.loading {
    True -> [
      base_combobox.status(
        [
          attribute.class(cn.cn(["cn-combobox-loading"])),
          attribute.attribute("data-slot", "combobox-status"),
        ],
        [html.text(loading_label)],
      ),
    ]
    False -> []
  }
  list.append(loading, [
    base_combobox.status(
      [
        attribute.class(cn.cn(["cn-combobox-empty"])),
        attribute.attribute("data-slot", "combobox-empty"),
      ],
      [html.text(empty_label)],
    ),
  ])
}

// A flat (ungrouped) list of styled options, keyed by visible position.
fn flat_options(anatomy: Anatomy, model: Model(value)) -> List(Element(Msg)) {
  base_combobox.visible(model)
  |> list.index_map(fn(pair, pos) { item(anatomy, model, pos, pair.1) })
}

// Grouped options: one `role=group` per non-empty section, each with its label
// header and the section's options (still keyed by their flat visible position).
fn grouped_options(
  anatomy: Anatomy,
  model: Model(value),
  groups: List(#(String, List(#(Int, base_combobox.Item(value))))),
) -> List(Element(Msg)) {
  list.index_map(groups, fn(group, gi) {
    let #(label, entries) = group
    base_combobox.group(
      anatomy,
      gi,
      [
        attribute.class(cn.cn(["cn-combobox-group"])),
        attribute.attribute("data-slot", "combobox-group"),
      ],
      [
        base_combobox.group_label(
          anatomy,
          gi,
          [
            attribute.class(cn.cn(["cn-combobox-label"])),
            attribute.attribute("data-slot", "combobox-label"),
          ],
          [html.text(label)],
        ),
        ..list.map(entries, fn(entry) { item(anatomy, model, entry.0, entry.1) })
      ],
    )
  })
}

/// The whole widget in one call: the field + the popup, assembled from `model`.
/// The common case for a combobox.
pub fn combobox(
  anatomy anatomy: Anatomy,
  model model: Model(value),
  placeholder placeholder: String,
  side side: Side,
  align align: Align,
  clearable clearable: Bool,
  empty_label empty_label: String,
  loading_label loading_label: String,
) -> Element(Msg) {
  html.div([attribute.class(cn.cn(["cn-combobox-root"]))], [
    input(anatomy, model, placeholder:, clearable:, attrs: []),
    content(anatomy, model, side:, align:, empty_label:, loading_label:),
  ])
}

// One styled `role="option"` at visible position `pos`: the label text directly,
// then a built-in lucide check **indicator rendered only when selected** (Base
// UI's `ItemIndicator`). Private — its `base_combobox.Item` parameter must not
// surface in the public API.
fn item(
  anatomy: Anatomy,
  model: Model(value),
  pos: Int,
  it: base_combobox.Item(value),
) -> Element(Msg) {
  let indicator = case base_combobox.is_selected(model, it.value) {
    True -> [
      html.span([attribute.class(cn.cn(["cn-combobox-item-indicator"]))], [
        check_glyph(),
      ]),
    ]
    False -> []
  }
  base_combobox.option(
    anatomy,
    model,
    pos,
    it,
    [
      attribute.class(cn.cn(["cn-combobox-item"])),
      attribute.attribute("data-slot", "combobox-item"),
    ],
    [html.text(it.label), ..indicator],
  )
}

// --- Mappings to the headless layer ----------------------------------------

fn item_to_base(item: Item(value)) -> base_combobox.Item(value) {
  base_combobox.Item(
    value: item.value,
    label: item.label,
    disabled: item.disabled,
  )
}

fn group_to_base(group: Group(value)) -> base_combobox.Group(value) {
  base_combobox.Group(
    label: group.label,
    items: list.map(group.items, item_to_base),
  )
}

fn config_to_base(config: Config) -> base_combobox.Config {
  base_combobox.Config(
    loop: config.loop,
    auto_highlight: config.auto_highlight,
    mode: mode_to_base(config.mode),
  )
}

fn mode_to_base(mode: SelectionMode) -> base_combobox.SelectionMode {
  case mode {
    Single -> base_combobox.Single
    Multiple -> base_combobox.Multiple
  }
}
