# Stateful components

Most of the kit is **native-first and render-once**. Popover and tooltip lean on
web-platform primitives (the Popover API, CSS anchor positioning, Interest
Invokers) so the browser owns the state: "no `Bool` lives in Gleam-land," the
BEAM emits markup, and there's no `Model`/`update` loop. See
[`composition.md`](composition.md) and the popover module header.

**Combobox is the first component where that doesn't hold.** There is no native
combobox/autocomplete primitive: filtering a list against typed text, moving an
active-descendant highlight with the arrow keys, and wiring the listbox/option
ARIA are *behaviour we have to run ourselves*. So combobox — and the interactive
components that will follow it (select, menu, autocomplete) — is a **stateful
Lustre component**: `Model` / `Msg` / `update` / `view`. This doc is the pattern
those components share.

## Still universal (rule 3)

A `Model`/`update` loop is **not** a target-specific escape hatch. Lustre's
runtime is exactly the thing that runs on **both** JS and the BEAM, so a stateful
component is as universal as a render-once one — the BEAM renders the closed
markup + ARIA scaffolding server-side, and the same `update` drives it on the
client. The rule that matters is *where the impurity lives* (below).

## The two-part shape: pure core + effectful shell

Split every stateful headless component in two, so the hard logic is testable in
isolation and the DOM is quarantined:

1. **Pure core** — a state record and pure transitions over it. **No DOM, no
   effects, no ARIA, no Lustre.** Just `Model(value)` + functions
   `Model -> Model` (and `Model -> #(Model, …)` where a result must flow out).
   This is where the cross-target risk concentrates (string filtering, index
   math), so it gets **exhaustive unit tests run on both targets** in CI.

   The combobox core is `gg_base_ui/combobox/combobox.gleam`: `matches` /
   `visible` (filter), `navigate` / `move` (highlight), `set_query` / `select` /
   `open` / `close` (transitions), `is_selected` / `is_empty` (selectors).

2. **Effectful shell** — the Lustre component proper: the `Msg` enum, an `update`
   that maps each `Msg` to a core transition **plus** any DOM `Effect`, and a
   `view` that renders the parts with their listbox/option ARIA. This is the
   **only** place DOM/FFI enters.

```
Msg ──update──▶ core transition (pure)  ─▶ new Model
                     └▶ Effect (FFI: scroll active option into view,
                                focus the input, read --anchor-width)
Model ──view──▶ Elements + ARIA (role=combobox/listbox/option, aria-*)
```

### What FFI is allowed, and why it's safe SSR-side

Keep FFI to the few things only a live DOM can do, each behind an `@external`
with an inert Gleam fallback body (the rule-3 pattern from the popover FFI):

- scroll the active `option` into view as the highlight moves,
- focus the input when the list opens,
- measure the anchor to publish `--anchor-width`.

Because these are `Effect`s fired from `update` (never from `view`), a
server-render produces the markup with **no client effect** — the list renders
closed and correct, and the behaviour activates only once the runtime is live.
Positioning itself stays native (`gg_base_ui/positioning` + the Popover API), as
in popover — no JS positioning library.

### Browser support — Safari (three shims)

The native-first bet (rule 4) leans on APIs Safari shipped only partially.
Tested against **Safari 26.1**, which **does** support the Popover API, CSS
anchor *positioning* (`position-area` placement + `position-try-fallbacks` flip),
`anchor-size()`, and the CSS motion recipe (`@starting-style` +
`transition-behavior: allow-discrete`). What it lacks breaks one component each —
so the fix is **three small, independent shims**, all in `gg_base_ui` behind an
`@external` with the inert Gleam fallback, all feature-detected so Chrome/Firefox
and SSR run **zero** added JS:

1. **Popover — Invoker Commands.** The trigger opens via `command`/`commandfor`,
   unsupported in Safari, so it never opens. `ensureInvokerCommandsPolyfill`
   (`popover_ffi.ts`) installs a delegated `click` that runs the command and a
   `toggle` listener that keeps `aria-expanded` in sync. The one subtlety is the
   `popover="auto"` light-dismiss double-toggle (clicking an open popover's
   trigger light-dismisses it on pointerdown, so a naive toggle reopens it) —
   defeated by capturing the open-state at `pointerdown`. No-op when `"command"
   in HTMLButtonElement.prototype`.
2. **Tooltip — Interest Invokers.** The trigger opens via `interestfor` +
   `interest-delay-*`, unsupported in Safari, so it never shows.
   `ensureInterestInvokersPolyfill` (`tooltip_ffi.ts`) installs delegated
   pointer/focus listeners that show/hide the `popover="hint"` target with the
   delays (read from `data-interest-delay-*`, since the unknown CSS props are
   dropped). No-op when `"interestForElement" in HTMLButtonElement.prototype`.
3. **Combobox — anchor *sizing*.** Placement works, but the popup's
   `max-block-size: min(<cap>, calc(100% - <gap>))` relies on `100%` resolving
   against the `position-area` cell; Safari resolves it wrong, collapsing the list
   to a thin strip (`anchor-size(width)` for the width *does* resolve, so width is
   left native). `fitPopup` (`combobox_ffi.ts`) **inspects the actual rendered
   box** rather than feature-probing (`CSS.supports` and an `anchor-size` probe
   both report support while sizing still fails): if the box collapsed (content
   present, height < 24px) or overflows the viewport, it pins a definite
   `block-size` from the content height (so the `flex-basis:0` list can't
   collapse) and clamps `max-block-size` to the measured available space. It
   re-fits via a `MutationObserver` (async results / first-open loading mount a
   tick after open) + `resize`/`scroll`, rAF-coalesced, and no-ops where native
   CSS sized it fine.

**Listener lifecycle.** The popover/tooltip shims install **once** per page
(guarded flag, delegated on `document`) — mirroring `arrow_ffi`'s
`ensureResolvedSideObserver`, not per-instance, so nothing accumulates. The
combobox's per-open listeners (MutationObserver + resize + scroll + rAF) are torn
down three ways: the `hide` effect, a once-installed `toggle` listener (fires on
close **and** on DOM removal, covering unmount-while-open), and an `applyFit`
self-heal when the popup is gone.

Two smaller Safari fixes ride along the same way (feature-detected, no-op
elsewhere):

- **Arrow.** The caret shape is set via the CSS `d` property (`arrow.css`), which
  Safari doesn't support, so its `<path>`s render nothing. Where CSS `d` is
  unsupported, `arrow_ffi`'s resolved-side observer writes the `d` **attribute**
  per side instead (universal; CSS `d` wins by cascade where it exists).
- **Chip focus visibility.** Roving chip focus *worked* on Safari, but the ring
  didn't show: shadcn's chip (and ours) carried no focus style, relying on the UA
  outline, which Safari doesn't draw for a programmatically-focused
  `tabindex="-1"` element. The chip recipe now adds an explicit **`:focus`** ring
  (not `:focus-visible`, which Safari won't match for programmatic focus) — a
  deliberate a11y divergence (WCAG 2.4.7), same class as the chip-remove
  `aria-label`.

## Controlled vs uncontrolled

Mirror Base UI's `value`/`defaultValue` split, the same way popover handles
`open`:

- **Uncontrolled** (default) — the component owns the whole `Model`, including
  `selected`. The host mounts it and forgets it.
- **Controlled** — the parent owns the *selected value* and passes it in + an
  `on_change`; the component still owns the **transient UI state** (`query`,
  `active_index`, `open`) regardless. Selection changes are surfaced from the
  core (e.g. `select_active` returns the chosen value) so `update` can call
  `on_change` instead of (or alongside) storing it.

Transient UI state is never "controlled" — only the *selection* is. This keeps
the controlled API small and matches Base UI.

## The facade still applies

`gg_base_ui/combobox` is headless and internal. `gg_ui/ui/combobox` re-exposes it
under gg_ui's own names — its own `SelectionMode` / `Side` / `Align` enums with
`*_to_base` mappings, opaque handles aliased, capabilities wrapped — so no
`base_*` type appears in the public surface (rule 2). See
[`composition.md`](composition.md).
