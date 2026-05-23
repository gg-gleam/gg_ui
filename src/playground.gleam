//// Dev playground entry: a tiny Lustre app that mounts the styled popover so
//// it can be exercised in a real browser via `pnpm dev`. Compiled to JS and
//// imported by `playground/main.ts`. Not part of the library's public API.

import gg_ui/popover
import gg_ui/popover/positioning
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
  UserToggledPopover
  PopoverDismissed
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
  case msg {
    UserToggledPopover -> {
      let pop = popover.update(model.pop, popover.Toggled)
      #(
        Model(pop:),
        positioning.sync(pop, popover.BottomStart, PopoverDismissed),
      )
    }
    PopoverDismissed -> {
      let pop = popover.update(model.pop, popover.DismissRequested)
      #(
        Model(pop:),
        positioning.sync(pop, popover.BottomStart, PopoverDismissed),
      )
    }
  }
}

fn view(model: Model) -> Element(Msg) {
  html.div(
    [
      attribute.class(
        "flex min-h-dvh items-center justify-center gap-4 bg-background "
        <> "text-foreground",
      ),
    ],
    [
      styled.trigger(model.pop, UserToggledPopover, "Open popover"),
      styled.panel(model.pop, [
        html.p([attribute.class("text-sm font-medium")], [
          html.text("A Floating-UI-positioned popover."),
        ]),
        html.p([attribute.class("mt-1 text-xs text-muted-foreground")], [
          html.text("Click outside or press Escape to dismiss."),
        ]),
      ]),
    ],
  )
}
