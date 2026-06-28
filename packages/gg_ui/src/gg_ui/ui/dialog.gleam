//// shadcn-flavoured modal dialog — the **thin** styled layer built on the
//// headless `gg_base_ui/dialog`. Mirrors shadcn's authoring model: this layer
//// emits *class names* (`cn-dialog`, `cn-dialog-header`, …) whose Tailwind
//// recipes live in the per-style CSS (`styles/shapes/<style>/dialog.css`); the
//// backdrop fade, dialog enter/exit, and scroll-lock live in the shared motion
//// layer (`styles/motion/dialog.css`). This is the layer a future CLI copies
//// into a consuming app.
////
//// Mirrors shadcn's parts: `trigger` (an outline `Button`), `content` (the
//// native `<dialog>` box — focus-trapped, labelled, with a `::backdrop`),
//// `header`, `footer`, `title`, `description`, and `close`. For the common case
//// there's also a terse `dialog` that hides the anatomy/aria plumbing and only
//// asks for the trigger + content children (shadcn's `<Dialog>` feel), baking in
//// the corner ✕ close.
////
//// **`gg_base_ui` is a true internal dependency — it never appears in this
//// module's public API.** Consumers name only gg_ui types: `Anatomy` (a thin
//// re-export of the headless handle, which you never construct directly),
//// `Dismiss` and `Role` (gg_ui's own enums, mapped to the headless ones
//// internally). The `anatomy` / `show` / `hide` wrappers re-expose the headless
//// capabilities under gg_ui's name. This keeps the styled surface stable even if
//// the headless layer is restructured — and matches how `button` owns its own
//// `Variant` / `Size`.
////
//// Native-first behavior is preserved verbatim: the `<dialog>` element, its
//// `showModal()` focus trap / top layer / `::backdrop`, the native `[open]`
//// visual state, and `closedby` light-dismiss are *behavior*, not looks — they
//// stay here and in the headless layer, not in the CSS. Only pure-visual
//// utilities move to `cn-*` class names.

import gg_base_ui/dialog/dialog as base_dialog
import gg_icon/icon
import gg_icons_lucide/lucide/x as lu_x
import gg_ui/ui/button
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html

// --- Anatomy + capabilities (facade over the headless handle) ------------
//
// gg_base_ui stays internal: callers obtain an `Anatomy` from `anatomy` /
// `anatomy_with_id` (or the terse `dialog`'s children callback) and drive the
// dialog with the `show` / `hide` effects — all named under gg_ui.

/// The dialog handle: the stable set of ids the parts share (content, title,
/// description). A re-export of the headless type — you never construct it
/// directly; you get one from `anatomy` / `anatomy_with_id` or the terse
/// `dialog` children callback, then thread it through `trigger` / `content` /
/// `title` / `description` / `close`.
pub type Anatomy =
  base_dialog.Anatomy

/// Build an `Anatomy` with a freshly-generated, collision-free id — the
/// default. Call **once** per dialog and reuse the result (the `useId`
/// analogue); never recompute it per render, or the ids wiring the parts would
/// change out from under each other.
pub fn anatomy() -> Anatomy {
  base_dialog.anatomy()
}

/// Build an `Anatomy` from an explicit, caller-chosen base id. Escape hatch for
/// when the id must be deterministic (tests, or pinning across a server/client
/// render boundary). Prefer `anatomy` otherwise; the caller owns uniqueness.
/// Safe to call in both `view` and `update` (it's a pure id derivation).
pub fn anatomy_with_id(id: String) -> Anatomy {
  base_dialog.anatomy_with_id(id)
}

/// How the dialog may be dismissed. `LightDismiss` closes on a backdrop click
/// **or** Escape (the friendly default); `CloseRequest` closes on Escape /
/// platform back only (an accidental backdrop click won't discard it); `Manual`
/// hands full control of close to the host. Mapped to the headless `Dismiss`
/// internally.
pub type Dismiss {
  LightDismiss
  CloseRequest
  Manual
}

fn dismiss_to_base(dismiss: Dismiss) -> base_dialog.Dismiss {
  case dismiss {
    LightDismiss -> base_dialog.LightDismiss
    CloseRequest -> base_dialog.CloseRequest
    Manual -> base_dialog.Manual
  }
}

/// The dialog's ARIA role. `Standard` keeps the native `<dialog>` role;
/// `AlertDialog` upgrades it to `alertdialog` — for a dialog that interrupts to
/// confirm a consequential action (assistive tech treats it more assertively).
/// Mapped to the headless `Role` internally.
pub type Role {
  Standard
  AlertDialog
}

fn role_to_base(role: Role) -> base_dialog.Role {
  case role {
    Standard -> base_dialog.Dialog
    AlertDialog -> base_dialog.Alert
  }
}

/// Open the dialog imperatively (the **command** capability), keyed by the
/// handle. No-op if already open. Drive it from `update`, an async task, or an
/// external (non-trigger) button — no host state required. (Named after the
/// native `showModal`; distinct from the `close` *button* part below.)
pub fn show(anatomy: Anatomy) -> Effect(msg) {
  base_dialog.open(anatomy)
}

/// Close the dialog imperatively. No-op if already closed. (Native `close()`.)
pub fn hide(anatomy: Anatomy) -> Effect(msg) {
  base_dialog.close(anatomy)
}

// --- Parts ---------------------------------------------------------------

/// shadcn's `<DialogTrigger render={<Button />}>`: the trigger's *behavior*
/// merged onto a `Button` that owns the *appearance*. You pass the `variant` /
/// `size` (shadcn defaults the trigger to outline/medium — pass `button.Outline`
/// / `button.Medium` for that look). The native Invoker Command
/// (`command="show-modal"`) opens the dialog modally — no host state.
pub fn trigger(
  anatomy: Anatomy,
  variant variant: button.Variant,
  size size: button.Size,
  attrs attrs: List(attribute.Attribute(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  // User attrs first, behaviour attrs last so the Invoker Command + aria wiring
  // always wins a conflict; a caller `class` is merged by `button` itself.
  button.button(
    variant:,
    size:,
    attrs: list.append(attrs, base_dialog.trigger_attributes(anatomy)),
    children:,
  )
}

/// The trigger's headless behaviour attributes (Invoker Command + aria) to merge
/// onto **your own** element — Base UI's `render` prop in Gleam form. Reach for
/// this only when you don't want the styled `Button`:
/// `html.button([..dialog.trigger_attributes(d)], [html.text("Open")])`. For the
/// common styled trigger, use `trigger`.
pub fn trigger_attributes(anatomy: Anatomy) -> List(attribute.Attribute(msg)) {
  base_dialog.trigger_attributes(anatomy)
}

/// `DialogContent`: the modal popup box — a native `<dialog>` that the platform
/// focus-traps, renders in the top layer, and dims behind with a `::backdrop`.
/// `dismiss` picks the `closedby` policy (`LightDismiss` / `CloseRequest` /
/// `Manual`); `role` picks `Standard` vs `AlertDialog`. `on_close` is the
/// optional **observe** capability — `Some(f)` fires `f` on *every* close path
/// (Escape, backdrop, a close button, the `hide` effect); `None` keeps the
/// dialog purely declarative.
///
/// Wires `aria-labelledby` / `aria-describedby` (resolved by id), so include a
/// `title` — and usually a `description` — among the children.
///
/// `attrs` are merged onto the `<dialog>` after the base wiring — shadcn's
/// `className` escape hatch in Gleam form (e.g. `attribute.class("sm:max-w-md")`
/// to widen it, or `attribute.attribute("dir", "rtl")`). Pass `[]` for the
/// default. Extra `class` attributes concatenate with `cn-dialog`.
///
/// **Structure:** when present, the children are wrapped once in an inner
/// `<div class="cn-dialog-content">`. The native `<dialog>` (`cn-dialog`) is a
/// bare positioning + top-layer shell; the inner div carries shadcn's actual
/// `DialogContent` recipe (the `grid` layout, padding, surface). This split
/// works around a Safari bug: WebKit distorts the size of a top-layer
/// `<dialog>`, which mis-sizes a `grid`/`flex-row` footer to the dialog's
/// border-box. Doing the layout on a *normal* inner `<div>` sizes it to the
/// padded content-box correctly, in every browser, with no feature detection.
pub fn content(
  anatomy: Anatomy,
  dismiss dismiss: Dismiss,
  role role: Role,
  on_close on_close: Option(fn() -> msg),
  attrs attrs: List(attribute.Attribute(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  // Wrap the children in the inner panel only when there *are* children: a
  // host-controlled dialog that mounts its body lazily passes `[]` while closed
  // (see the Lazy Content story), and an empty `.cn-dialog-content` wrapper
  // would defeat that "closed shell is empty" contract.
  let body = case children {
    [] -> []
    _ -> [html.div([attribute.class("cn-dialog-content")], children)]
  }
  base_dialog.popup(
    anatomy,
    dismiss_to_base(dismiss),
    role_to_base(role),
    on_close,
    [
      attribute.class("cn-dialog"),
      base_dialog.labelled_by(anatomy),
      base_dialog.described_by(anatomy),
      ..attrs
    ],
    body,
  )
}

/// `DialogHeader`: stacks a title and description with tight spacing (centered
/// on narrow viewports, leading-aligned from `sm` up, matching shadcn). `attrs`
/// merge onto the wrapper (pass `[]` for the default).
pub fn header(
  attrs: List(attribute.Attribute(msg)),
  children: List(Element(msg)),
) -> Element(msg) {
  html.div([attribute.class("cn-dialog-header"), ..attrs], children)
}

/// `DialogFooter`: the action row — stacked + reversed on narrow viewports,
/// right-aligned in a row from `sm` up (shadcn's footer recipe). `attrs` merge
/// onto the wrapper (e.g. `attribute.class("sm:justify-start")`); pass `[]` for
/// the default.
pub fn footer(
  attrs: List(attribute.Attribute(msg)),
  children: List(Element(msg)),
) -> Element(msg) {
  html.div([attribute.class("cn-dialog-footer"), ..attrs], children)
}

/// `DialogTitle`: the accessible heading the content is labelled by.
pub fn title(anatomy: Anatomy, children: List(Element(msg))) -> Element(msg) {
  base_dialog.title(anatomy, [attribute.class("cn-dialog-title")], children)
}

/// `DialogDescription`: muted supplementary text the content is described by.
pub fn description(
  anatomy: Anatomy,
  children: List(Element(msg)),
) -> Element(msg) {
  base_dialog.description(
    anatomy,
    [attribute.class("cn-dialog-description")],
    children,
  )
}

/// `DialogClose`: a button that closes the dialog natively via the
/// `command="close"` Invoker Command — no JS, works inside the declarative flow.
/// Defaults to an outline `Button` (shadcn's "Cancel" footer action feel); for
/// the in-corner ✕ use `close_icon` instead.
pub fn close(
  anatomy: Anatomy,
  variant variant: button.Variant,
  size size: button.Size,
  attrs attrs: List(attribute.Attribute(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  button.button(
    variant:,
    size:,
    attrs: list.append(attrs, base_dialog.close_attributes(anatomy)),
    children:,
  )
}

/// The corner ✕ close button (shadcn's built-in `DialogContent` close): an
/// icon-only ghost `Button` pinned top-right (`cn-dialog-close`) that closes via
/// the `command="close"` Invoker Command. The lucide `x` glyph is decorative
/// (`aria-hidden`), so an `aria-label="Close"` names the button.
pub fn close_icon(anatomy: Anatomy) -> Element(msg) {
  button.button(
    variant: button.Ghost,
    size: button.IconSm,
    attrs: [
      attribute.class("cn-dialog-close"),
      attribute.attribute("aria-label", "Close"),
      ..base_dialog.close_attributes(anatomy)
    ],
    children: [lu_x.x([icon.size(icon.Sm)])],
  )
}

// --- Terse API -----------------------------------------------------------
//
// The composable parts above mirror Base UI: you mint an `Anatomy` and thread it
// through `trigger`/`content`/… yourself, for full control. The terse `dialog`
// below is the shadcn-`<Dialog>`-style convenience for the common case — it
// hides the mechanics (anatomy generation, the `<dialog>` box, aria, the corner
// ✕) so the call site only decides the trigger and the content children. Reach
// for the parts when you need anything the slots don't cover.

/// Everything the terse `dialog` lets you tune, with sensible defaults from
/// `options`. Pass `options: dialog.options()` for the common case, or override
/// **only** what you need with Gleam's record-update syntax:
///
/// ```gleam
/// dialog.options()                                       // all defaults
/// Options(..dialog.options(), text: "Edit profile")      // just the trigger label
/// Options(..dialog.options(), role: AlertDialog, dismiss: CloseRequest)
/// ```
///
/// **Trigger** (used by `dialog`; ignored by `dialog_with_trigger`, where you
/// bring your own element):
/// - `text`: the trigger button's label.
/// - `variant` / `size`: the trigger button's look (the `Button` enums).
///
/// **Popup**:
/// - `id`: `None` auto-generates a collision-free id (the default); `Some(id)`
///   pins it (tests, server/client render boundaries) — you own uniqueness.
/// - `dismiss`: `LightDismiss` / `CloseRequest` / `Manual`.
/// - `role`: `Standard` vs `AlertDialog`.
/// - `close_button`: render the built-in corner ✕ (off for an `AlertDialog`,
///   which should force an explicit choice).
/// - `on_close`: the **observe** capability — `Some(f)` fires on every close.
pub type Options(msg) {
  Options(
    id: Option(String),
    text: String,
    variant: button.Variant,
    size: button.Size,
    dismiss: Dismiss,
    role: Role,
    close_button: Bool,
    on_close: Option(fn() -> msg),
  )
}

/// The terse dialog's defaults: an outline/medium trigger labelled `"Open"`, an
/// auto-generated id, light-dismiss, the `Standard` role, the corner ✕ shown,
/// and no observe callback. Spread it with record-update to change a field —
/// `Options(..dialog.options(), text: "Edit profile")`.
pub fn options() -> Options(msg) {
  Options(
    id: None,
    text: "Open",
    variant: button.Outline,
    size: button.Medium,
    dismiss: LightDismiss,
    role: Standard,
    close_button: True,
    on_close: None,
  )
}

/// Terse dialog — the whole modal in one call, mechanics hidden. The shadcn
/// `<Dialog>` equivalent.
///
/// The trigger is the styled button described by `options` (`text` / `variant` /
/// `size`); `children` is a callback that receives the minted `Anatomy` so you
/// compose `title` / `description` / `footer` (which need the shared ids) and any
/// normal Lustre children. Pass `dialog.options()` for all-defaults, or spread
/// it to override only what you need — e.g. `Options(..dialog.options(), text:
/// "Edit profile")`.
///
/// Want a trigger that *isn't* the styled button (an icon button, a link, a
/// custom element)? Use `dialog_with_trigger` and pass your own. For full
/// structural control everywhere, drop to the composable parts.
pub fn dialog(
  options options: Options(msg),
  children children: fn(Anatomy) -> List(Element(msg)),
) -> Element(msg) {
  dialog_with_trigger(
    trigger: fn(anatomy) {
      trigger(
        anatomy,
        variant: options.variant,
        size: options.size,
        attrs: [],
        children: [html.text(options.text)],
      )
    },
    options:,
    children:,
  )
}

/// Terse dialog with a **caller-supplied trigger** — same as `dialog` but you
/// provide the trigger element via a callback that receives the minted
/// `Anatomy`. Build it with the standalone `trigger` (full button props) or your
/// own element via `trigger_attributes`. The `text` / `variant` / `size` fields
/// of `options` don't apply here — your trigger owns its appearance; the rest of
/// `options` (dismiss, role, corner ✕, observe, id) still does.
pub fn dialog_with_trigger(
  trigger trigger: fn(Anatomy) -> Element(msg),
  options options: Options(msg),
  children children: fn(Anatomy) -> List(Element(msg)),
) -> Element(msg) {
  let Options(id:, dismiss:, role:, close_button:, on_close:, ..) = options
  let anatomy = case id {
    Some(id) -> anatomy_with_id(id)
    None -> anatomy()
  }
  let corner = case close_button {
    True -> [close_icon(anatomy)]
    False -> []
  }
  element.fragment([
    trigger(anatomy),
    content(
      anatomy,
      dismiss:,
      role:,
      on_close:,
      attrs: [],
      children: list.append(children(anatomy), corner),
    ),
  ])
}
