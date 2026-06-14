//// Story mounts for the styled `InputGroup`. `Playground` drives the addon
//// `align` from the controls; `Alignments` renders every align in a column for
//// visual review. Addon glyphs come from the demo catalog and follow the **Icon
//// set** / **Icon variant** toolbar globals. The input-group story has no host
//// state, so it renders once via `lustre.element` (like the popover terse mount),
//// not `lustre.application`.

import gg_ui/ui/input_group.{
  type Align, BlockEnd, BlockStart, IconXs, InlineEnd, InlineStart, Xs,
}
import lustre
import lustre/attribute.{type Attribute}
import lustre/element.{type Element}
import lustre/element/html
import stories/icons/demo_icons.{type IconSet, type IconVariant}

fn mount(selector: String, view: Element(msg)) -> Nil {
  let assert Ok(_) = lustre.start(lustre.element(view), selector, Nil)
  Nil
}

// --- mounts --------------------------------------------------------------

pub fn mount_input_group_playground(
  selector: String,
  align: String,
  icon_set: String,
  icon_variant: String,
) -> Nil {
  mount(
    selector,
    view_playground(
      parse_align(align),
      demo_icons.parse_set(icon_set),
      demo_icons.parse_variant(icon_variant),
    ),
  )
}

pub fn mount_input_group_alignments(
  selector: String,
  icon_set: String,
  icon_variant: String,
) -> Nil {
  mount(
    selector,
    view_alignments(
      demo_icons.parse_set(icon_set),
      demo_icons.parse_variant(icon_variant),
    ),
  )
}

pub fn mount_input_group_invalid(
  selector: String,
  icon_set: String,
  icon_variant: String,
) -> Nil {
  mount(
    selector,
    view_invalid(
      demo_icons.parse_set(icon_set),
      demo_icons.parse_variant(icon_variant),
    ),
  )
}

// --- args ----------------------------------------------------------------

fn parse_align(align: String) -> Align {
  case align {
    "inline-end" -> InlineEnd
    "block-start" -> BlockStart
    "block-end" -> BlockEnd
    _ -> InlineStart
  }
}

// --- views ---------------------------------------------------------------

fn view_playground(
  align: Align,
  icon_set: IconSet,
  icon_variant: IconVariant,
) -> Element(msg) {
  center([
    input_group.input_group([], [
      input_group.input([attribute.placeholder("Search…")]),
      input_group.addon(align, [], [
        demo_icons.render(icon_set, icon_variant, demo_icons.Search, []),
      ]),
    ]),
  ])
}

fn view_alignments(
  icon_set: IconSet,
  icon_variant: IconVariant,
) -> Element(msg) {
  let search = fn() {
    demo_icons.render(icon_set, icon_variant, demo_icons.Search, [])
  }
  column([
    // Leading icon.
    input_group.input_group([], [
      input_group.input([attribute.placeholder("Search…")]),
      input_group.addon(InlineStart, [], [search()]),
    ]),
    // Trailing icon button (the combobox-trigger shape).
    input_group.input_group([], [
      input_group.input([attribute.placeholder("Pick a framework…")]),
      input_group.addon(InlineEnd, [], [
        input_group.button(IconXs, [aria_label("Open")], [
          demo_icons.render(icon_set, icon_variant, demo_icons.ChevronDown, []),
        ]),
      ]),
    ]),
    // Trailing muted text (a unit / suffix).
    input_group.input_group([], [
      input_group.input([attribute.placeholder("0.00")]),
      input_group.addon(InlineEnd, [], [
        input_group.text([], [html.text("USD")]),
      ]),
    ]),
    // Both edges: leading icon + trailing button.
    input_group.input_group([], [
      input_group.addon(InlineStart, [], [search()]),
      input_group.input([attribute.placeholder("Search and go…")]),
      input_group.addon(InlineEnd, [], [
        input_group.button(Xs, [], [html.text("Go")]),
      ]),
    ]),
  ])
}

/// shadcn's error state lives on the *container*: any slotted descendant with
/// `aria-invalid="true"` turns the whole group destructive (border + ring). The
/// red border shows statically here; the red ring (like the focus ring) needs
/// focus, so click into a field to see it.
fn view_invalid(icon_set: IconSet, icon_variant: IconVariant) -> Element(msg) {
  let invalid = attribute.attribute("aria-invalid", "true")
  column([
    // Invalid input alone — the group border turns destructive.
    input_group.input_group([], [
      input_group.input([attribute.placeholder("name@example.com"), invalid]),
    ]),
    // With addons: the destructive state is the group's, so it wraps them too.
    input_group.input_group([], [
      input_group.addon(InlineStart, [], [
        demo_icons.render(icon_set, icon_variant, demo_icons.Search, []),
      ]),
      input_group.input([attribute.placeholder("Search…"), invalid]),
      input_group.addon(InlineEnd, [], [
        input_group.button(Xs, [], [html.text("Go")]),
      ]),
    ]),
  ])
}

// --- helpers -------------------------------------------------------------

fn aria_label(value: String) -> Attribute(msg) {
  attribute.attribute("aria-label", value)
}

fn center(children: List(Element(msg))) -> Element(msg) {
  html.div(
    [
      attribute.class(
        "flex min-h-24 w-full max-w-sm items-center justify-center "
        <> "text-foreground",
      ),
    ],
    children,
  )
}

fn column(children: List(Element(msg))) -> Element(msg) {
  html.div(
    [
      attribute.class(
        "flex min-h-24 w-full max-w-sm flex-col gap-4 text-foreground",
      ),
    ],
    children,
  )
}
