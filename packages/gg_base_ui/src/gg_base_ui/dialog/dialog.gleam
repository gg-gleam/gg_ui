//// Headless modal dialog, native-first — a Lustre port of Base UI's `Dialog.*`
//// anatomy, built on the platform `<dialog>` element instead of a JS runtime.
////
//// Base UI exposes the dialog as composable parts (`Root`, `Trigger`,
//// `Backdrop`, `Portal`, `Popup`, `Title`, `Description`, `Close`). We mirror
//// that surface, but the native `<dialog>` opened with `showModal()` already
//// gives us — for free, with no JS state machine — everything Base UI builds by
//// hand:
////
//// - **Focus trap + focus restore.** `showModal()` traps Tab focus inside the
////   dialog and restores focus to the previously-focused element (usually the
////   trigger) on close. No `FocusGuard`s, no focus manager.
//// - **Top layer + inert background.** The modal dialog renders in the [top
////   layer](https://developer.mozilla.org/en-US/docs/Glossary/Top_layer)
////   (escaping `overflow`/`transform` clipping — so Base UI's `Portal` is
////   unnecessary) and makes everything behind it inert (unfocusable,
////   unclickable). So Base UI's `Backdrop` part collapses into the native
////   `::backdrop` pseudo-element, styled in CSS — there is no backdrop element
////   to render.
//// - **`aria-modal` + role.** A modally-open `<dialog>` exposes
////   `role="dialog"` + `aria-modal="true"` to assistive tech natively. We only
////   emit `role="alertdialog"` ourselves when the caller asks for the alert
////   variant.
//// - **Close requests (Escape / platform back).** Modal dialogs honour Escape
////   and platform dismiss gestures natively, dispatching a `cancel` then a
////   `close` event.
////
//// What the platform doesn't do declaratively, native primitives still cover:
////
//// - **Trigger + Close use [Invoker
////   Commands](https://developer.mozilla.org/en-US/docs/Web/API/Invoker_Commands_API)**:
////   `command="show-modal"` + `commandfor` opens the dialog as a modal,
////   `command="close"` closes it. No click handler in Gleam-land. (Safari
////   ≤26.1 has `<dialog>` but not Invoker Commands, so `trigger_attributes`
////   installs a tiny polyfill — see `dialog_ffi.ts`.)
//// - **Light-dismiss** (click the backdrop to close) is the native
////   [`closedby`](https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/dialog#closedby)
////   attribute (`Dismiss`). `closedby` isn't in Safari yet, so the same FFI
////   shim adds a backdrop-click fallback there.
//// - **Visual open/closed styling** comes from the native `[open]` attribute /
////   `:modal` pseudo-class — no `data-open`/`data-closed` mirror to keep in
////   sync. Scroll-lock is pure CSS (`:root:has(dialog:modal)`).
////
//// Two *optional, orthogonal* capabilities layer on top, exactly like popover:
////
//// - **observe** — pass `on_close: Some(f)` to `popup` to learn when the dialog
////   closes (Escape, light-dismiss, a `close` button, or the `close` effect),
////   from the native `close` event. `None` wires no handler.
//// - **command** — `open` / `close` return `Effect`s keyed by the handle's
////   content id, so you can drive the dialog from `update`, an async task, or an
////   external (non-trigger) button. No host state required.
////
//// **Universal.** The whole declarative structure renders as plain markup on the
//// BEAM; the client-only glue (the polyfills, `showModal`/`close`) lives behind
//// the FFI boundary with Gleam fallback bodies that never run server-side.

import gg_base_ui/helpers/id_gen/id_gen
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute.{type Attribute}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

// --- Anatomy -------------------------------------------------------------

/// Stable IDs the parts share — the dialog's content id (the `commandfor`
/// target and what `aria-controls` points at), and the title / description ids
/// the popup's `aria-labelledby` / `aria-describedby` reference. All derived
/// from one base.
///
/// **Construct once and reuse** — generate in `init` and keep it in your model,
/// or once at the top of a render-once static view, then thread it through the
/// parts. Do **not** call `anatomy()` inside a re-rendering `view`: it mints a
/// fresh base each call (see `id_gen`), which would change the ids out from
/// under the `commandfor` link they wire.
pub type Anatomy {
  Anatomy(content_id: String, title_id: String, description_id: String)
}

/// Build an `Anatomy` with a freshly-generated, collision-free base id — the
/// default. Callers never invent or expose an id, so two dialogs on the same
/// page can't clash. The `useId` analogue (see
/// `gg_base_ui/helpers/id_gen/id_gen`): call **once** per dialog and reuse the
/// result; never recompute it per render.
pub fn anatomy() -> Anatomy {
  anatomy_with_id(id_gen.generate_with_prefix("dialog"))
}

/// Build an `Anatomy` from an explicit, caller-chosen base id. Escape hatch for
/// when the id must be deterministic — tests, or pinning ids across a
/// server/client render boundary. Prefer `anatomy()` otherwise so ids stay an
/// internal detail. The caller owns uniqueness. Safe to call in `view` *and*
/// `update` (it's a pure id derivation).
pub fn anatomy_with_id(id: String) -> Anatomy {
  Anatomy(
    content_id: id <> "-content",
    title_id: id <> "-title",
    description_id: id <> "-description",
  )
}

// --- Dismiss -------------------------------------------------------------

/// How the dialog may be dismissed, mapping to the native `closedby` attribute:
///
/// - `LightDismiss` (`closedby="any"`): clicking the backdrop **or** a close
///   request (Escape / platform back) closes it. The friendly default for
///   non-destructive dialogs.
/// - `CloseRequest` (`closedby="closerequest"`): close requests only — Escape /
///   platform back, but *not* an outside click. This is the platform's own
///   default for modal dialogs; pick it when an accidental backdrop click
///   shouldn't discard the dialog.
/// - `Manual` (`closedby="none"`): neither backdrop click nor Escape closes it;
///   the host fully owns close (via the `close` effect or a `close` button).
///   Reserve for flows that must not be dismissed out from under the user.
///
/// `closedby` is not yet in Safari; `LightDismiss` degrades there via the FFI
/// backdrop-click shim, and Escape always works on a modal dialog regardless.
pub type Dismiss {
  LightDismiss
  CloseRequest
  Manual
}

fn dismiss_to_string(dismiss: Dismiss) -> String {
  case dismiss {
    LightDismiss -> "any"
    CloseRequest -> "closerequest"
    Manual -> "none"
  }
}

// --- Role ----------------------------------------------------------------

/// The dialog's ARIA role. `Dialog` keeps the native `<dialog>` role (so we set
/// nothing); `Alert` overrides it to `alertdialog`, the role for a dialog that
/// interrupts to confirm a consequential action and expects an immediate
/// response (and which assistive tech treats more assertively).
pub type Role {
  Dialog
  Alert
}

fn role_attributes(role: Role) -> List(Attribute(msg)) {
  case role {
    Dialog -> []
    Alert -> [attribute.attribute("role", "alertdialog")]
  }
}

// --- Trigger -------------------------------------------------------------

/// Declarative trigger attributes — Base UI's `render` prop in Gleam form.
/// Merge onto a `<button>` (or a styled `Button`) to turn it into the dialog
/// trigger; button-only because the native Invoker Command association requires
/// a `<button>`. The headless layer never renders the button itself.
///
/// Uses [Invoker Commands](https://developer.mozilla.org/en-US/docs/Web/API/Invoker_Commands_API):
/// `command="show-modal"` + `commandfor` opens the dialog modally (top layer,
/// focus trap, backdrop) with no JS. `aria-haspopup="dialog"` and
/// `aria-controls` wire the disclosure relationship; the `aria-expanded="false"`
/// is a static SSR seed — once open, screen readers read the live disclosure
/// state from the accessibility tree (the polyfill mirrors the DOM attribute on
/// Safari).
pub fn trigger_attributes(anatomy: Anatomy) -> List(Attribute(msg)) {
  let Nil = ensure_dialog_polyfill()
  [
    attribute.attribute("command", "show-modal"),
    attribute.attribute("commandfor", anatomy.content_id),
    attribute.attribute("aria-haspopup", "dialog"),
    attribute.attribute("aria-controls", anatomy.content_id),
    attribute.attribute("aria-expanded", "false"),
  ]
}

// --- Popup ---------------------------------------------------------------

/// The modal popup — a native `<dialog>`. **Always rendered** in the DOM: the
/// UA stylesheet hides it (`display: none`) until it's shown, and the platform
/// promotes it to the top layer on open. Keeping it mounted means (a) SSR
/// round-trips the whole structure and (b) we need no JS mount/unmount state
/// machine, matching popover.
///
/// `dismiss` chooses the `closedby` policy; `role` picks `dialog` vs
/// `alertdialog`. `on_close` is the optional **observe** capability: `Some(f)`
/// wires the native `close` event so the host learns of *every* close path
/// (Escape, light-dismiss, a close button, the `close` effect); `None` keeps
/// the dialog purely declarative.
///
/// Label/describe it by including `labelled_by` / `described_by` in `attrs`
/// alongside a `title` / `description` child.
pub fn popup(
  anatomy: Anatomy,
  dismiss: Dismiss,
  role: Role,
  on_close: Option(fn() -> msg),
  attrs: List(Attribute(msg)),
  children: List(Element(msg)),
) -> Element(msg) {
  let close_handler = case on_close {
    None -> []
    Some(handler) -> [event.on("close", decode.success(handler()))]
  }
  html.dialog(
    list.flatten([
      [
        attribute.id(anatomy.content_id),
        attribute.attribute("closedby", dismiss_to_string(dismiss)),
      ],
      role_attributes(role),
      close_handler,
      attrs,
    ]),
    children,
  )
}

/// Point a popup's `aria-labelledby` at its `title`. Add to `popup`'s attrs.
pub fn labelled_by(anatomy: Anatomy) -> Attribute(msg) {
  attribute.attribute("aria-labelledby", anatomy.title_id)
}

/// Point a popup's `aria-describedby` at its `description`. Add to `popup`'s
/// attrs.
pub fn described_by(anatomy: Anatomy) -> Attribute(msg) {
  attribute.attribute("aria-describedby", anatomy.description_id)
}

// --- Title / Description / Close ------------------------------------------

/// Accessible heading for the dialog. Renders `<h2>` with the id `labelled_by`
/// references.
pub fn title(
  anatomy: Anatomy,
  attrs: List(Attribute(msg)),
  children: List(Element(msg)),
) -> Element(msg) {
  html.h2([attribute.id(anatomy.title_id), ..attrs], children)
}

/// Supplementary text. Renders `<p>` with the id `described_by` references.
pub fn description(
  anatomy: Anatomy,
  attrs: List(Attribute(msg)),
  children: List(Element(msg)),
) -> Element(msg) {
  html.p([attribute.id(anatomy.description_id), ..attrs], children)
}

/// Attributes for a button that closes the dialog natively via the
/// `command="close"` Invoker Command — no JS, works inside the declarative
/// flow. Merge onto a `<button>` (or a styled `Button`).
pub fn close_attributes(anatomy: Anatomy) -> List(Attribute(msg)) {
  [
    attribute.attribute("command", "close"),
    attribute.attribute("commandfor", anatomy.content_id),
  ]
}

// --- Command capability --------------------------------------------------
//
// Drive any dialog imperatively, keyed by its content id. Works regardless of
// whether the host observes state — handy for opening from `update`, an async
// task, or an external (non-trigger) button. JS-only; the Erlang fallbacks
// never run because effects execute client-side.

@external(javascript, "./dialog_ffi.ts", "showModal")
fn show_modal(_content_id: String) -> Nil {
  Nil
}

@external(javascript, "./dialog_ffi.ts", "closeDialog")
fn close_dialog(_content_id: String) -> Nil {
  Nil
}

// Idempotent install of the dialog Invoker-Commands + `closedby` light-dismiss
// polyfills — a no-op where the native APIs exist (Chrome/Firefox) and on the
// BEAM. `trigger_attributes` calls it so the declarative trigger still works on
// Safari.
@external(javascript, "./dialog_ffi.ts", "ensureDialogPolyfill")
fn ensure_dialog_polyfill() -> Nil {
  Nil
}

/// Open the dialog modally (top layer, focus trap, backdrop). No-op if it's
/// already open.
pub fn open(anatomy: Anatomy) -> Effect(msg) {
  effect.from(fn(_dispatch) { show_modal(anatomy.content_id) })
}

/// Close the dialog. No-op if it's already closed.
pub fn close(anatomy: Anatomy) -> Effect(msg) {
  effect.from(fn(_dispatch) { close_dialog(anatomy.content_id) })
}
