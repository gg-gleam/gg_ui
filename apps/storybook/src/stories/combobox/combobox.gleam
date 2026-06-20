//// Story mount for the styled `Combobox` — the kit's first *stateful* story, so
//// it runs a real `lustre.application` (Model/update/view), not `lustre.element`.
//// The host owns the combobox `Model` + `Anatomy` and threads the opaque `Msg`
//// through `combobox.update`. Icons aren't a consumer concern — the field's
//// chevron, the selected check, the clear ✕ and the chip ✕ are built into the
//// component from lucide — so the story passes no icons and ignores the icon
//// toolbar globals.
////
//// One app drives every story variant via `Flags`: single-select (the
//// playground), multiple-select with chips, a grouped list, and an async demo
//// whose button toggles the `role=status` loading announcement.

import gg_ui/positioning.{
  type Align, type Side, Bottom, Center, End, Left, Right, Start, Top,
}
import gg_ui/ui/button
import gg_ui/ui/combobox
import gg_ui/ui/text
import gleam/int
import gleam/list
import gleam/option
import gleam/string
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

type Variant {
  VSingle
  VMultiple
  VGrouped
  VGroupedMultiple
}

type Flags {
  Flags(
    side: Side,
    align: Align,
    clearable: Bool,
    variant: Variant,
    async: Bool,
  )
}

type Model {
  Model(
    cb: combobox.Model(String),
    anatomy: combobox.Anatomy,
    flags: Flags,
    loading: Bool,
  )
}

type Msg {
  ComboboxMsg(combobox.Msg)
  ToggleLoading
}

fn item(label: String) -> combobox.Item(String) {
  combobox.Item(value: label, label:, disabled: False)
}

fn frameworks() -> List(combobox.Item(String)) {
  list.map(
    [
      "Next.js",
      "SvelteKit",
      "Nuxt",
      "Remix",
      "Astro",
      "Gleam Lustre",
      "Phoenix",
    ],
    item,
  )
}

fn framework_groups() -> List(combobox.Group(String)) {
  [
    combobox.Group(label: "React", items: list.map(["Next.js", "Remix"], item)),
    combobox.Group(label: "Vue", items: list.map(["Nuxt"], item)),
    combobox.Group(label: "Svelte", items: list.map(["SvelteKit"], item)),
    combobox.Group(
      label: "Other",
      items: list.map(["Astro", "Gleam Lustre", "Phoenix"], item),
    ),
  ]
}

fn init(flags: Flags) -> #(Model, Effect(Msg)) {
  let anatomy = combobox.anatomy_with_id("combobox-story")
  let config = case flags.variant {
    VMultiple | VGroupedMultiple ->
      combobox.Config(
        loop: True,
        auto_highlight: False,
        mode: combobox.Multiple,
      )
    _ -> combobox.config()
  }
  let cb = case flags.variant {
    VGrouped | VGroupedMultiple ->
      combobox.init_grouped(framework_groups(), config)
    _ -> combobox.init(frameworks(), config)
  }
  #(Model(cb:, anatomy:, flags:, loading: False), effect.none())
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    ComboboxMsg(cb_msg) -> {
      let #(cb, eff) = combobox.update(model.anatomy, model.cb, cb_msg)
      #(Model(..model, cb:), effect.map(eff, ComboboxMsg))
    }
    ToggleLoading -> {
      let loading = !model.loading
      #(
        Model(..model, loading:, cb: combobox.set_loading(model.cb, loading)),
        effect.none(),
      )
    }
  }
}

fn view(model: Model) -> Element(Msg) {
  let widget = element.map(combobox_widget(model), ComboboxMsg)
  let toggle = case model.flags.async {
    True -> [async_toggle(model.loading)]
    False -> []
  }
  html.div(
    [
      // A *definite* width (`w-80`, = max-w-xs), not `w-full max-w-xs`: the story
      // uses Storybook's `layout: "centered"`, so the canvas is shrink-to-fit and
      // a percentage/max-width collapses to content width — which makes the
      // multiple-select field grow when the first chip appears (1 chip + input >
      // bare input). A fixed width gives the field's `w-full` something to fill,
      // so it stays put and chips wrap. shadcn's example sizes ComboboxChips the
      // same way at the call site (`w-full max-w-xs` inside a framed preview).
      attribute.class("flex min-h-72 w-80 flex-col gap-3 text-foreground"),
    ],
    list.flatten([[widget], toggle, [selected_line(model)]]),
  )
}

// Assemble the combobox from parts (the composition API, shadcn-style): the field
// + a popup holding the empty announcer, an optional loading announcer, and the
// list (sectioned for the grouped variants, flat otherwise).
fn combobox_widget(model: Model) -> Element(combobox.Msg) {
  let a = model.anatomy
  let cb = model.cb
  let loading = case combobox.is_loading(cb) {
    True -> [
      combobox.loading([], [html.text("Loading frameworks…")]),
    ]
    False -> []
  }
  let body = case model.flags.variant {
    VGrouped | VGroupedMultiple ->
      combobox.groups(cb, fn(label, entries, gi) {
        combobox.group(
          a,
          gi,
          [],
          list.flatten([
            [combobox.label(a, gi, [], [html.text(label)])],
            list.map(entries, fn(e) { combobox.option(a, cb, e.0, e.1) }),
          ]),
        )
      })
    _ -> combobox.options(a, cb)
  }
  html.div([], [
    combobox.input(
      a,
      cb,
      placeholder: "Search framework…",
      clearable: model.flags.clearable,
      attrs: [],
    ),
    combobox.content(
      a,
      cb,
      side: model.flags.side,
      align: model.flags.align,
      attrs: [],
      children: list.flatten([
        loading,
        [combobox.empty([], [html.text("No framework found.")])],
        [combobox.list(a, cb, [], body)],
      ]),
    ),
  ])
}

// The async demo's control: flips the combobox's `role=status` loading state.
fn async_toggle(loading: Bool) -> Element(Msg) {
  let label = case loading {
    True -> "Stop loading"
    False -> "Simulate loading"
  }
  button.button(button.Outline, button.Sm, [event.on_click(ToggleLoading)], [
    html.text(label),
  ])
}

// Dogfood the kit (rule 6): the status line is our `text` component, not raw
// `text-sm text-muted-foreground`.
fn selected_line(model: Model) -> Element(Msg) {
  let label = case model.flags.variant {
    VMultiple | VGroupedMultiple ->
      case combobox.selected_values(model.cb) {
        [] -> "Nothing selected"
        values ->
          int.to_string(list.length(values))
          <> " selected: "
          <> string.join(values, ", ")
      }
    _ ->
      case combobox.selected(model.cb) {
        option.Some(value) -> "Selected: " <> value
        option.None -> "Nothing selected"
      }
  }
  text.s6([text.color(text.Muted)], [html.text(label)])
}

// --- mount ---------------------------------------------------------------

fn start(flags: Flags, selector: String) -> Nil {
  let assert Ok(_) =
    lustre.start(lustre.application(init, update, view), selector, flags)
  Nil
}

pub fn mount_combobox_playground(
  selector: String,
  side: String,
  align: String,
  clearable: Bool,
) -> Nil {
  start(
    Flags(parse_side(side), parse_align(align), clearable, VSingle, False),
    selector,
  )
}

pub fn mount_combobox_multiple(
  selector: String,
  side: String,
  align: String,
) -> Nil {
  start(
    Flags(parse_side(side), parse_align(align), True, VMultiple, False),
    selector,
  )
}

pub fn mount_combobox_grouped(
  selector: String,
  side: String,
  align: String,
) -> Nil {
  start(
    Flags(parse_side(side), parse_align(align), False, VGrouped, False),
    selector,
  )
}

pub fn mount_combobox_grouped_multiple(
  selector: String,
  side: String,
  align: String,
) -> Nil {
  start(
    Flags(parse_side(side), parse_align(align), False, VGroupedMultiple, False),
    selector,
  )
}

pub fn mount_combobox_async(
  selector: String,
  side: String,
  align: String,
) -> Nil {
  start(
    Flags(parse_side(side), parse_align(align), False, VSingle, True),
    selector,
  )
}

fn parse_side(side: String) -> Side {
  case side {
    "top" -> Top
    "right" -> Right
    "left" -> Left
    _ -> Bottom
  }
}

fn parse_align(align: String) -> Align {
  case align {
    "center" -> Center
    "end" -> End
    _ -> Start
  }
}
