import gg_ui/ui/button
import gg_ui/ui/dialog
import gleam/list
import gleam/option
import lustre
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

// --- mounts --------------------------------------------------------------
//
// No model, no msg, no update — the platform `<dialog>` owns open/closed via
// the native Invoker Commands (`command="show-modal"`/`"close"`). `lustre.element`
// is the right tool: a static view rendered once, no event loop in Gleam-land.

pub fn mount_dialog_playground(
  selector: String,
  text: String,
  dismiss: String,
  role: String,
  close_button: Bool,
  variant: String,
  size: String,
) -> Nil {
  mount_static(
    selector,
    view_playground(
      text,
      parse_dismiss(dismiss),
      parse_role(role),
      close_button,
      parse_variant(variant),
      parse_size(size),
    ),
  )
}

// --- shadcn doc examples (ui.shadcn.com/docs/components/dialog) -----------

pub fn mount_dialog_demo(selector: String) -> Nil {
  mount_static(selector, view_demo())
}

pub fn mount_dialog_close_button(selector: String) -> Nil {
  mount_static(selector, view_close_button())
}

pub fn mount_dialog_no_close_button(selector: String) -> Nil {
  mount_static(selector, view_no_close_button())
}

pub fn mount_dialog_sticky_footer(selector: String) -> Nil {
  mount_static(selector, view_sticky_footer())
}

pub fn mount_dialog_scrollable(selector: String) -> Nil {
  mount_static(selector, view_scrollable())
}

pub fn mount_dialog_rtl(selector: String) -> Nil {
  mount_static(selector, view_rtl())
}

fn mount_static(selector: String, view: Element(Nil)) -> Nil {
  let app = lustre.element(view)
  let assert Ok(_) = lustre.start(app, selector, Nil)
  Nil
}

// --- args ----------------------------------------------------------------

fn parse_dismiss(dismiss: String) -> dialog.Dismiss {
  case dismiss {
    "close-request" -> dialog.CloseRequest
    "manual" -> dialog.Manual
    _ -> dialog.LightDismiss
  }
}

fn parse_role(role: String) -> dialog.Role {
  case role {
    "alert" -> dialog.AlertDialog
    _ -> dialog.Standard
  }
}

fn parse_variant(variant: String) -> button.Variant {
  case variant {
    "destructive" -> button.Destructive
    "outline" -> button.Outline
    "secondary" -> button.Secondary
    "ghost" -> button.Ghost
    "link" -> button.Link
    _ -> button.Default
  }
}

fn parse_size(size: String) -> button.Size {
  case size {
    "xs" -> button.Xs
    "sm" -> button.Sm
    "lg" -> button.Lg
    "icon" -> button.Icon
    "icon-xs" -> button.IconXs
    "icon-sm" -> button.IconSm
    "icon-lg" -> button.IconLg
    _ -> button.Medium
  }
}

// --- shared story helpers -------------------------------------------------
//
// Input / Label / Field aren't part of the kit yet, so these stories use raw
// Tailwind for the form scaffolding (AGENTS.md rule 6: raw Tailwind only for the
// gaps the kit doesn't cover). Swap them for the real components once they land.

fn field(
  label label: String,
  id id: String,
  value value: String,
) -> Element(msg) {
  html.div([attribute.class("grid gap-2")], [
    html.label(
      [attribute.for(id), attribute.class("text-sm font-medium leading-none")],
      [html.text(label)],
    ),
    html.input([
      attribute.id(id),
      attribute.value(value),
      attribute.class(
        "h-9 w-full rounded-md border bg-transparent px-3 py-1 text-sm shadow-xs "
        <> "outline-none focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50",
      ),
    ]),
  ])
}

fn field_group(children: List(Element(msg))) -> Element(msg) {
  html.div([attribute.class("grid gap-4")], children)
}

const lorem = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur."

/// A `max-h-[50vh]` scroll region whose negative inline margin bleeds to the
/// content edges (shadcn's pattern); dogfoods the `no-scrollbar` utility.
fn lorem_body() -> Element(msg) {
  html.div(
    [
      // tabindex=0 keeps the scroll region keyboard-reachable (axe
      // `scrollable-region-focusable` / the modern-web HTML guidance).
      attribute.attribute("tabindex", "0"),
      attribute.attribute("role", "group"),
      attribute.class("no-scrollbar -mx-4 max-h-[50vh] overflow-y-auto px-4"),
    ],
    list.repeat(
      html.p([attribute.class("mb-4 leading-normal")], [html.text(lorem)]),
      8,
    ),
  )
}

fn page(children: List(Element(msg))) -> Element(msg) {
  html.div([attribute.class("text-foreground")], children)
}

// --- view: controls playground -------------------------------------------

/// The terse `dialog.dialog`: a trigger described by `options` plus a `children`
/// callback handed the minted `Anatomy` for the composable header/footer parts.
/// `dismiss` / `role` / `close_button` come from the controls via record-update
/// over `dialog.options()`.
fn view_playground(
  text: String,
  dismiss: dialog.Dismiss,
  role: dialog.Role,
  close_button: Bool,
  variant: button.Variant,
  size: button.Size,
) -> Element(msg) {
  page([
    dialog.dialog(
      options: dialog.Options(
        ..dialog.options(),
        text:,
        variant:,
        size:,
        dismiss:,
        role:,
        close_button:,
      ),
      children: fn(d) {
        [
          dialog.header([], [
            dialog.title(d, [html.text("Edit profile")]),
            dialog.description(d, [
              html.text(
                "Make changes to your profile here. Click save when you're done.",
              ),
            ]),
          ]),
          dialog.footer([], [
            dialog.close(
              d,
              variant: button.Outline,
              size: button.Medium,
              children: [
                html.text("Cancel"),
              ],
            ),
            dialog.close(
              d,
              variant: button.Default,
              size: button.Medium,
              children: [
                html.text("Save changes"),
              ],
            ),
          ]),
        ]
      },
    ),
  ])
}

// --- views: shadcn doc examples ------------------------------------------

/// shadcn "Usage" demo — Edit profile, with a form (Name / Username), Cancel +
/// Save, and the built-in corner ✕. Uses the composable parts so `content` can
/// take shadcn's `sm:max-w-sm` width override.
fn view_demo() -> Element(Nil) {
  let d = dialog.anatomy()
  page([
    dialog.trigger(d, variant: button.Outline, size: button.Medium, children: [
      html.text("Open Dialog"),
    ]),
    dialog.content(
      d,
      dismiss: dialog.LightDismiss,
      role: dialog.Standard,
      on_close: option.None,
      attrs: [attribute.class("sm:max-w-sm")],
      children: [
        dialog.header([], [
          dialog.title(d, [html.text("Edit profile")]),
          dialog.description(d, [
            html.text(
              "Make changes to your profile here. Click save when you're done.",
            ),
          ]),
        ]),
        field_group([
          field(label: "Name", id: "name-1", value: "Pedro Duarte"),
          field(label: "Username", id: "username-1", value: "@peduarte"),
        ]),
        dialog.footer([], [
          dialog.close(
            d,
            variant: button.Outline,
            size: button.Medium,
            children: [
              html.text("Cancel"),
            ],
          ),
          dialog.close(
            d,
            variant: button.Default,
            size: button.Medium,
            children: [
              html.text("Save changes"),
            ],
          ),
        ]),
        dialog.close_icon(d),
      ],
    ),
  ])
}

/// shadcn "Custom Close Button" — a Share-link dialog: a read-only link input
/// and a footer (`sm:justify-start`) with a single Close button, plus the corner
/// ✕. `content` widened to `sm:max-w-md`.
fn view_close_button() -> Element(Nil) {
  let d = dialog.anatomy()
  page([
    dialog.trigger(d, variant: button.Outline, size: button.Medium, children: [
      html.text("Share"),
    ]),
    dialog.content(
      d,
      dismiss: dialog.LightDismiss,
      role: dialog.Standard,
      on_close: option.None,
      attrs: [attribute.class("sm:max-w-md")],
      children: [
        dialog.header([], [
          dialog.title(d, [html.text("Share link")]),
          dialog.description(d, [
            html.text("Anyone who has this link will be able to view this."),
          ]),
        ]),
        html.div([attribute.class("flex items-center gap-2")], [
          html.div([attribute.class("grid flex-1 gap-2")], [
            html.label([attribute.for("link"), attribute.class("sr-only")], [
              html.text("Link"),
            ]),
            html.input([
              attribute.id("link"),
              attribute.value("https://ui.shadcn.com/docs/installation"),
              attribute.readonly(True),
              attribute.class(
                "h-9 w-full rounded-md border bg-transparent px-3 py-1 text-sm shadow-xs outline-none",
              ),
            ]),
          ]),
        ]),
        dialog.footer([attribute.class("sm:justify-start")], [
          dialog.close(
            d,
            variant: button.Default,
            size: button.Medium,
            children: [
              html.text("Close"),
            ],
          ),
        ]),
        dialog.close_icon(d),
      ],
    ),
  ])
}

/// shadcn "No Close Button" — `showCloseButton={false}`, so no corner ✕ (just
/// omit `close_icon` from the children).
fn view_no_close_button() -> Element(Nil) {
  let d = dialog.anatomy()
  page([
    dialog.trigger(d, variant: button.Outline, size: button.Medium, children: [
      html.text("No Close Button"),
    ]),
    dialog.content(
      d,
      dismiss: dialog.LightDismiss,
      role: dialog.Standard,
      on_close: option.None,
      attrs: [],
      children: [
        dialog.header([], [
          dialog.title(d, [html.text("No Close Button")]),
          dialog.description(d, [
            html.text(
              "This dialog doesn't have a close button in the top-right corner.",
            ),
          ]),
        ]),
      ],
    ),
  ])
}

/// shadcn "Sticky Footer" — a `max-h-[50vh]` scroll region between the header
/// and footer; the grid layout keeps the footer pinned below the scroll area.
fn view_sticky_footer() -> Element(Nil) {
  let d = dialog.anatomy()
  page([
    dialog.trigger(d, variant: button.Outline, size: button.Medium, children: [
      html.text("Sticky Footer"),
    ]),
    dialog.content(
      d,
      dismiss: dialog.LightDismiss,
      role: dialog.Standard,
      on_close: option.None,
      attrs: [],
      children: [
        dialog.header([], [
          dialog.title(d, [html.text("Sticky Footer")]),
          dialog.description(d, [
            html.text(
              "This dialog has a sticky footer that stays visible while the "
              <> "content scrolls.",
            ),
          ]),
        ]),
        lorem_body(),
        dialog.footer([], [
          dialog.close(
            d,
            variant: button.Outline,
            size: button.Medium,
            children: [
              html.text("Close"),
            ],
          ),
        ]),
        dialog.close_icon(d),
      ],
    ),
  ])
}

/// shadcn "Scrollable Content" — same scroll region, no footer.
fn view_scrollable() -> Element(Nil) {
  let d = dialog.anatomy()
  page([
    dialog.trigger(d, variant: button.Outline, size: button.Medium, children: [
      html.text("Scrollable Content"),
    ]),
    dialog.content(
      d,
      dismiss: dialog.LightDismiss,
      role: dialog.Standard,
      on_close: option.None,
      attrs: [],
      children: [
        dialog.header([], [
          dialog.title(d, [html.text("Scrollable Content")]),
          dialog.description(d, [
            html.text("This is a dialog with scrollable content."),
          ]),
        ]),
        lorem_body(),
        dialog.close_icon(d),
      ],
    ),
  ])
}

/// shadcn "RTL" — the Edit-profile demo with `dir="rtl"` on the content (Arabic
/// copy), so layout, text alignment, and the footer row mirror.
fn view_rtl() -> Element(Nil) {
  let d = dialog.anatomy()
  page([
    dialog.trigger(d, variant: button.Outline, size: button.Medium, children: [
      html.text("فتح الحوار"),
    ]),
    dialog.content(
      d,
      dismiss: dialog.LightDismiss,
      role: dialog.Standard,
      on_close: option.None,
      attrs: [attribute.attribute("dir", "rtl"), attribute.class("sm:max-w-sm")],
      children: [
        dialog.header([], [
          dialog.title(d, [html.text("تعديل الملف الشخصي")]),
          dialog.description(d, [
            html.text(
              "قم بإجراء تغييرات على ملفك الشخصي هنا. انقر فوق حفظ عند الانتهاء.",
            ),
          ]),
        ]),
        field_group([
          field(label: "الاسم", id: "name-rtl", value: "Pedro Duarte"),
          field(label: "اسم المستخدم", id: "username-rtl", value: "@peduarte"),
        ]),
        dialog.footer([], [
          dialog.close(
            d,
            variant: button.Outline,
            size: button.Medium,
            children: [
              html.text("إلغاء"),
            ],
          ),
          dialog.close(
            d,
            variant: button.Default,
            size: button.Medium,
            children: [
              html.text("حفظ التغييرات"),
            ],
          ),
        ]),
        dialog.close_icon(d),
      ],
    ),
  ])
}
