//// Dev playground entry: a tiny Lustre app that mounts the styled popover.
//// The trigger sits inside a deliberately hostile box — `overflow: hidden`
//// *and* a `transform` (which makes it the containing block for fixed
//// descendants) — to prove the popover escapes the clip via the top layer.
//// Compiled to JS and imported by `playground/main.ts`.

import gg_ui/core/popover
import gg_ui/core/positioning.{Bottom, Placement, Start}
import gg_ui/styled/popover as styled
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html

pub type Model {
  Model(pop: popover.State)
}

pub type Msg {
  PopoverToggled(Bool)
}

pub fn main() -> Nil {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}

fn init(_flags) -> #(Model, Effect(Msg)) {
  #(Model(pop: popover.init("demo")), effect.none())
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  // Declarative popover: the browser owns open/close; we just mirror it.
  case msg {
    PopoverToggled(open) -> #(
      Model(
        pop: popover.update(model.pop, case open {
          True -> popover.Opened
          False -> popover.Closed
        }),
      ),
      effect.none(),
    )
  }
}

fn view(model: Model) -> Element(Msg) {
  html.div(
    [
      attribute.class(
        "grid min-h-dvh place-items-center bg-background text-foreground",
      ),
    ],
    [
      html.div(
        [
          // The clip trap: overflow-hidden + transform. A non-top-layer
          // element would be cropped to this 16rem × 6rem box.
          attribute.class(
            "h-24 w-64 overflow-hidden rounded-lg border border-border p-4",
          ),
          attribute.styles([#("transform", "translateZ(0)")]),
        ],
        [
          html.p([attribute.class("mb-2 text-xs text-muted-foreground")], [
            html.text("Clipping box (overflow-hidden + transform)"),
          ]),
          styled.trigger(model.pop, "Open popover"),
          styled.panel(model.pop, Placement(Bottom, Start), PopoverToggled, [
            html.p([attribute.class("text-sm font-medium")], [
              html.text("Top-layer popover — escapes the clip."),
            ]),
            html.p([attribute.class("mt-1 text-xs text-muted-foreground")], [
              html.text("Click outside or press Escape to dismiss."),
            ]),
          ]),
        ],
      ),
    ],
  )
}
