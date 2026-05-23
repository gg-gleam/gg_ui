//// Story mounts for the popover, one `mount_*` per variant. Stories don't
//// share state — each call starts a fresh Lustre runtime against the canvas
//// element Storybook just created. Wired up from
//// `src/gg_ui/core/popover.stories.ts` via the `.storybook/lustre-mount.ts`
//// helper.

import gg_ui/core/popover
import gg_ui/core/positioning.{Bottom, Placement, Start}
import gg_ui/styled/popover as styled
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html

type Model {
  Model(pop: popover.State)
}

type Msg {
  PopoverToggled(Bool)
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
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

// --- mounts --------------------------------------------------------------

pub fn mount_basic(selector: String) -> Nil {
  mount(selector, "story-basic", view_basic)
}

pub fn mount_clipping(selector: String) -> Nil {
  mount(selector, "story-clipping", view_clipping)
}

fn mount(
  selector: String,
  id: String,
  view_fn: fn(Model) -> Element(Msg),
) -> Nil {
  let init_fn = fn(_flags) { #(Model(pop: popover.init(id)), effect.none()) }
  let app = lustre.application(init_fn, update, view_fn)
  let assert Ok(_) = lustre.start(app, selector, Nil)
  Nil
}

// --- views ---------------------------------------------------------------

fn view_basic(model: Model) -> Element(Msg) {
  html.div([attribute.class("text-foreground")], [
    styled.trigger(model.pop, "Open popover"),
    styled.panel(model.pop, Placement(Bottom, Start), PopoverToggled, [
      html.p([attribute.class("text-sm font-medium")], [
        html.text("A top-layer popover."),
      ]),
      html.p([attribute.class("mt-1 text-xs text-muted-foreground")], [
        html.text("Click outside or press Escape to dismiss."),
      ]),
    ]),
  ])
}

/// Hostile wrapper to prove the popover escapes a clipping ancestor:
/// `overflow: hidden` *and* `transform` — the combo that would normally trap
/// a `position: fixed` descendant.
fn view_clipping(model: Model) -> Element(Msg) {
  html.div(
    [
      attribute.class(
        "h-24 w-64 overflow-hidden rounded-lg border border-border p-4 "
        <> "text-foreground",
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
          html.text("Top layer escapes the clip."),
        ]),
      ]),
    ],
  )
}
