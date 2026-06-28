# AGENTS.md

> `CLAUDE.md` is a symlink to this file — **edit `AGENTS.md` only.**
> This is the agent's index. It states the rules and points into the canonical
> docs ([`README.md`](README.md) and [`dev-docs/`](dev-docs/README.md)); it does
> not re-document the toolchain. When the two disagree, fix the drift.

## What gg_ui is

A **headless-first UI kit for [Lustre](https://lustre.build)** (the Gleam
frontend framework). It ports **shadcn/ui's patterns** — not its code — to Gleam,
layered the way Base UI + shadcn are.

shadcn offers two headless backends: Radix and Base UI. **This project follows
the Base UI implementation only. Never port Radix behavior.**

## Two reference repos (read them — they live on this machine)

| Repo | Role | Path |
| --- | --- | --- |
| **Base UI** | The **behavior** source of truth — anatomy, state machine, focus/keyboard, ARIA. | `/Users/andres/code/opensource/base-ui` (component parts under `packages/react/src/<component>/`) |
| **shadcn/ui** | The **styled surface** — variants, class recipes, prop ergonomics, naming. | `/Users/andres/code/opensource/shadcn-ui` |

**Rule of thumb:** *behavior comes from Base UI, looks and API feel come from
shadcn. When they disagree on behavior, Base UI wins.*

## The non-negotiable rules

1. **Base UI only**, never Radix (see above).
2. **The layer boundary is a package boundary.** `packages/gg_base_ui` (headless
   behavior + a11y) is its **own Hex package** — pure Gleam, **no Tailwind, no
   stylesheet**. Like shadcn imports Base UI, it is **imported, never ejected**:
   `packages/gg_ui` (the styled kit) depends on it, and so do apps the CLI scaffolds.
   Styling composes on top in `gg_ui`, never the reverse. Full model in
   [`dev-docs/composition.md`](dev-docs/composition.md).
   **`gg_ui` is also a facade: its *public* API must never name a `gg_base_ui`
   type.** Import the headless package as `base_<x>` and keep it internal —
   consumers (and the CLI-ejected `ui/`) import **only `gg_ui`**, so the headless
   layer can be restructured without breaking the styled surface. Because Gleam
   **can't re-export a constructor**, a `pub type T = base.T` alias only hides the
   *type name*: for any enum a caller constructs (`Dismiss`, positioning
   `Placement`/`Side`/`Align`, …) `gg_ui` defines its **own** variants + a private
   `*_to_base` mapping; opaque handles a caller never builds (e.g. popover
   `Anatomy`) can stay a plain alias; capabilities (`open`/`close`/…) are thin
   wrappers. This is why `button` owns its `Variant`/`Size` and `popover` re-exports
   `Anatomy`/`Dismiss` rather than leaking `base_*` — match that for every component.
3. **Universal — both targets, or it doesn't ship.** The library packages
   (`gg_base_ui`, `gg_ui`) pin **no** `target`; they must compile *and behave
   identically* on **JS *and* the BEAM** (see [`dev-docs/vision.md`](dev-docs/vision.md)
   rule 2). Prefer **pure Gleam** for anything in the styled output so it's
   target-agnostic by construction — e.g. `cn` is `clsx + tailwind-merge` backed
   by **`packages/gg_cn`**, our own **pure-Gleam** tailwind-merge port (no FFI,
   no Elixir `tails`, so **CI needs no Elixir** and the engine behaves identically
   on JS + BEAM). `cn` resolves real Tailwind conflicts because components now
   emit **raw structural utilities** alongside `cn-*` recipe names (see rule 8);
   the engine (class trie) is built once via `gg_cn.default()`. Where a
   target-specific engine *is* unavoidable, make sure both targets produce the
   same bytes — a JS-only shortcut that diverges on SSR is a rule-3 violation.
   Client-only behavior (DOM FFI) lives behind the headless boundary with a Gleam
   fallback body so the markup still renders server-side with no client effect.
4. **Web-first / native primitives.** Build on the platform even when browser
   coverage isn't universal — native Popover API (top layer + light-dismiss),
   CSS Anchor Positioning (no JS positioning lib), `:popover-open` for visual
   state, `:has()`, container queries, view transitions. Prefer a primitive over
   a hand-rolled JS reimplementation. Keep FFI minimal. **Motion follows the same
   rule:** native CSS (`@starting-style` + `transition-behavior: allow-discrete`)
   for top-layer enter/exit; reserve shadcn's `tw-animate-css` plugin for
   components whose motion is genuinely keyframe-shaped / JS-mounted, installed
   only when needed (see `styles/motion.css`).
5. **Check the modern-web guidance before writing any HTML/CSS or client JS.**
   Invoke the installed Claude Code skill **`modern-web-guidance:modern-web-guidance`**
   (the `modern-web-guidance` plugin from the **`googlechrome`** marketplace;
   mirrors <https://developer.chrome.com/docs/modern-web-guidance>) — query it
   *first*, because training data goes stale fast on web APIs. If it isn't
   available, add the `googlechrome` marketplace and install the plugin. A
   sibling skill, `modern-web-guidance:chrome-extensions`, covers extension work.
6. **Dogfood the design system.** Anywhere *we* render UI — Storybook stories,
   the docs site, future apps, even a component composed of others — **use our
   own `gg_ui` components instead of raw Tailwind** whenever one fits. A story
   showing a label uses `gg_ui/ui/text` (`text.s2([text.color(text.Muted)], …)`),
   **not** `html.p` with `class="text-sm text-muted-foreground"`. Reach for raw
   Tailwind only for the gaps the kit doesn't cover yet (bare layout — flex/grid
   scaffolding). If you catch yourself hand-writing a recipe a component already
   owns (text sizing/color, buttons, inputs, …), that's the signal to swap it for
   the component. Dogfooding is how we find the kit's rough edges first.
7. **Shape fragments are `@apply`-only, one rule per `cn-*` class.** Every rule in
   `styles/shapes/<style>/<component>.css` (and the other shippable recipe
   fragments) must be a **single-class selector** — `.cn-foo { @apply <tailwind
   utilities/variants>; }` — whose body is **nothing but Tailwind** (`@apply`
   utilities, variants, and arbitrary `[property:value]` utilities). This is a
   hard requirement: the CLI **ejects each `cn-*` recipe into the user's markup**
   as the className string, so a class must be self-contained. **Forbidden:** raw
   CSS declarations, and any selector that isn't a lone class —
   `.cn-x:has(…)`, `.cn-x[data-…] .cn-y`, descendant/compound/combinator rules,
   bare element/attribute selectors. Express all state and cross-element logic as
   **Tailwind variants on the class itself**: `data-*`, `aria-*`, `has-[…]`,
   `group-*`/`peer-*`/`in-*`/`*:`, etc. (e.g. *not*
   `.cn-avatar[data-status=error] .cn-avatar-image { … }` but
   `.cn-avatar-image { @apply … group-data-[status=error]/avatar:hidden; }`).
8. **Structural utilities raw, themeable surface in `cn-*` (the shadcn split).**
   A component's class string has **two buckets**, exactly as shadcn's Base UI
   `style-mira` components do (e.g.
   `shadcn-ui/apps/v4/registry/bases/base/ui/button.tsx` +
   `registry/styles/style-mira.css`): (a) **structural / overridable** utilities
   that are constant across styles — layout, flex, svg pointer rules
   (`inline-flex items-center justify-center shrink-0 …`) — are emitted as **raw
   Tailwind directly in the component** (the Gleam `base` string), so a caller's
   `class` override can win; (b) the **themeable surface** that varies by
   style/theme — color, radius, border, rings, font — lives in the `cn-*` `@apply`
   recipe (rule 7). Keeping (a) raw is what makes overrides work: `cn` runs
   tailwind-merge so e.g. `justify-between` **removes** the default
   `justify-center` (CSS cascade is decided by stylesheet order, so merely
   appending the override is unreliable — the loser must be dropped, and a
   `.style-x .cn-y` recipe would out-specify a plain utility anyway). A caller
   passes the override as a normal `class` attribute in `attrs`; the component
   folds it in with **`cn.merge(own: classes(variant:, size:), attrs: attrs)`**
   (from **`gg_base_ui/helpers/cn`**), which pulls every `class` value out of
   `attrs` and runs them through tailwind-merge with the component's own classes,
   emitting a single merged `class`. (Not a separate `attribute.class` — Lustre
   would concatenate without resolving conflicts.) The helper lives in
   **`gg_base_ui`** (imported, never ejected) so its logic and its
   `lustre/vdom/vattr` read are updated **once** centrally, never frozen into
   ejected user code; only the trivial styled `ui/` component ejects. **Do not**
   bury overridable structural utilities inside `@apply`. Mirror the shadcn
   component's exact split per component.

## Project map

A monorepo: Gleam library packages under `packages/`, consumer apps under
`apps/` (Storybook today; a docs site later), and the repo root as a pure
pnpm-workspace orchestrator (no Gleam package of its own). The **icon system**
splits core-vs-data: the core (`gg_icon` + `gg_icon_gen`) lives here in
`packages/`; the big, community-extensible icon **sets** (`gg_icons_lucide`, …)
are separate repos that depend on the published `gg_icon`. See
[`dev-docs/icons.md`](dev-docs/icons.md).

```
packages/
  gg_base_ui/                # LAYER 1 — headless behavior + a11y. Own Hex package;
    src/gg_base_ui/          #   IMPORTED, never ejected. Emits no Tailwind/CSS.
      button/  popover/      #   Native-first; relative `./*_ffi.ts` only where the
      positioning/  arrow/   #   platform needs glue (positioning/arrow are shared).
      helpers/id_gen/        #   the `useId` analogue (popover depends on it)
      helpers/cn.gleam       #   cn = clsx+tailwind-merge (via gg_cn) + cn.merge (folds class from attrs).
                             #   Imported, never ejected → fixed once, not frozen per user. (deps gg_cn)
  gg_ui/                     # LAYER 2 — thin styled kit. Depends on gg_base_ui + gg_icons_lucide
                             #   (default icon set / source of truth; CLI swaps it per components.json at eject).
    src/gg_ui/
      ui/button.gleam        #   Emit raw structural utils + `cn-*` recipe names (gva+cn); see rule 8.
      ui/popover.gleam       #   Native-first preserved. (ui/ is what the CLI ejects.)
      styles/                #   shippable CSS *fragments* — NO `@import "tailwindcss"`:
        tokens.css           #     shared `@theme inline` map + `:root { --radius }`
        base_colors/<name>.css   # BASE COLOR axis  → `.base-color-<name>` (7 neutrals)
        themes/<name>.css        # THEME axis (accents) → `.theme-<name>` (17 colors)
        shapes/<style>/{button,popover}.css (+ <style>.css index)  # STYLE axis → `.style-<name>`
        motion/<comp>.css (+ motion.css index)   # shared MOTION layer (native)
  gg_cn/                     # TAILWIND-MERGE — pure-Gleam clsx+tailwind-merge port (from cnfast).
    src/gg_cn.gleam          #   Backs gg_ui's `cn`. No FFI, both-target; `default()` = lazy global.
  gg_icon/                   # ICON INTERFACE — set-agnostic Hex pkg: Size, the icon.svg()
    src/gg_icon/icon.gleam   #   wrapper, placeholder (fallback box). Tailwind-free, no set.
  gg_icon_gen/               # ICON GENERATOR engine (dev tool, own Hex pkg): SVG→Gleam +
    src/gg_icon_gen/         #   shard + emit + icons.json. Sets dev-dep it; never shipped.
apps/
  storybook/                 # Storybook host APP (own gleam.toml `gg_ui_storybook` + package.json
    src/gg_ui.css            #   `@gg_ui/storybook`; path-deps both packages). CSS ENTRY here:
    src/stories/<component>/ #   `@import "tailwindcss"` + assembles fragments. Stories:
    .storybook/ vite.config.ts vitest.config.ts tsconfig.json  # <c>.stories.ts + <c>.gleam
(repo root)                  # pure pnpm-workspace orchestrator — no gleam.toml of its own:
  package.json pnpm-workspace.yaml   #   workspace scripts (delegate via `pnpm --filter`/`-r`)
  biome.json (.ts/.json)  .stylelintrc.json (.css)   # shared lint/format config, whole tree
dev-docs/                    # architecture bible — start at dev-docs/README.md
```

> **Fragments vs entry.** Library packages ship *fragments* (no Tailwind import).
> A *consumer* (the `apps/storybook` app today; a real app via the CLI later)
> writes **one entry** that `@import`s Tailwind then the fragments. Tests run
> **per package** (`cd packages/gg_base_ui && gleam test`); `gleam build` from
> `apps/storybook` compiles the whole path-dep graph (the root is not a Gleam
> package). The monorepo is realized; `packages/gg_ui_cli` and an `apps/docs`
> site are still deferred.

Deeper reading: [`dev-docs/vision.md`](dev-docs/vision.md),
[`composition.md`](dev-docs/composition.md),
[`styling.md`](dev-docs/styling.md), [`themes.md`](dev-docs/themes.md),
[`monorepo.md`](dev-docs/monorepo.md), [`registry.md`](dev-docs/registry.md),
[`cli.md`](dev-docs/cli.md), [`icons.md`](dev-docs/icons.md). Toolchain &
commands: [`README.md`](README.md).

## Building / refining a component — the workflow

1. **Read the Base UI source first** (`packages/react/src/<component>/`). Map its
   anatomy (Root/Trigger/Positioner/Popup/…), state machine, focus management,
   keyboard interactions, and the ARIA contract (roles + `aria-*` + id wiring).
2. **Check shadcn** for the variant set, default class recipe, and prop feel to
   mirror.
3. **Reach for a native primitive** before reimplementing behavior in Gleam
   (rule 3) — confirm against the modern-web guidance (rule 4).
4. **Write the headless layer** in `packages/gg_base_ui/src/gg_base_ui/<component>/`
   — behavior + a11y + `data-*`/ARIA only, no Tailwind, no token imports. FFI
   `@external` paths are **relative** (`"./<name>_ffi.ts"`) so they resolve from
   any package. Keep the Base UI mapping in the module comment (match existing).
5. **Write the thin styled layer** in `packages/gg_ui/src/gg_ui/ui/<component>.gleam`
   — compose the headless attributes onto elements that carry `cn-*` class names
   (`gva` + `cn`, below). Put each class's Tailwind recipe in the per-component
   fragment `styles/shapes/<style>/<component>.css` (+ the `<style>.css` index).
6. **Add a Storybook story** (next section) and **`gleam test`** the pure parts.

### Worked example — the two layers + `gva`/`cn`

The headless layer (in `gg_base_ui`) returns *behavior attributes* to merge onto
any element (`gg_base_ui/button/button.gleam` — the `useButton`/`render`-prop split):

```gleam
// packages/gg_base_ui/src/gg_base_ui/button/button.gleam
pub fn attributes(config config: Config, target target: Target) -> List(Attribute(msg))
pub fn button(config, attrs, children) -> Element(msg)  // renders <button> + attributes
```

The **thin** styled layer follows shadcn's authoring model (rule 8): the `base`
string mixes **raw structural utilities** (constant across styles, overridable)
with the `cn-*` recipe names (`cn-button cn-button-variant-default
cn-button-size-default`) whose Tailwind lives in the shape fragment. **`gva`**
(Gleam Variance Authority — the CVA analogue) assembles the recipe, and **`cn`**
(= `clsx + tailwind-merge` via `gg_cn`) folds everything into one class string,
**resolving real conflicts** (`cn-*` names have none and pass through; raw
utilities dedupe by group). The themeable Tailwind for each `cn-*` lives in the
per-component shape fragment (`styles/shapes/nova/button.css`, under
`.style-nova`); `gg_base_ui/button/button` is imported as `base_button`:

```gleam
// packages/gg_ui/src/gg_ui/ui/button.gleam
import gg_base_ui/button/button as base_button
import gg_base_ui/helpers/cn                  // cn + cn.merge (imported, never ejected)
// cn-button = themeable recipe; the rest are raw structural utilities, kept raw
// so a caller's `class` can override them (mirrors shadcn's button base string).
const base = "cn-button group/button inline-flex shrink-0 items-center justify-center whitespace-nowrap …"

pub fn classes(variant variant: Variant, size size: Size) -> String {
  gva.gva(default: base, resolver: resolve, defaults: [])
  |> gva.with(VariantKey(variant))           // → "cn-button-variant-default"
  |> gva.with(SizeKey(size))                 // → "cn-button-size-default"
  |> gva.build
  |> fn(recipe) { cn.cn([recipe]) }
}

pub fn button(variant, size, attrs, children) -> Element(msg) {
  base_button.button(                       // headless behavior…
    config: base_button.config(),
    attrs: [
      attribute.attribute("data-slot", "button"),
      // cn.merge folds the caller's `class` (from attrs) through tailwind-merge
      // with the component's own classes → one merged `class`, overrides win.
      ..cn.merge(own: classes(variant:, size:), attrs: attrs)
    ],
    children:,
  )
}
```

```css
/* styles/shapes/nova/button.css — themeable surface only, keyed by cn-* names.
 * Structural utilities (inline-flex/items-center/justify-center) are NOT here —
 * they're raw in the component `base` so callers can override them (rule 8). */
.style-nova {
  .cn-button { @apply rounded-lg border bg-clip-padding text-sm font-medium …; }
  .cn-button-variant-default { @apply bg-primary text-primary-foreground; }
  .cn-button-size-default    { @apply h-8 gap-1.5 px-2.5; }
}
```

Cross-rule conflicts (e.g. base `border-transparent` vs
`.cn-button-variant-outline border-border`) resolve by **source order** —
variant/size rules come after the base, so they win (shadcn's own ordering).
Color is two axes of pure CSS vars: `base_colors/<name>.css` (`.base-color-*`,
the neutrals + a default `--primary`) and `themes/<name>.css` (`.theme-*`,
accents that override `--primary`); `tokens.css` republishes them via `@theme
inline`. Three independent axes — `style-<x>` + `base-color-<y>` +
`theme-<z>` (+ `dark`) — combine on the root, matching shadcn's Style / Base
Color / Theme. The CSS entry (`apps/storybook/src/gg_ui.css`) imports Tailwind,
then the fragments; see [`styling.md`](dev-docs/styling.md) + [`themes.md`](dev-docs/themes.md).

> ✅ **`cn` merges (via `gg_cn`).** It runs `clsx + tailwind-merge`, so a caller
> mixing in raw Tailwind utilities gets real conflict resolution — last wins, the
> loser is **removed** (`cn(["… justify-center", "justify-between"])` →
> `justify-between`). `cn-*` recipe names carry no conflicting utilities, so they
> pass through untouched. `gg_cn` is our **pure-Gleam** tailwind-merge port (no
> FFI / no `tails` / both-target); the engine is built once via `gg_cn.default()`.
> This only works because overridable utilities are **raw in the component**
> (rule 8) — utilities buried in a `cn-*` `@apply` recipe are invisible to the
> merge engine *and* out-specified by the `.style-x .cn-y` selector.

Other conventions worth knowing: **controlled vs uncontrolled** mirrors Base UI's
`open`/`defaultOpen` (`Uncontrolled` = browser owns state, the default;
`Controlled(on_change)` + `set_open` for combobox-style cases). Use
`gg_base_ui/helpers/id_gen` (the `useId` analogue) for stable ids — generate
**once**, never per render. FFI is **TypeScript**, referenced by a **relative**
path (so it resolves once the module lives in its own package), with a Gleam
fallback body that never runs (effects are client-side):

```gleam
@external(javascript, "./popover_ffi.ts", "showPopover")
fn show_popover(_content_id: String) -> Nil { Nil }
```

## Storybook stories

Every component gets a story so it's developable and reviewable in isolation.
`pnpm dev` runs Storybook on `:6006` (delegates to the `apps/storybook` app,
which reuses its `vite.config.ts`, so `.gleam` imports + Tailwind work inside
stories). Stories are discovered by the glob `src/**/*.stories.@(ts|tsx)` — they
must live under `apps/storybook/src/`, in `apps/storybook/src/stories/<component>/`.

A story is **two files**, with a clean split: TypeScript owns the Storybook
`meta`/controls, Gleam owns the rendering.

- **`<component>.stories.ts`** — `meta` (title, default `args`, `argTypes`
  controls) plus one `export const` per story. Each story's `render` hands a
  callback to `mountLustre`; the callback receives a **CSS selector string** and
  forwards it (with the control args) to an exported Gleam `mount_*` function:

  ```ts
  import { mountLustre } from "../../../.storybook/lustre-mount";
  import { mount_playground, mount_variants } from "./button.gleam";

  const variants = ["default", "destructive", "outline", /* … */] as const;

  const meta: Meta<ButtonArgs> = {
    title: "Components/Button",
    args: { variant: "default", size: "default", disabled: false },
    argTypes: { variant: { control: { type: "select" }, options: variants } /* … */ },
  };
  export default meta;

  // Controls-driven story: forward the args positionally to the Gleam mount.
  export const Playground: Story = {
    render: ({ variant, size, disabled }) =>
      mountLustre((selector) => mount_playground(selector, variant, size, disabled)),
  };

  // Showcase story: ignores args, disables the controls panel.
  export const Variants: Story = {
    parameters: { controls: { disable: true } },
    render: () => mountLustre(mount_variants),
  };
  ```

- **`<component>.gleam`** — exported `mount_*(selector: String, …) -> Nil`
  functions. Each maps the raw control **strings** to the component's Gleam enums
  with a `parse_*` helper (always with a safe fallback so a stray arg can't
  crash), builds the view from the **styled** layer, and starts Lustre into the
  selector. Use `lustre.element` for a static, render-once view (the native-first
  default — popover relies on this); use `lustre.application` only when the story
  needs host state (e.g. the controlled-popover demo):

  ```gleam
  pub fn mount_playground(
    selector: String, variant: String, size: String, disabled: Bool,
  ) -> Nil {
    let view =
      button.button(parse_variant(variant), parse_size(size), [], [html.text("Button")])
    let assert Ok(_) = lustre.start(lustre.element(view), selector, Nil)
    Nil
  }

  fn parse_variant(v: String) -> button.Variant {
    case v {
      "destructive" -> button.Destructive
      "outline" -> button.Outline
      // …
      _ -> button.Default   // safe fallback
    }
  }
  ```

Conventions: title under `Components/<Name>`; a `Playground` story bound to the
controls, plus fixed **showcase** stories (`Variants`, `Sizes`, …) with
`controls: { disable: true }` that render a grid for visual review. `mountLustre`
(`.storybook/lustre-mount.ts`) mints a fresh host `<div>` per render and passes
its `#id` selector on the next microtask. Tokens + recipes resolve because
`.storybook/preview.ts` imports the entry `src/gg_ui.css`; its decorator +
`globalTypes` put the active axes on the story root as toolbar dropdowns —
**Shape** (`style-*`), **Base color** (`base-color-*`), **Theme** (`theme-*`
accents, default `none`), **Mode** (`.dark`). Mirror the live example: the popover
stories cover the uncontrolled/controlled/collision cases worth copying.

## Before you call it done

- [ ] Read the Base UI source; mapped its behavior + ARIA. Checked shadcn for the
      styled surface.
- [ ] Checked `modern-web-guidance` for a native primitive before hand-rolling.
- [ ] Headless code in `gg_base_ui` imports **no** styling and **no Tailwind**;
      the thin `gg_ui/ui/` component emits `cn-*` class names (`gva` + `cn`,
      explicit `cn.cn(...)` for overrides) with the Tailwind recipe in the
      per-component shape fragment `styles/shapes/<style>/<component>.css`.
- [ ] **`gg_ui`'s public API names no `base_*` type** (rule 2 facade): own
      enums + `*_to_base` for caller-constructed variants, alias for opaque
      handles, thin wrappers for capabilities. A consumer/story compiles with
      **only** `import gg_ui/…` — grep the story for `import gg_base_ui` (should
      be none).
- [ ] FFI `@external` paths are relative (`"./<name>_ffi.ts"`), not `/src/…`.
- [ ] Story added (`.stories.ts` + `.gleam`) and visible in `pnpm dev`.
- [ ] **Run `pnpm format` after editing** — stylelint owns `.css` (lint + the
      blank-line-between-rules format), Biome owns `.ts`/`.json`; then `gleam test`
      passes **in each package** and `pnpm typecheck` + `pnpm lint` are clean.
