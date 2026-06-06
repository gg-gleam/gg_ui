// id_gen FFI (JavaScript target) — the `useId`-style unique id counter.
//
// One module-level counter shared by every Lustre runtime on the page, so even
// multiple independently-mounted apps (e.g. several Storybook canvases) never
// collide. Post-increment: first call returns `<prefix>-0`.
//
// The Erlang counterpart lives in `gg_base_ui_id_gen_ffi.erl`. Keep the export name
// (`nextId`) in sync with the `@external(javascript, ...)` binding in
// `id_gen.gleam`.

let counter = 0

export function nextId(prefix: string): string {
  return `${prefix}-${counter++}`
}
