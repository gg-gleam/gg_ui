//// Story mount for the styled `Combobox` — the kit's first *stateful* story, so
//// it runs a real `lustre.application` (Model/update/view), not `lustre.element`.
//// The host owns the combobox `Model` + `Anatomy` and threads the opaque `Msg`
//// through `combobox.update`. Icons aren't a consumer concern — the field's
//// chevron, the selected check and the clear ✕ are built into the component from
//// lucide — so the story passes no icons and ignores the icon toolbar globals.

import gg_ui/positioning.{
  type Align, type Side, Bottom, Center, End, Left, Right, Start, Top,
}
import gg_ui/ui/combobox
import gg_ui/ui/text
import gleam/option.{None, Some}
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html

type Flags {
  Flags(side: Side, align: Align, clearable: Bool)
}

type Model {
  Model(cb: combobox.Model(String), anatomy: combobox.Anatomy, flags: Flags)
}

type Msg {
  ComboboxMsg(combobox.Msg)
}

fn frameworks() -> List(combobox.Item(String)) {
  build_items([
    "Next.js", "SvelteKit", "Nuxt", "Remix", "Astro", "Gleam Lustre", "Phoenix",
  ])
}

fn build_items(labels: List(String)) -> List(combobox.Item(String)) {
  case labels {
    [] -> []
    [label, ..rest] -> [
      combobox.Item(value: label, label:, disabled: False),
      ..build_items(rest)
    ]
  }
}

fn init(flags: Flags) -> #(Model, Effect(Msg)) {
  let anatomy = combobox.anatomy_with_id("combobox-playground")
  #(
    Model(cb: combobox.init(frameworks(), combobox.config()), anatomy:, flags:),
    effect.none(),
  )
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    ComboboxMsg(cb_msg) -> {
      let #(cb, eff) = combobox.update(model.anatomy, model.cb, cb_msg)
      #(Model(..model, cb:), effect.map(eff, ComboboxMsg))
    }
  }
}

fn view(model: Model) -> Element(Msg) {
  let widget =
    combobox.combobox(
      anatomy: model.anatomy,
      model: model.cb,
      placeholder: "Search framework…",
      side: model.flags.side,
      align: model.flags.align,
      clearable: model.flags.clearable,
      empty_label: "No framework found.",
    )
  html.div(
    [
      attribute.class(
        "flex min-h-72 w-full max-w-xs flex-col gap-3 text-foreground",
      ),
    ],
    [element.map(widget, ComboboxMsg), selected_line(model.cb)],
  )
}

fn selected_line(cb: combobox.Model(String)) -> Element(Msg) {
  let label = case combobox.selected(cb) {
    Some(value) -> "Selected: " <> value
    None -> "Nothing selected"
  }
  // Dogfood the kit (rule 6): the label is our `text` component, not raw
  // `text-sm text-muted-foreground`. s6 is the body size (normal weight) — s1–s5
  // bake in semibold (heading tier). NB: the scale has no small-normal token
  // (s7 is text-sm but font-medium), a gap dogfooding surfaced.
  text.s6([text.color(text.Muted)], [html.text(label)])
}

// --- mount ---------------------------------------------------------------

pub fn mount_combobox_playground(
  selector: String,
  side: String,
  align: String,
  clearable: Bool,
) -> Nil {
  let flags =
    Flags(side: parse_side(side), align: parse_align(align), clearable:)
  let assert Ok(_) =
    lustre.start(lustre.application(init, update, view), selector, flags)
  Nil
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
