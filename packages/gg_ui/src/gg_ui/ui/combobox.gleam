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
import gleam/list
import gleam/option.{type Option}
import lustre/attribute.{type Attribute}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html

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

/// The field: an `input_group` wrapping the headless `role=combobox` input plus a
/// trailing affordance — the lucide chevron, or (when `clearable` and something is
/// selected) a clear ✕ button. In `Multiple` mode the selected chips render
/// leading, inside the field. `placeholder` is the hint.
///
/// The positioning anchor sits on the **group**, not the inner input, so the
/// popup's `anchor-size(width)` matches the whole field (chips + input + addon).
pub fn input(
  anatomy: Anatomy,
  model: Model(value),
  placeholder placeholder: String,
  clearable clearable: Bool,
  attrs attrs: List(Attribute(Msg)),
) -> Element(Msg) {
  input_group.input_group(
    [
      base_combobox.anchor(anatomy),
      attribute.attribute("data-slot", "combobox"),
      ..attrs
    ],
    list.flatten([
      chips(model),
      [
        base_combobox.input(anatomy, model, [
          attribute.class(cn.cn(["cn-input-group-input", "cn-combobox-input"])),
          attribute.attribute("data-slot", "input-group-control"),
          attribute.placeholder(placeholder),
        ]),
        input_group.addon(
          input_group.InlineEnd,
          [],
          end_affordance(model, clearable),
        ),
      ],
    ]),
  )
}

// The selected chips, leading the input in `Multiple` mode (Base UI's
// `Combobox.Chips`). Nothing in `Single` mode or with no selection.
fn chips(model: Model(value)) -> List(Element(Msg)) {
  case base_combobox.selection_mode(model), base_combobox.has_selection(model) {
    base_combobox.Multiple, True -> [
      html.div(
        [
          attribute.class(cn.cn(["cn-combobox-chips"])),
          attribute.attribute("data-slot", "combobox-chips"),
          attribute.attribute("role", "group"),
          attribute.attribute("aria-label", "Selected"),
        ],
        list.index_map(base_combobox.selected_items(model), chip),
      ),
    ]
    _, _ -> []
  }
}

// One chip: the label + a built-in lucide ✕ remove button (behaviour from the
// headless `chip_remove_attributes`, keyed by the chip's index in the selection).
fn chip(item: base_combobox.Item(value), index: Int) -> Element(Msg) {
  html.span([attribute.class(cn.cn(["cn-combobox-chip"]))], [
    html.span([attribute.class(cn.cn(["cn-combobox-chip-label"]))], [
      html.text(item.label),
    ]),
    html.button(
      list.append(base_combobox.chip_remove_attributes(index, item.label), [
        attribute.class(cn.cn(["cn-combobox-chip-remove"])),
      ]),
      [chip_remove_glyph()],
    ),
  ])
}

// The trailing affordance: a clear button when `clearable` and a value is set
// (shadcn replaces the chevron with clear), otherwise the decorative chevron.
fn end_affordance(model: Model(value), clearable: Bool) -> List(Element(Msg)) {
  case clearable && base_combobox.has_selection(model) {
    True -> [
      input_group.button(
        input_group.IconXs,
        list.append(base_combobox.clear_attributes(), [
          attribute.attribute("aria-label", "Clear selection"),
          attribute.class(cn.cn(["cn-combobox-clear"])),
        ]),
        [clear_glyph()],
      ),
    ]
    False -> [
      // The chevron is a real trigger button (shadcn's ComboboxTrigger) — clicking
      // it toggles the list; behaviour from the headless `trigger_attributes`.
      input_group.button(
        input_group.IconXs,
        list.append(base_combobox.trigger_attributes(), [
          attribute.class(cn.cn(["cn-combobox-trigger"])),
        ]),
        [chevron_glyph()],
      ),
    ]
  }
}

// --- Built-in lucide glyphs (the source of truth; CLI-swappable at eject) -----
//
// Each carries an explicit `icon.size` so the button's `[&_svg:not([class*='size-
// '])]` default (size-3 on icon-xs) doesn't shrink them — the icons.md idiom.

fn chevron_glyph() -> Element(msg) {
  lu_c.chevron_down([icon.size(icon.Md)])
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

/// The popup: the headless `role=listbox` (native `popover`, positioned) holding
/// the visible options — flat, or re-sectioned under `role=group` headers for a
/// grouped list — plus a polite `role=status` region that announces the loading /
/// empty state. `aria-multiselectable` is set in `Multiple` mode.
pub fn content(
  anatomy: Anatomy,
  model: Model(value),
  side side: Side,
  align align: Align,
  empty_label empty_label: String,
  loading_label loading_label: String,
) -> Element(Msg) {
  let body = case base_combobox.is_empty(model) {
    True -> []
    False ->
      case base_combobox.visible_groups(model) {
        [] -> flat_options(anatomy, model)
        groups -> grouped_options(anatomy, model, groups)
      }
  }
  base_combobox.popup(
    anatomy,
    positioning.to_base(side, align),
    6,
    [attribute.class(cn.cn(["cn-combobox-content"]))],
    [
      base_combobox.list(
        anatomy,
        base_combobox.selection_mode(model),
        [attribute.class(cn.cn(["cn-combobox-list"]))],
        body,
      ),
      status(model, empty_label, loading_label),
    ],
  )
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
      [attribute.class(cn.cn(["cn-combobox-group"]))],
      [
        base_combobox.group_label(
          anatomy,
          gi,
          [attribute.class(cn.cn(["cn-combobox-group-label"]))],
          [html.text(label)],
        ),
        ..list.map(entries, fn(entry) { item(anatomy, model, entry.0, entry.1) })
      ],
    )
  })
}

// The polite live region (Base UI's `Status`/`Empty`). Always mounted so the
// announcement fires consistently; its children toggle — the loading line when
// `loading`, the empty message when nothing matches, nothing otherwise.
fn status(
  model: Model(value),
  empty_label: String,
  loading_label: String,
) -> Element(Msg) {
  let children = case model.loading, base_combobox.is_empty(model) {
    True, _ -> [
      html.div([attribute.class(cn.cn(["cn-combobox-loading"]))], [
        html.text(loading_label),
      ]),
    ]
    False, True -> [
      html.div([attribute.class(cn.cn(["cn-combobox-empty"]))], [
        html.text(empty_label),
      ]),
    ]
    False, False -> []
  }
  base_combobox.status(
    [attribute.class(cn.cn(["cn-combobox-status"]))],
    children,
  )
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

// One styled `role="option"` at visible position `pos`: the label + a built-in
// lucide check indicator (CSS shows it only when `aria-selected`). Private — its
// `base_combobox.Item` parameter must not surface in the public API.
fn item(
  anatomy: Anatomy,
  model: Model(value),
  pos: Int,
  it: base_combobox.Item(value),
) -> Element(Msg) {
  base_combobox.option(
    anatomy,
    model,
    pos,
    it,
    [attribute.class(cn.cn(["cn-combobox-item"]))],
    [
      html.span([attribute.class(cn.cn(["cn-combobox-item-label"]))], [
        html.text(it.label),
      ]),
      html.span([attribute.class(cn.cn(["cn-combobox-item-indicator"]))], [
        check_glyph(),
      ]),
    ],
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
