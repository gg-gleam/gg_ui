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
