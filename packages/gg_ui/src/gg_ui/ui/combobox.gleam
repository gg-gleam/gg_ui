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
/// navigation; `auto_highlight` highlights the first match as you type; `mode` is
/// the selection axis; `filter` is who filters the list (the component, or the
/// host/server — a remote/server search).
pub type Config {
  Config(
    loop: Bool,
    auto_highlight: Bool,
    mode: SelectionMode,
    filter: FilterMode,
  )
}

/// Selection mode. `Single` replaces the selection and closes on pick; `Multiple`
/// toggles membership, keeps the list open, and renders the picks as chips.
pub type SelectionMode {
  Single
  Multiple
}

/// Who filters the list. `Client` (default) substring-filters `items` by the
/// typed query; `Manual` leaves the list as-is (the host fetched already-filtered
/// results — a remote/server search). Base UI's `filter={null}`.
pub type FilterMode {
  Client
  Manual
}

/// Base UI's defaults: looping navigation, no auto-highlight, single-select,
/// client-side filtering.
pub fn config() -> Config {
  Config(loop: True, auto_highlight: False, mode: Single, filter: Client)
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

/// Replace the whole `items` list (a remote search returned a fresh page one).
/// Drops the highlight and any group sections. For a `Manual`-filter combobox.
pub fn set_items(
  model: Model(value),
  items: List(Item(value)),
) -> Model(value) {
  base_combobox.set_items(model, list.map(items, item_to_base))
}

/// Append more `items` (the next page of a paginated/remote list); the highlight
/// is kept so keyboard position survives a page load.
pub fn append_items(
  model: Model(value),
  items: List(Item(value)),
) -> Model(value) {
  base_combobox.append_items(model, list.map(items, item_to_base))
}

/// A scroll handler for the `list` that fires when it's within `threshold` px of
/// its bottom — wire it onto the `list` to auto-load the next page. It's a no-op
/// for the combobox; the host checks `is_reached_end` on the threaded `Msg` to
/// fetch. (The popup owns the native toggle observer, so this is a `Msg`, not a
/// host-generic event.)
pub fn on_scroll_end(threshold threshold: Int) -> Attribute(Msg) {
  base_combobox.on_scroll_end(threshold:)
}

/// Whether `msg` is the `list`'s near-bottom signal (from `on_scroll_end`). In
/// your `update`, check it on the wrapped combobox `Msg` to fetch the next page.
pub fn is_reached_end(msg: Msg) -> Bool {
  base_combobox.is_reached_end(msg)
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

/// How many items are currently visible (post-filter, or all of them in `Manual`
/// mode) — e.g. to decide whether more pages remain to load.
pub fn visible_count(model: Model(value)) -> Int {
  base_combobox.visible_count(model)
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

/// The popup container (shadcn's `ComboboxContent`) — the native-popover box
/// (`cn-combobox-content`, the `group/combobox-content` marker + `data-empty`
/// when nothing matches). You **compose** what goes inside: an `empty`, an
/// optional `loading`, and a `list`. `side`/`align` position it; `attrs` and
/// `children` are merged.
pub fn content(
  anatomy: Anatomy,
  model: Model(value),
  side side: Side,
  align align: Align,
  attrs attrs: List(Attribute(Msg)),
  children children: List(Element(Msg)),
) -> Element(Msg) {
  base_combobox.popup(
    anatomy,
    positioning.to_base(side, align),
    // 8px (shadcn's sideOffset is 6) so the gap clears the field's 3px focus ring
    // — at 6 the ring eats most of the gap and the popup reads as over the input.
    8,
    list.flatten([
      [
        attribute.class(cn.cn(["cn-combobox-content"])),
        attribute.class("group/combobox-content"),
        attribute.attribute("data-slot", "combobox-content"),
      ],
      empty_marker(is_empty(model)),
      attrs,
    ]),
    children,
  )
}

/// The `role=listbox` (shadcn's `ComboboxList`) — `aria-multiselectable` in
/// `Multiple` mode, `data-empty` when there's nothing to show. Fill it with
/// `options` / `items` (flat) or `groups` (sectioned), plus any footer (e.g. a
/// pagination sentinel). A sibling of `empty`/`loading` inside `content`.
pub fn list(
  anatomy: Anatomy,
  model: Model(value),
  attrs attrs: List(Attribute(Msg)),
  children children: List(Element(Msg)),
) -> Element(Msg) {
  base_combobox.list(
    anatomy,
    base_combobox.selection_mode(model),
    list.flatten([
      [
        attribute.class(cn.cn(["cn-combobox-list"])),
        attribute.attribute("data-slot", "combobox-list"),
      ],
      empty_marker(is_empty(model)),
      attrs,
    ]),
    children,
  )
}

/// The empty announcer (shadcn's `ComboboxEmpty`) — a polite `role=status` region
/// CSS-revealed only when `content` carries `data-empty`. `children` is **any UI**
/// (text, an icon, interpolated copy). Keep it mounted so the announcement fires.
pub fn empty(
  attrs attrs: List(Attribute(Msg)),
  children children: List(Element(Msg)),
) -> Element(Msg) {
  base_combobox.status(
    list.flatten([
      [
        attribute.class(cn.cn(["cn-combobox-empty"])),
        attribute.attribute("data-slot", "combobox-empty"),
      ],
      attrs,
    ]),
    children,
  )
}

/// The loading announcer (Base UI's `Status`) — a polite `role=status` region for
/// async work. `children` is **any UI** (a spinner + text). Render it conditionally
/// on `is_loading`; it sits as a sibling of `empty`/`list` inside `content`.
pub fn loading(
  attrs attrs: List(Attribute(Msg)),
  children children: List(Element(Msg)),
) -> Element(Msg) {
  base_combobox.status(
    list.flatten([
      [
        attribute.class(cn.cn(["cn-combobox-loading"])),
        attribute.attribute("data-slot", "combobox-status"),
      ],
      attrs,
    ]),
    children,
  )
}

/// Whether the visible list is empty (gate the `empty`/`list` composition).
pub fn is_empty(model: Model(value)) -> Bool {
  base_combobox.is_empty(model)
}

/// Whether the async loading state is on (gate the `loading` part).
pub fn is_loading(model: Model(value)) -> Bool {
  model.loading
}

// `data-empty` on the content + list (shadcn's `data-empty:p-0` / the empty's
// `group-data-empty/combobox-content:flex` reveal). Empty value, present-or-absent.
fn empty_marker(empty: Bool) -> List(Attribute(msg)) {
  case empty {
    True -> [attribute.attribute("data-empty", "")]
    False -> []
  }
}

// --- Options + groups (composition sugars) ---------------------------------

/// The default options — one label-only `option` per visible item, keyed by its
/// visible position. The ergonomic flat-list filler: `list(.., options(..))`.
pub fn options(anatomy: Anatomy, model: Model(value)) -> List(Element(Msg)) {
  items(model, fn(it, pos) { option(anatomy, model, pos, it) })
}

/// Map the visible items to elements with your own per-item renderer (custom item
/// content — an avatar, secondary text, …). `render` gets the `Item` and its
/// visible position. Pair with `item` for the styled option shell.
pub fn items(
  model: Model(value),
  render render: fn(Item(value), Int) -> Element(Msg),
) -> List(Element(Msg)) {
  base_combobox.visible(model)
  |> list.index_map(fn(pair, pos) { render(item_from_base(pair.1), pos) })
}

/// One styled `role=option` (shadcn's `ComboboxItem`) at visible position `pos`.
/// `children` is the item's content; a lucide check **indicator is appended only
/// when the item is selected** (Base UI's `ItemIndicator`). Clicking selects.
pub fn item(
  anatomy: Anatomy,
  model: Model(value),
  pos: Int,
  item: Item(value),
  children: List(Element(Msg)),
) -> Element(Msg) {
  let indicator = case base_combobox.is_selected(model, item.value) {
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
    item_to_base(item),
    [
      attribute.class(cn.cn(["cn-combobox-item"])),
      attribute.attribute("data-slot", "combobox-item"),
    ],
    list.append(children, indicator),
  )
}

/// A label-only `item` — the common case (`combobox.option(anatomy, model, pos, it)`).
pub fn option(
  anatomy: Anatomy,
  model: Model(value),
  pos: Int,
  it: Item(value),
) -> Element(Msg) {
  item(anatomy, model, pos, it, [html.text(it.label)])
}

/// Map the visible **groups** to elements with your own per-section renderer:
/// `render` gets the group label, its entries (`#(visible_position, Item)` — the
/// flat positions `item` keys off), and the group index. Empty groups drop out.
/// Compose each section with `group` + `label` + `item`.
pub fn groups(
  model: Model(value),
  render render: fn(String, List(#(Int, Item(value))), Int) -> Element(Msg),
) -> List(Element(Msg)) {
  base_combobox.visible_groups(model)
  |> list.index_map(fn(g, gi) {
    let #(lbl, entries) = g
    let entries = list.map(entries, fn(e) { #(e.0, item_from_base(e.1)) })
    render(lbl, entries, gi)
  })
}

/// A labelled section (shadcn's `ComboboxGroup`) — `role=group` wired to its
/// `label` by `gi`. `children` is the `label` then the section's `item`s.
pub fn group(
  anatomy: Anatomy,
  gi: Int,
  attrs: List(Attribute(Msg)),
  children: List(Element(Msg)),
) -> Element(Msg) {
  base_combobox.group(
    anatomy,
    gi,
    list.flatten([
      [
        attribute.class(cn.cn(["cn-combobox-group"])),
        attribute.attribute("data-slot", "combobox-group"),
      ],
      attrs,
    ]),
    children,
  )
}

/// A group's label (shadcn's `ComboboxLabel`) — the `aria-labelledby` target for
/// `group gi`. Place it first in the group.
pub fn label(
  anatomy: Anatomy,
  gi: Int,
  attrs: List(Attribute(Msg)),
  children: List(Element(Msg)),
) -> Element(Msg) {
  base_combobox.group_label(
    anatomy,
    gi,
    list.flatten([
      [
        attribute.class(cn.cn(["cn-combobox-label"])),
        attribute.attribute("data-slot", "combobox-label"),
      ],
      attrs,
    ]),
    children,
  )
}

fn item_to_base(item: Item(value)) -> base_combobox.Item(value) {
  base_combobox.Item(
    value: item.value,
    label: item.label,
    disabled: item.disabled,
  )
}

fn item_from_base(item: base_combobox.Item(value)) -> Item(value) {
  Item(value: item.value, label: item.label, disabled: item.disabled)
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
    filter: filter_to_base(config.filter),
  )
}

fn mode_to_base(mode: SelectionMode) -> base_combobox.SelectionMode {
  case mode {
    Single -> base_combobox.Single
    Multiple -> base_combobox.Multiple
  }
}

fn filter_to_base(filter: FilterMode) -> base_combobox.FilterMode {
  case filter {
    Client -> base_combobox.Client
    Manual -> base_combobox.Manual
  }
}
