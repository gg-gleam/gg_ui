//// Headless combobox — a Lustre port of Base UI's `Combobox.*`. **The kit's
//// first stateful component**: unlike popover/tooltip (native-first, render-once,
//// no model), a combobox has *no* native primitive — filtering, active-descendant
//// highlight, and listbox ARIA must run in a `Model`/`Msg`/`update`/`view`
//// component. See [`dev-docs/stateful-components.md`](../../../../dev-docs/stateful-components.md).
////
//// The module has two clearly-separated halves (see
//// [`dev-docs/stateful-components.md`](../../../../dev-docs/stateful-components.md)):
////
//// 1. **Pure core** — the state record and the pure transitions over it
////    (filtering, highlight navigation, open/close/query/select) with **no DOM,
////    no effects, no ARIA**. It behaves identically on JS and the BEAM (rule 3)
////    and is where the cross-target risk lives, so it's exhaustively unit-tested.
//// 2. **Effectful shell** — the Lustre component: `Anatomy`, `Msg`, `update`
////    (core transition + DOM effect), and the listbox/option `view` parts with
////    their ARIA. This is the **only** place DOM enters — event wiring, native
////    popover show/hide, and the scroll-into-view / focus FFI. The host embeds it
////    as an MVU module (its model holds a `Model(value)` + an `Anatomy`; its
////    update threads `Msg` through `update`).
////
//// Base UI mapping: `Root` owns this `Model`; `Input` dispatches `set_query`;
//// `List`/`Item` render `visible`; keyboard maps to `move` / `select_active`;
//// `Value`/`Empty` read the selectors. `Group`/`GroupLabel` re-section the
//// visible list (`visible_groups`); `Chips`/`Chip`/`ChipRemove` render + remove
//// `selected_items`; `Status` is the polite live region.
////
//// Both selection modes are wired (`selectionMode`): `Single` replaces +
//// closes; `Multiple` toggles membership, stays open, and surfaces picks as
//// chips. Deferred refinement (not a silent divergence): roving left/right
//// arrow navigation *between* chips — each chip is still removable via its
//// labelled button and Backspace pops the last one.

import gg_base_ui/helpers/id_gen/id_gen
import gg_base_ui/positioning/positioning.{type Placement}
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre/attribute.{type Attribute}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

// --- Items ---------------------------------------------------------------

/// One option in the list: the opaque `value` the caller selects, the `label`
/// shown + filtered against, and whether it's `disabled` (skipped by navigation
/// and not selectable). Mirrors a Base UI collection item.
pub type Item(value) {
  Item(value: value, label: String, disabled: Bool)
}

/// A labelled section of the list (Base UI's `Combobox.Group`). The items are
/// stored flat in the `Model` (so filtering / navigation / index math are
/// unchanged); a `GroupRange` records which slice of that flat list a group
/// covers so the view can re-section it under a `role="group"` header.
pub type Group(value) {
  Group(label: String, items: List(Item(value)))
}

/// A group's span in the flat `items` list — `label` plus the `[start, start +
/// length)` slice it owns. The pure core keeps these so `visible_groups` can
/// bucket the filtered list back into sections without re-threading the nesting.
pub type GroupRange {
  GroupRange(label: String, start: Int, length: Int)
}

// --- Config --------------------------------------------------------------

/// Behaviour switches, defaulted to Base UI's. `loop` = arrow navigation wraps
/// past the ends (`loopFocus`, default on). `auto_highlight` = the first match is
/// highlighted as you type (`autoHighlight`, default off). `mode` is Base UI's
/// `selectionMode` (single vs multiple/chips).
pub type Config {
  Config(loop: Bool, auto_highlight: Bool, mode: SelectionMode)
}

/// Base UI's defaults: looping navigation, no auto-highlight, single-select.
pub fn config() -> Config {
  Config(loop: True, auto_highlight: False, mode: Single)
}

/// Base UI's `selectionMode`. `Single` replaces the selection and closes on pick;
/// `Multiple` toggles membership, keeps the list open, and surfaces the picks as
/// chips.
pub type SelectionMode {
  Single
  Multiple
}

// --- Navigation ----------------------------------------------------------

/// A highlight move over the *visible* (filtered) list. `Next`/`Previous` are
/// the arrow keys; `First`/`Last` are Home/End.
pub type Nav {
  First
  Last
  Next
  Previous
}

// --- Model ---------------------------------------------------------------

/// The combobox's state. `query` is the filter text (what the user typed);
/// `input_value` is what the field displays (equal to `query` while typing, the
/// chosen label after a single-select pick). `active_index` highlights an entry
/// in the **visible** list (post-filter), not `items`. `selected` holds the
/// chosen values **in selection order** (0/1 entry for `Single`, the full set —
/// rendered as chips — for `Multiple`). `groups` is empty for a flat list, or one
/// `GroupRange` per section. `loading` drives the async `status` announcement.
pub type Model(value) {
  Model(
    open: Bool,
    query: String,
    input_value: String,
    items: List(Item(value)),
    groups: List(GroupRange),
    active_index: Option(Int),
    selected: List(value),
    loading: Bool,
    config: Config,
  )
}

/// A fresh, closed, empty-query model over a flat `items` list.
pub fn init(
  items items: List(Item(value)),
  config config: Config,
) -> Model(value) {
  Model(
    open: False,
    query: "",
    input_value: "",
    items:,
    groups: [],
    active_index: None,
    selected: [],
    loading: False,
    config:,
  )
}

/// A fresh model over **grouped** items (Base UI's grouped collection). The
/// groups are flattened into `items` (preserving order) with a `GroupRange` per
/// section, so every pure transition / index calculation is identical to the flat
/// case — only the view re-sections them.
pub fn init_grouped(
  groups groups: List(Group(value)),
  config config: Config,
) -> Model(value) {
  let #(items, ranges, _) =
    list.fold(groups, #([], [], 0), fn(acc, group) {
      let #(items, ranges, start) = acc
      let length = list.length(group.items)
      #(
        list.append(items, group.items),
        [GroupRange(label: group.label, start:, length:), ..ranges],
        start + length,
      )
    })
  Model(..init(items:, config:), groups: list.reverse(ranges))
}

// --- Filtering (pure) ----------------------------------------------------

/// Whether `label` matches `query`. Empty query matches everything (Base UI).
///
/// Base UI uses `Intl.Collator` with `sensitivity: 'base'` — case- *and*
/// accent-insensitive. This first cut is case-insensitive **substring** matching
/// (`string.lowercase` + `string.contains`), which is pure Gleam and identical on
/// both targets. Diacritic-folding (`é` ≡ `e`) is the one piece deferred — it
/// needs Unicode normalisation we don't pull in yet — and is tracked as a
/// refinement, not a behaviour we silently diverge on per target.
pub fn matches(label label: String, query query: String) -> Bool {
  query == ""
  || string.contains(
    does: string.lowercase(label),
    contain: string.lowercase(query),
  )
}

/// The visible list: `items` filtered by the current `query`, each paired with
/// its **original index** in `items` (option ids / value lookup need the stable
/// index, which filtering would otherwise lose).
pub fn visible(model: Model(value)) -> List(#(Int, Item(value))) {
  model.items
  |> list.index_map(fn(item, index) { #(index, item) })
  |> list.filter(fn(pair) {
    matches(label: { pair.1 }.label, query: model.query)
  })
}

/// How many entries the visible list has.
pub fn visible_count(model: Model(value)) -> Int {
  list.length(visible(model))
}

/// The visible list re-sectioned into groups: one `#(label, entries)` per
/// **non-empty** group, where each entry is `#(visible_position, item)` — the
/// flat post-filter position (the same index `option` / `option_id` key off, so
/// active-descendant + `OptionChosen` stay correct across sections). Empty groups
/// drop out (Base UI hides a fully-filtered group). Returns `[]` for a flat list
/// (no groups) — the caller renders `visible` directly in that case.
pub fn visible_groups(
  model: Model(value),
) -> List(#(String, List(#(Int, Item(value))))) {
  // Pair each visible entry with its flat post-filter position, then bucket by
  // the group whose original-index range contains it.
  let positioned =
    visible(model)
    |> list.index_map(fn(pair, pos) { #(pos, pair.0, pair.1) })
  model.groups
  |> list.filter_map(fn(range) {
    let entries =
      positioned
      |> list.filter(fn(p) {
        let original_index = p.1
        original_index >= range.start
        && original_index < range.start + range.length
      })
      |> list.map(fn(p) { #(p.0, p.2) })
    case entries {
      [] -> Error(Nil)
      _ -> Ok(#(range.label, entries))
    }
  })
}

/// The visible entry currently highlighted, if any.
pub fn active_item(model: Model(value)) -> Option(Item(value)) {
  case model.active_index {
    None -> None
    Some(index) ->
      visible(model)
      |> list.drop(index)
      |> list.first
      |> option.from_result
      |> option.map(fn(pair) { pair.1 })
  }
}

// --- Highlight navigation (pure) -----------------------------------------

/// Resolve a `Nav` move against a list of `count` entries, honouring `loop`.
/// `None` (nothing highlighted) seeds from the natural end: `Next`/`First` →
/// first, `Previous`/`Last` → last. Returns `None` only for an empty list.
pub fn navigate(
  active active: Option(Int),
  nav nav: Nav,
  count count: Int,
  loop loop: Bool,
) -> Option(Int) {
  case count {
    0 -> None
    _ ->
      case nav {
        First -> Some(0)
        Last -> Some(count - 1)
        Next ->
          case active {
            None -> Some(0)
            Some(i) if i >= count - 1 ->
              case loop {
                True -> Some(0)
                False -> Some(count - 1)
              }
            Some(i) -> Some(i + 1)
          }
        Previous ->
          case active {
            None -> Some(count - 1)
            Some(i) if i <= 0 ->
              case loop {
                True -> Some(count - 1)
                False -> Some(0)
              }
            Some(i) -> Some(i - 1)
          }
      }
  }
}

// --- Transitions (pure) --------------------------------------------------
//
// Each returns a new Model; the effectful shell maps a Msg to one of these and
// adds the DOM effect (scroll the active option into view, focus, …) around it.

/// Open the list.
pub fn open(model: Model(value)) -> Model(value) {
  Model(..model, open: True)
}

/// Close the list and drop the highlight (selection + input value are kept).
pub fn close(model: Model(value)) -> Model(value) {
  Model(..model, open: False, active_index: None)
}

/// Reset to the empty state — drop **all** selections, the typed text, and the
/// highlight (the open state is left as-is). Backs the clear affordance; unrelated
/// to selection mode (single or multiple can be clearable).
pub fn clear(model: Model(value)) -> Model(value) {
  Model(..model, selected: [], input_value: "", query: "", active_index: None)
}

/// Toggle whether the host is showing the async loading state — drives the
/// `status` live-region announcement (Base UI's `Combobox.Status`).
pub fn set_loading(model: Model(value), loading: Bool) -> Model(value) {
  Model(..model, loading:)
}

/// The user typed: set the filter `query` and the displayed `input_value` to the
/// text, open the list, and re-seat the highlight. `auto_highlight` lands on the
/// first match; otherwise the highlight clears (a stale index would point at the
/// wrong post-filter row).
pub fn set_query(model: Model(value), query: String) -> Model(value) {
  let next = Model(..model, query:, input_value: query, open: True)
  let active = case model.config.auto_highlight, visible_count(next) {
    True, count if count > 0 -> Some(0)
    _, _ -> None
  }
  Model(..next, active_index: active)
}

/// Move the highlight (arrow / Home / End) over the visible list.
pub fn move(model: Model(value), nav: Nav) -> Model(value) {
  let active =
    navigate(
      active: model.active_index,
      nav:,
      count: visible_count(model),
      loop: model.config.loop,
    )
  Model(..model, active_index: active)
}

/// Act on the highlighted entry (Enter / click on the active option) — `select`
/// in single mode, `toggle` in multiple. Returns the new model and the value
/// acted on (`None` if nothing was highlighted) so the shell can notify a
/// controlled parent; the shell reads `open` to decide whether to keep the list up.
pub fn select_active(model: Model(value)) -> #(Model(value), Option(value)) {
  case active_item(model) {
    None -> #(model, None)
    Some(item) -> choose(model, item)
  }
}

/// Act on a specific `item` (a pointer click that already knows the row),
/// dispatching on `mode`: `select` (single) replaces + closes; `toggle`
/// (multiple) flips membership + stays open.
pub fn choose(
  model: Model(value),
  item: Item(value),
) -> #(Model(value), Option(value)) {
  case model.config.mode {
    Single -> #(select(model, item), Some(item.value))
    Multiple -> #(toggle(model, item), Some(item.value))
  }
}

/// Single-select an `item`: record it as the sole selection, fill the input with
/// its label, close, clear the query so a reopen shows the full list.
pub fn select(model: Model(value), item: Item(value)) -> Model(value) {
  Model(
    ..model,
    selected: [item.value],
    input_value: item.label,
    query: "",
    open: False,
    active_index: None,
  )
}

/// Multiple-select toggle: flip `item.value`'s membership (append on add, so
/// chips keep selection order), **keep the list open**, and — matching Base UI's
/// clear-on-pick — reset the filter if the user had typed one (dropping the
/// highlight, since the visible list changes); an unfiltered toggle leaves the
/// highlight put, so repeated Enter toggles the same row.
pub fn toggle(model: Model(value), item: Item(value)) -> Model(value) {
  let selected = case list.contains(model.selected, item.value) {
    True -> list.filter(model.selected, fn(v) { v != item.value })
    False -> list.append(model.selected, [item.value])
  }
  case model.query {
    "" -> Model(..model, selected:, open: True)
    _ ->
      Model(
        ..model,
        selected:,
        query: "",
        input_value: "",
        open: True,
        active_index: None,
      )
  }
}

/// Remove the selection at chip `index` (a chip-remove click). Out-of-range is a
/// no-op. Order is preserved, so the remaining chips keep their positions.
pub fn remove_selected_at(model: Model(value), index: Int) -> Model(value) {
  let selected =
    model.selected
    |> list.index_map(fn(value, i) { #(i, value) })
    |> list.filter(fn(pair) { pair.0 != index })
    |> list.map(fn(pair) { pair.1 })
  Model(..model, selected:)
}

/// Remove the last selection (Backspace in an empty input). No-op when nothing is
/// selected.
pub fn remove_last_selected(model: Model(value)) -> Model(value) {
  case list.length(model.selected) {
    0 -> model
    n -> remove_selected_at(model, n - 1)
  }
}

// --- Selectors (pure reads) ----------------------------------------------

/// Whether `value` is among the current selections (drives an item's
/// `aria-selected` / check indicator). Uses Gleam structural equality — a
/// faithful stand-in for Base UI's `isItemEqualToValue` for plain value types.
pub fn is_selected(model: Model(value), value: value) -> Bool {
  list.contains(model.selected, value)
}

/// The sole selection (single-select convenience) — the first of the selection
/// list, `None` if nothing is selected.
pub fn selected_value(model: Model(value)) -> Option(value) {
  option.from_result(list.first(model.selected))
}

/// All selected values, in selection order (drives the chips in multiple mode).
pub fn selected_values(model: Model(value)) -> List(value) {
  model.selected
}

/// The selected **items** (value + label), in selection order — looked up in
/// `items` so the chips can show labels. Values with no matching item drop out.
pub fn selected_items(model: Model(value)) -> List(Item(value)) {
  list.filter_map(model.selected, fn(value) {
    list.find(model.items, fn(item) { item.value == value })
  })
}

/// Whether anything is selected (drives the clear affordance / chip rendering).
pub fn has_selection(model: Model(value)) -> Bool {
  model.selected != []
}

/// The model's selection mode (lets the styled facade emit the listbox's
/// `aria-multiselectable` without re-threading config).
pub fn selection_mode(model: Model(value)) -> SelectionMode {
  model.config.mode
}

/// Whether the visible list is empty (drives the `Empty` part).
pub fn is_empty(model: Model(value)) -> Bool {
  visible_count(model) == 0
}

// =========================================================================
// EFFECTFUL SHELL — the Lustre component (Anatomy / Msg / update / view)
// =========================================================================
//
// The only place DOM enters. Drives the pure core above and adds event wiring,
// listbox/option ARIA, native-popover show/hide, and the scroll/focus FFI.

// --- Anatomy -------------------------------------------------------------

/// The stable ids the parts share. Mint **once** (the `useId` analogue) and keep
/// it in the host model; never recompute per render. `popup_id` is the top-layer
/// native popover (the element shown/hidden + positioned); `listbox_id` is the
/// `role="listbox"` *inside* it (what the input's `aria-controls` points at, so
/// the popup can also hold the sibling `status` region without a
/// listbox-required-children violation).
pub type Anatomy {
  Anatomy(
    input_id: String,
    popup_id: String,
    listbox_id: String,
    label_id: String,
  )
}

/// Build an `Anatomy` with a fresh, collision-free base id (the default).
pub fn anatomy() -> Anatomy {
  anatomy_with_id(id_gen.generate_with_prefix("combobox"))
}

/// Build an `Anatomy` from an explicit base id — for tests or pinning across a
/// server/client render boundary. The caller owns uniqueness.
pub fn anatomy_with_id(id: String) -> Anatomy {
  Anatomy(
    input_id: id <> "-input",
    popup_id: id <> "-popup",
    listbox_id: id <> "-listbox",
    label_id: id <> "-label",
  )
}

/// Stable id for the option at visible position `pos` — the target of the
/// input's `aria-activedescendant` and the option's own `id`.
pub fn option_id(anatomy: Anatomy, pos: Int) -> String {
  anatomy.listbox_id <> "-option-" <> int.to_string(pos)
}

/// Stable id for group `gi`'s label — the target of the group's `aria-labelledby`
/// (wires `role="group"` to its `group_label`).
pub fn group_label_id(anatomy: Anatomy, gi: Int) -> String {
  anatomy.listbox_id <> "-group-" <> int.to_string(gi)
}

// --- Msg -----------------------------------------------------------------

/// What the component handles. The host threads these through `update`; it never
/// constructs them by hand (the view parts wire the events), so a styled facade
/// can keep `Msg` opaque.
pub type Msg {
  /// The input's text changed (`on_input`): re-filter + open.
  InputChanged(String)
  /// ArrowDown — highlight the next visible option (opening if closed).
  MoveNext
  /// ArrowUp — highlight the previous visible option.
  MovePrevious
  /// Home — highlight the first visible option.
  MoveFirst
  /// End — highlight the last visible option.
  MoveLast
  /// Enter — select the highlighted option.
  ChooseActive
  /// Escape — close without selecting.
  Dismissed
  /// A pointer click on the visible option at this position.
  OptionChosen(Int)
  /// Hover moved onto the visible option at this position (highlight follows).
  OptionHighlighted(Int)
  /// The native popover's `toggle` fired (`True` open / `False` closed) — keeps
  /// the model in sync.
  ListToggled(Bool)
  /// The input gained focus or was clicked — open the list.
  OpenRequested
  /// The trigger (chevron) was clicked — toggle the list open/closed.
  ToggleRequested
  /// The clear affordance was pressed — drop the selection + typed text.
  Cleared
  /// A chip's remove button was pressed — drop the selection at this index.
  ChipRemoved(Int)
  /// Backspace in an empty input — drop the last selection (multiple mode).
  LastChipRemoved
  /// No-op — carries a `preventDefault` on the popup's mousedown so a click
  /// inside the list doesn't blur the input (and so close it) before it lands.
  Noop
}

// --- update --------------------------------------------------------------

/// Map a `Msg` to a pure core transition plus any DOM effect (native popover
/// show/hide, scroll the active option into view, focus the input). Returns the
/// new model and its effect; the host inspects `model.selected` for the choice.
pub fn update(
  anatomy: Anatomy,
  model: Model(value),
  msg: Msg,
) -> #(Model(value), Effect(Msg)) {
  case msg {
    InputChanged(text) -> #(set_query(model, text), show(anatomy))
    MoveNext -> navigated(anatomy, model, Next)
    MovePrevious -> navigated(anatomy, model, Previous)
    MoveFirst -> navigated(anatomy, model, First)
    MoveLast -> navigated(anatomy, model, Last)
    ChooseActive -> {
      let #(next, _) = select_active(model)
      #(next, choose_effect(anatomy, next))
    }
    Dismissed -> #(close(model), hide(anatomy))
    OptionChosen(pos) -> {
      let #(next, _) = select_active(Model(..model, active_index: Some(pos)))
      #(next, choose_effect(anatomy, next))
    }
    ChipRemoved(index) -> #(remove_selected_at(model, index), focus(anatomy))
    LastChipRemoved -> #(remove_last_selected(model), focus(anatomy))
    OptionHighlighted(pos) -> #(
      Model(..model, active_index: Some(pos)),
      effect.none(),
    )
    ListToggled(True) -> #(open(model), effect.none())
    ListToggled(False) -> #(close(model), effect.none())
    OpenRequested -> #(
      open(model),
      effect.batch([show(anatomy), focus(anatomy)]),
    )
    ToggleRequested ->
      case model.open {
        True -> #(close(model), hide(anatomy))
        False -> #(open(model), effect.batch([show(anatomy), focus(anatomy)]))
      }
    // Clearing keeps focus so the user can keep typing.
    Cleared -> #(clear(model), focus(anatomy))
    Noop -> #(model, effect.none())
  }
}

// After a pick: single-select closed the list (hide it); multiple-select kept it
// open for the next toggle (keep it shown, input focused).
fn choose_effect(anatomy: Anatomy, next: Model(value)) -> Effect(Msg) {
  case next.open {
    True -> effect.batch([show(anatomy), focus(anatomy)])
    False -> hide(anatomy)
  }
}

// Arrow / Home / End: open (if needed), move the highlight, then show + scroll
// the now-active option into view.
fn navigated(
  anatomy: Anatomy,
  model: Model(value),
  nav: Nav,
) -> #(Model(value), Effect(Msg)) {
  let next = move(open(model), nav)
  #(next, effect.batch([show(anatomy), scroll_active(anatomy, next)]))
}

fn scroll_active(anatomy: Anatomy, model: Model(value)) -> Effect(Msg) {
  case model.active_index {
    Some(pos) ->
      effect.from(fn(_dispatch) {
        scroll_option_into_view(option_id(anatomy, pos))
      })
    None -> effect.none()
  }
}

fn show(anatomy: Anatomy) -> Effect(Msg) {
  effect.from(fn(_dispatch) { show_listbox(anatomy.popup_id) })
}

fn hide(anatomy: Anatomy) -> Effect(Msg) {
  effect.from(fn(_dispatch) { hide_listbox(anatomy.popup_id) })
}

fn focus(anatomy: Anatomy) -> Effect(Msg) {
  effect.from(fn(_dispatch) { focus_input(anatomy.input_id) })
}

// --- view parts ----------------------------------------------------------

/// The positioning anchor for the listbox. Put it on the **field** — the element
/// whose width the popup should match. For a bare input that's the input itself;
/// when the input is wrapped (e.g. in an input-group with a trailing chevron) put
/// it on the *wrapper*, so `anchor-size(width)` matches the whole field rather
/// than the narrower inner input.
pub fn anchor(anatomy: Anatomy) -> Attribute(msg) {
  positioning.anchor_style(anatomy.input_id)
}

/// The combobox `<input>` — `role="combobox"` wired to the listbox + the active
/// option, with the text + keyboard behaviour. Merge styling via `attrs`. Place
/// `anchor` on the field element (this input, or its wrapper) so the popup can
/// tether + size to it.
pub fn input(
  anatomy: Anatomy,
  model: Model(value),
  attrs: List(Attribute(Msg)),
) -> Element(Msg) {
  html.input(
    list.flatten([
      [
        attribute.id(anatomy.input_id),
        attribute.attribute("role", "combobox"),
        attribute.attribute("aria-autocomplete", "list"),
        attribute.attribute("aria-expanded", bool_attr(model.open)),
        attribute.attribute("aria-controls", anatomy.listbox_id),
        attribute.value(model.input_value),
        event.on_input(InputChanged),
        event.advanced(
          "keydown",
          keydown_handler(backspace_removes_chip(model)),
        ),
        event.on_focus(OpenRequested),
        // Click an already-focused input to reopen (focus won't refire).
        event.on_click(OpenRequested),
        // Outside-click dismissal: losing focus closes the list. Clicks inside
        // the popup keep focus (the listbox's mousedown preventDefault below), so
        // this only fires for a genuine click-away or Tab-out.
        event.on_blur(Dismissed),
      ],
      active_descendant(anatomy, model),
      attrs,
    ]),
  )
}

/// The top-layer **popup** — the native `popover` box, anchored to the input via
/// `gg_base_ui/positioning`. It holds the `list` plus any sibling parts (the
/// `status` live region), which is why the `role="listbox"` lives on the inner
/// `list`, not here: a listbox may only contain options/groups, so the announcer
/// can't be its child.
///
/// It's a **`popover="manual"`** (not `auto`): we still want the native top layer
/// (so the popup escapes `overflow`/`transform` clipping), but **not** the native
/// light-dismiss — `auto` would close it on the very click that opened it,
/// because our trigger is an `<input>`, not an associated invoker button. The
/// combobox owns dismissal instead (input blur + Escape), the way Base UI's
/// `useDismiss` does. The mousedown `preventDefault` keeps a click *inside* the
/// popup from blurring the input (which would close it before an option's click
/// lands). `placement` / `side_offset` reuse `gg_base_ui/positioning`.
pub fn popup(
  anatomy: Anatomy,
  placement: Placement,
  side_offset: Int,
  attrs: List(Attribute(Msg)),
  children: List(Element(Msg)),
) -> Element(Msg) {
  html.div(
    list.flatten([
      [
        attribute.id(anatomy.popup_id),
        attribute.attribute("popover", "manual"),
        attribute.attribute(
          "data-side",
          positioning.side_to_string(placement.side),
        ),
        attribute.attribute(
          "data-align",
          positioning.align_to_string(placement.align),
        ),
        event.on("toggle", toggle_decoder()),
        event.advanced("mousedown", keep_focus_handler()),
      ],
      positioning.positioned_style(anatomy.input_id, placement, side_offset),
      attrs,
    ]),
    children,
  )
}

/// The `role="listbox"` itself (the input's `aria-controls` target), holding the
/// `option`s / `group`s. `mode` adds `aria-multiselectable` in multiple mode.
/// Render it inside `popup`, as a sibling of any `status` region.
pub fn list(
  anatomy: Anatomy,
  mode: SelectionMode,
  attrs: List(Attribute(msg)),
  options: List(Element(msg)),
) -> Element(msg) {
  html.div(
    list.flatten([
      [
        attribute.id(anatomy.listbox_id),
        attribute.attribute("role", "listbox"),
      ],
      list_attributes(mode),
      attrs,
    ]),
    options,
  )
}

// Extra listbox ARIA keyed off the selection mode — `aria-multiselectable` in
// multiple mode (Base UI's `ComboboxList`).
fn list_attributes(mode: SelectionMode) -> List(Attribute(msg)) {
  case mode {
    Multiple -> [attribute.attribute("aria-multiselectable", "true")]
    Single -> []
  }
}

/// A labelled section header + its options (Base UI's `Combobox.Group`):
/// `role="group"` wired by `aria-labelledby` to the `group_label` it contains.
/// `gi` is the group's index (its `group_label_id`). `children` is the label part
/// followed by the section's `option`s.
pub fn group(
  anatomy: Anatomy,
  gi: Int,
  attrs: List(Attribute(msg)),
  children: List(Element(msg)),
) -> Element(msg) {
  html.div(
    list.flatten([
      [
        attribute.attribute("role", "group"),
        attribute.attribute("aria-labelledby", group_label_id(anatomy, gi)),
      ],
      attrs,
    ]),
    children,
  )
}

/// A group's label element — carries the `id` the parent `group` points
/// `aria-labelledby` at. Presentational (no role); place it first in the group.
pub fn group_label(
  anatomy: Anatomy,
  gi: Int,
  attrs: List(Attribute(msg)),
  children: List(Element(msg)),
) -> Element(msg) {
  html.div([attribute.id(group_label_id(anatomy, gi)), ..attrs], children)
}

/// A polite live region (Base UI's `Combobox.Status` / `Empty`): announces async
/// loading / empty-result changes to screen readers. **Keep it mounted** — toggle
/// its *children*, not the element — so the announcement fires consistently.
pub fn status(
  attrs: List(Attribute(msg)),
  children: List(Element(msg)),
) -> Element(msg) {
  html.div(
    list.flatten([
      [
        attribute.attribute("role", "status"),
        attribute.attribute("aria-live", "polite"),
        attribute.attribute("aria-atomic", "true"),
      ],
      attrs,
    ]),
    children,
  )
}

/// One `role="option"` at visible position `pos`. Carries `aria-selected`,
/// `data-highlighted` when active, and `data-disabled`/`aria-disabled`; clicking
/// selects, hovering highlights. `children` is the label (+ any indicator).
pub fn option(
  anatomy: Anatomy,
  model: Model(value),
  pos: Int,
  item: Item(value),
  attrs: List(Attribute(Msg)),
  children: List(Element(Msg)),
) -> Element(Msg) {
  html.div(
    list.flatten([
      [
        attribute.id(option_id(anatomy, pos)),
        attribute.attribute("role", "option"),
        attribute.attribute(
          "aria-selected",
          bool_attr(is_selected(model, item.value)),
        ),
        event.on_click(OptionChosen(pos)),
        event.on_mouse_enter(OptionHighlighted(pos)),
      ],
      highlighted_attr(model, pos),
      disabled_attr(item),
      attrs,
    ]),
    children,
  )
}

/// Behaviour for a clear/reset control (shadcn's `ComboboxClear`): clicking it
/// drops the selection + typed text. The mousedown `preventDefault` keeps the
/// input focused so the list doesn't blur-close. Merge onto your clear `<button>`.
pub fn clear_attributes() -> List(Attribute(Msg)) {
  [
    attribute.attribute("type", "button"),
    event.on_click(Cleared),
    event.advanced("mousedown", keep_focus_handler()),
  ]
}

/// Behaviour for a chip's remove control (Base UI's `Combobox.ChipRemove`):
/// clicking drops the selection at `index`. Labelled `Remove <label>` for screen
/// readers, and the mousedown `preventDefault` keeps the input focused so the
/// list doesn't blur-close. Merge onto the chip's remove `<button>`.
pub fn chip_remove_attributes(
  index: Int,
  label: String,
) -> List(Attribute(Msg)) {
  [
    attribute.attribute("type", "button"),
    attribute.attribute("tabindex", "-1"),
    attribute.attribute("aria-label", "Remove " <> label),
    event.on_click(ChipRemoved(index)),
    event.advanced("mousedown", keep_focus_handler()),
  ]
}

/// Behaviour for the dropdown trigger (shadcn's `ComboboxTrigger`): clicking it
/// toggles the list. It's `tabindex="-1"` — the input is the focusable control —
/// and the mousedown `preventDefault` keeps focus on the input. Merge onto your
/// chevron `<button>`.
pub fn trigger_attributes() -> List(Attribute(Msg)) {
  [
    attribute.attribute("type", "button"),
    attribute.attribute("tabindex", "-1"),
    attribute.attribute("aria-label", "Toggle suggestions"),
    event.on_click(ToggleRequested),
    event.advanced("mousedown", keep_focus_handler()),
  ]
}

fn active_descendant(
  anatomy: Anatomy,
  model: Model(value),
) -> List(Attribute(Msg)) {
  case model.open, model.active_index {
    True, Some(pos) -> [
      attribute.attribute("aria-activedescendant", option_id(anatomy, pos)),
    ]
    _, _ -> []
  }
}

fn highlighted_attr(model: Model(value), pos: Int) -> List(Attribute(Msg)) {
  case model.active_index == Some(pos) {
    True -> [attribute.attribute("data-highlighted", "")]
    False -> []
  }
}

fn disabled_attr(item: Item(value)) -> List(Attribute(Msg)) {
  case item.disabled {
    True -> [
      attribute.attribute("data-disabled", ""),
      attribute.attribute("aria-disabled", "true"),
    ]
    False -> []
  }
}

fn bool_attr(value: Bool) -> String {
  case value {
    True -> "true"
    False -> "false"
  }
}

// Backspace pops the last chip only when there's a chip to pop and the caret has
// nothing to delete — multiple mode with an empty input. Single mode (or a
// non-empty input) never steals Backspace from normal text editing.
fn backspace_removes_chip(model: Model(value)) -> Bool {
  model.config.mode == Multiple
  && model.input_value == ""
  && has_selection(model)
}

fn keydown_handler(
  backspace_removes_chip: Bool,
) -> decode.Decoder(event.Handler(Msg)) {
  use key <- decode.field("key", decode.string)
  // Nav keys dispatch + preventDefault (stop the caret/page from also moving);
  // any other key fails the decoder, so typing flows through untouched.
  case key {
    "ArrowDown" -> decode.success(nav_handler(MoveNext))
    "ArrowUp" -> decode.success(nav_handler(MovePrevious))
    "Home" -> decode.success(nav_handler(MoveFirst))
    "End" -> decode.success(nav_handler(MoveLast))
    "Enter" -> decode.success(nav_handler(ChooseActive))
    "Escape" ->
      decode.success(event.handler(
        dispatch: Dismissed,
        prevent_default: False,
        stop_propagation: False,
      ))
    "Backspace" if backspace_removes_chip ->
      decode.success(nav_handler(LastChipRemoved))
    _ -> decode.failure(nav_handler(Dismissed), "combobox-ignored-key")
  }
}

fn nav_handler(msg: Msg) -> event.Handler(Msg) {
  event.handler(dispatch: msg, prevent_default: True, stop_propagation: False)
}

fn toggle_decoder() -> decode.Decoder(Msg) {
  use new_state <- decode.field("newState", decode.string)
  decode.success(ListToggled(new_state == "open"))
}

// Always preventDefault the popup's mousedown so the focused input isn't blurred
// by a click inside the list (which `on_blur` would otherwise read as a
// click-away and close). Dispatches `Noop` — the preventDefault is the point.
fn keep_focus_handler() -> decode.Decoder(event.Handler(Msg)) {
  decode.success(event.handler(
    dispatch: Noop,
    prevent_default: True,
    stop_propagation: False,
  ))
}

// --- FFI -----------------------------------------------------------------
//
// JS-only; the Erlang fallbacks never run (effects execute client-side), so an
// SSR render produces the markup with no client effect. Keep export names in
// sync with `combobox_ffi.ts`.

@external(javascript, "./combobox_ffi.ts", "showPopover")
fn show_listbox(_listbox_id: String) -> Nil {
  Nil
}

@external(javascript, "./combobox_ffi.ts", "hidePopover")
fn hide_listbox(_listbox_id: String) -> Nil {
  Nil
}

@external(javascript, "./combobox_ffi.ts", "scrollOptionIntoView")
fn scroll_option_into_view(_option_id: String) -> Nil {
  Nil
}

@external(javascript, "./combobox_ffi.ts", "focusInput")
fn focus_input(_input_id: String) -> Nil {
  Nil
}
