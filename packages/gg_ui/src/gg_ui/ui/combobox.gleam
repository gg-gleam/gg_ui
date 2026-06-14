//// shadcn-flavoured `Combobox` — the **thin** styled layer over the headless
//// `gg_base_ui/combobox`. The kit's first *stateful* component: the host embeds
//// it MVU-style (its model holds a `Model(value)` + an `Anatomy`; its update
//// threads `Msg` through `update`). This layer adds the `cn-*` class names — the
//// Tailwind recipes live in `styles/shapes/<style>/combobox.css` — and builds the
//// input on top of `input_group`. Behaviour + a11y stay in the headless layer.
////
//// **Facade (rule 2).** The caller-constructed surface is gg_ui's own: `Item` /
//// `Config` / `SelectionMode` are gg_ui types mapped to the headless layer via
//// private `*_to_base`. The opaque handles the caller only *threads* — `Model`,
//// `Msg`, `Anatomy` — are plain aliases (the sanctioned exception: the host never
//// constructs their variants). So a consumer/story imports **only `gg_ui/…`**.
////
//// **Icons are not a public-API concern.** The structural glyphs (dropdown
//// chevron, selected check, clear ✕) are built in from **lucide** — the source
//// of truth, matching shadcn's lucide default — not passed by the caller. So
//// `gg_ui` depends on `gg_icons_lucide`; the future CLI rewrites that import to
//// the user's `components.json` icon set at eject (name-mapped), so an ejected
//// app installs only its chosen set. See [`dev-docs/icons.md`](../../../../dev-docs/icons.md).
////
//// Single-select only for now; multiple / chips arrive with a later headless PR.

import gg_base_ui/combobox/combobox as base_combobox
import gg_icon/icon
import gg_icons_lucide/lucide/c as lu_c
import gg_icons_lucide/lucide/x as lu_x
import gg_ui/helpers/cn
import gg_ui/positioning.{type Align, type Side}
import gg_ui/ui/input_group
import gleam/list
import gleam/option.{type Option, is_some}
import lustre/attribute.{type Attribute}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html

// --- Handles (opaque aliases — threaded, never constructed by the caller) ---

/// The combobox state. Build it with `init`; read `selected` / `input_value` /
/// `is_open`. Threaded through `update` and the view parts.
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

/// Behaviour switches (Base UI's defaults via `config`). `loop` wraps arrow
/// navigation; `auto_highlight` highlights the first match as you type.
pub type Config {
  Config(loop: Bool, auto_highlight: Bool)
}

/// Selection mode. Only `Single` is wired today; `Multiple` is reserved.
pub type SelectionMode {
  Single
  Multiple
}

/// Base UI's defaults: looping navigation, no auto-highlight.
pub fn config() -> Config {
  Config(loop: True, auto_highlight: False)
}

// --- Lifecycle wrappers ----------------------------------------------------

/// A fresh, closed, empty-query model over `items`.
pub fn init(
  items items: List(Item(value)),
  config config: Config,
) -> Model(value) {
  base_combobox.init(
    items: list.map(items, item_to_base),
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

/// The currently selected value, if any.
pub fn selected(model: Model(value)) -> Option(value) {
  model.selected
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

/// The field: an `input_group` wrapping the headless `role=combobox` input plus
/// a trailing affordance — the lucide chevron, or (when `clearable` and something
/// is selected) a clear ✕ button. `placeholder` is the hint.
///
/// The positioning anchor sits on the **group**, not the inner input, so the
/// popup's `anchor-size(width)` matches the whole field (input + addon), not just
/// the narrower input.
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
  )
}

// The trailing affordance: a clear button when `clearable` and a value is set
// (shadcn replaces the chevron with clear), otherwise the decorative chevron.
fn end_affordance(model: Model(value), clearable: Bool) -> List(Element(Msg)) {
  case clearable && is_some(model.selected) {
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

/// The popup: the headless `role=listbox` (native `popover`, positioned) holding
/// one `item` per visible option, or an empty message when nothing matches.
pub fn content(
  anatomy: Anatomy,
  model: Model(value),
  side side: Side,
  align align: Align,
  empty_label empty_label: String,
) -> Element(Msg) {
  let options =
    base_combobox.visible(model)
    |> list.index_map(fn(pair, pos) { item(anatomy, model, pos, pair.1) })
  let children = case base_combobox.is_empty(model) {
    True -> [empty(empty_label)]
    False -> options
  }
  base_combobox.listbox(
    anatomy,
    positioning.to_base(side, align),
    6,
    [attribute.class(cn.cn(["cn-combobox-content"]))],
    children,
  )
}

/// The whole widget in one call: the field + the popup, assembled from `model`.
/// The common case for a single-select combobox.
pub fn combobox(
  anatomy anatomy: Anatomy,
  model model: Model(value),
  placeholder placeholder: String,
  side side: Side,
  align align: Align,
  clearable clearable: Bool,
  empty_label empty_label: String,
) -> Element(Msg) {
  html.div([attribute.class(cn.cn(["cn-combobox-root"]))], [
    input(anatomy, model, placeholder:, clearable:, attrs: []),
    content(anatomy, model, side:, align:, empty_label:),
  ])
}

// One styled `role=option`: the label + a built-in lucide check indicator (CSS
// shows it only when `aria-selected`). Private — its `base_combobox.Item`
// parameter must not surface in the public API.
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

fn empty(label: String) -> Element(Msg) {
  html.div([attribute.class(cn.cn(["cn-combobox-empty"]))], [html.text(label)])
}

// --- Mappings to the headless layer ----------------------------------------

fn item_to_base(item: Item(value)) -> base_combobox.Item(value) {
  base_combobox.Item(
    value: item.value,
    label: item.label,
    disabled: item.disabled,
  )
}

fn config_to_base(config: Config) -> base_combobox.Config {
  base_combobox.Config(loop: config.loop, auto_highlight: config.auto_highlight)
}
