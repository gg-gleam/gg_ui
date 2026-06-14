# dev-docs

Architectural notes for `gg_ui`. Read [`vision.md`](vision.md) first; the rest
are deep dives into the boxes it names.

## Start here

- **[vision.md](vision.md)** — the layered model, what shadcn concept maps
  to what in Gleam, what's in scope now vs deferred. The map of the
  project.

## Reference docs

Layered roughly bottom-up (foundations first):

- **[composition.md](composition.md)** — how Lustre adapts Base UI's
  composition model: the `gg_base_ui` / `gg_ui` package split (headless
  imported, never ejected), `attributes(...)`, `Target`,
  anchors-aren't-non-native, `cn` (a pure-Gleam class join). *Existing doc —
  read this before adding a new component.*
- **[styling.md](styling.md)** — the three orthogonal axes (Style / Base
  Color / Theme) plus Motion, all toggled by root classes. The **Style**
  axis (shape: nova / vega / luma / sera / lyra / mira / maia) ships as
  per-component CSS **fragments** (`styles/shapes/<style>/{button,popover}.css`)
  — the shadcn v4 "thin component + per-style overlay" pattern.
- **[themes.md](themes.md)** — the **Base Color** axis (neutral palette:
  neutral / stone / zinc / mauve / olive / mist / taupe) and the **Theme**
  axis (accent override of `--primary`: amber, blue, … 17 in all),
  `styles/tokens.css`, fragments vs the consumer entry, light/dark
  mechanics. Naming is shadcn-exact — the accent axis is "Theme", never
  "colors".
- **[typography.md](typography.md)** — the **font axis** and the `text`
  component. The library exposes only the
  `--font-sans`/`--font-heading`/`--font-mono` vars (via `@theme inline`);
  **font *family* selection is a consumer concern** — the Storybook app
  loads real `@fontsource` families behind **Font** + **Heading** toolbars
  (shadcn's body/heading split). Then a **considered divergence from
  shadcn** (which ships no typography component): a typed, tokenized
  **`text` component** (`gg_ui/ui/text`) — closed numeric **size** scale
  `s1…s7` with baked weight variants (`s4_m`/`s4_b`), tokenized `Attr`
  modifiers, no `className`; default `<span>`, `render_as` for semantic
  elements. Markdown/MDX is out of scope (Tailwind `prose`). Documents the
  shadcn↔gg_ui contrast and records the shipped API as an honest bet.
- **[icons.md](icons.md)** — icon strategy: placeholder pattern in
  registry source, transformer at install time, generated inline-SVG
  Gleam modules per library. Works on both Lustre targets.
- **[stateful-components.md](stateful-components.md)** — the pattern for the
  components that *can't* be native-first/render-once (combobox first, then
  select / menu / autocomplete): a stateful Lustre `Model`/`update` component
  split into a **pure, both-target-tested core** and a thin **effectful shell**
  that quarantines the DOM/FFI. Controlled-vs-uncontrolled and where FFI is
  allowed.

## The registry & CLI

How users consume our work. Both deferred to varying degrees but
fully specified here so the architecture targets them.

- **[registry.md](registry.md)** — the data layer. Schema (a near-verbatim
  fork of shadcn's), item types, `npmDependencies` extension, file-path
  conventions.
- **[config.md](config.md)** — `components.json` in a consuming app.
  Field-by-field mapping from shadcn's schema, aliases as Gleam module
  paths, dropped fields.
- **[cli.md](cli.md)** — *deferred.* The `gg-ui` binary. Fork strategy
  from shadcn's `packages/shadcn`, which modules to keep verbatim vs
  rewrite, commands, install flow. The eject copies the thin
  `ui/<component>.gleam` + `helpers/cn` and runs `gleam add gg_base_ui` —
  the headless import stays verbatim, never copied into user code.

## Repo-level

- **[monorepo.md](monorepo.md)** — the realized layout: `packages/gg_base_ui`
  (headless Hex package, imported not ejected), `packages/gg_ui` (thin
  styled kit + CSS fragments), and the repo-root `gg_ui_docs` host (CSS
  entry `src/docs/gg_ui.css` + `src/stories/` + Node tooling). Still
  deferred: `packages/gg_ui_cli` (npm), a deployed `apps/docs`, the
  generated `gg_ui_registry/`.

## Conventions for these docs

- One file per architectural concept, named after what it contains.
- Link with relative paths (`[`config.md`](config.md)`). Anchor links to
  sections within the same doc are fine.
- Each doc is self-contained enough to read on its own, but cross-links
  freely instead of duplicating.
- Mark deferred work as **deferred** in the doc's intro paragraph so a
  reader knows whether they're reading "how it works" or "how it will
  work".
- Document open questions inline. They turn into PRs later, not into
  separate planning docs.
