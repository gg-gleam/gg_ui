//// gg_icon_gen — the shared icon-set generator engine.
////
//// A set's `gen/` project hands `generate` a `Config` (per-variant source dir +
//// view_box + defaults + a `clean` hook); the engine reads the upstream SVGs,
//// shards each by first letter, and writes the baked Gleam modules,
//// `internal.gleam`, and `icons.json`. Build-only — never shipped to consumers.

import gg_icon_gen/names
import gg_icon_gen/render
import gg_icon_gen/svg
import gleam/dict
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import simplifile

/// One rendering style of a set (`outline`, `filled`, …).
pub type Variant {
  Variant(
    /// Variant name; also the module directory and the `<name>_defaults` const.
    name: String,
    /// Exactly one variant should set this; the placeholder default.
    is_default: Bool,
    view_box: String,
    /// Baked onto every `<svg>` of this variant (stroke vs fill, etc.).
    defaults: List(#(String, String)),
    /// Local directory of `*.svg` files for this variant.
    source_dir: String,
  )
}

/// A set's generation config.
pub type Config {
  Config(
    /// Short set name, e.g. `"tabler"`.
    set: String,
    /// Gleam package/module prefix, e.g. `"gg_icons_tabler"`.
    module_prefix: String,
    /// Directory to write the `<variant>/<shard>.gleam` modules + `internal.gleam`.
    out_src: String,
    /// Path to write `icons.json`.
    out_manifest: String,
    variants: List(Variant),
    /// Per-set SVG-inner cleanup (e.g. drop Tabler's transparent bounding rect).
    /// Use `fn(nodes) { nodes }` for none.
    clean: fn(List(svg.Node)) -> List(svg.Node),
  )
}

pub type Error {
  ReadError(path: String, detail: simplifile.FileError)
  WriteError(path: String, detail: simplifile.FileError)
}

type Built {
  Built(kebab: String, fn_name: String, shard: String, snake: String, children: String)
}

/// Generate the whole set from its pinned upstream SVGs.
pub fn generate(config: Config) -> Result(Nil, Error) {
  use per_variant <- result.try(
    list.try_map(config.variants, fn(v) {
      use pairs <- result.try(generate_variant(config, v))
      Ok(#(v.name, pairs))
    }),
  )

  let internal_src =
    render.internal(list.map(config.variants, fn(v) { #(v.name, v.defaults) }))
  use _ <- result.try(write_file(config.out_src <> "/internal.gleam", internal_src))

  let manifest_src =
    render.manifest(
      set: config.set,
      variants: list.map(config.variants, fn(v) { v.name }),
      default_variant: default_variant(config),
      icons: per_variant,
    )
  write_file(config.out_manifest, manifest_src)
}

fn default_variant(config: Config) -> String {
  config.variants
  |> list.find(fn(v) { v.is_default })
  |> result.map(fn(v) { v.name })
  |> result.unwrap(case config.variants {
    [first, ..] -> first.name
    [] -> ""
  })
}

fn generate_variant(
  config: Config,
  variant: Variant,
) -> Result(List(#(String, String)), Error) {
  use files <- result.try(
    simplifile.read_directory(variant.source_dir)
    |> result.map_error(ReadError(variant.source_dir, _)),
  )

  use built <- result.try(
    files
    |> list.filter(string.ends_with(_, ".svg"))
    |> list.try_map(fn(file) { build_icon(config, variant, file) }),
  )

  // One module per shard.
  let by_shard = group_by_shard(built)
  use _ <- result.try(
    by_shard
    |> dict.to_list
    |> list.try_map(fn(entry) {
      let #(shard, icons) = entry
      write_shard(config, variant, shard, icons)
    }),
  )

  // name → shard pairs for the manifest (sorted by name).
  Ok(
    built
    |> list.map(fn(b) { #(b.snake, b.shard) })
    |> list.sort(fn(a, b) { string.compare(a.0, b.0) }),
  )
}

fn build_icon(
  config: Config,
  variant: Variant,
  file: String,
) -> Result(Built, Error) {
  let path = variant.source_dir <> "/" <> file
  use content <- result.try(
    simplifile.read(path) |> result.map_error(ReadError(path, _)),
  )
  let kebab = string.drop_end(file, 4)
  let snake = names.snake_case(kebab)
  let children =
    content
    |> svg.extract_inner
    |> svg.parse
    |> config.clean
    |> svg.emit_children
  Ok(Built(
    kebab: kebab,
    fn_name: names.fn_name(snake),
    shard: names.shard(snake),
    snake: snake,
    children: children,
  ))
}

fn write_shard(
  config: Config,
  variant: Variant,
  shard: String,
  icons: List(Built),
) -> Result(Nil, Error) {
  let render_icons =
    icons
    |> list.sort(fn(a, b) { string.compare(a.fn_name, b.fn_name) })
    |> list.map(fn(b) {
      render.Icon(kebab: b.kebab, fn_name: b.fn_name, children_src: b.children)
    })

  let module_src =
    render.module(
      set: config.set,
      module_prefix: config.module_prefix,
      variant: variant.name,
      shard: shard,
      view_box: variant.view_box,
      defaults_const: variant.name <> "_defaults",
      icons: render_icons,
    )

  let dir = config.out_src <> "/" <> variant.name
  use _ <- result.try(
    simplifile.create_directory_all(dir)
    |> result.map_error(WriteError(dir, _)),
  )
  write_file(dir <> "/" <> shard <> ".gleam", module_src)
}

fn group_by_shard(built: List(Built)) -> dict.Dict(String, List(Built)) {
  list.fold(built, dict.new(), fn(acc, b) {
    dict.upsert(acc, b.shard, fn(existing) {
      case existing {
        option.Some(xs) -> [b, ..xs]
        option.None -> [b]
      }
    })
  })
}

fn write_file(path: String, content: String) -> Result(Nil, Error) {
  simplifile.write(to: path, contents: content)
  |> result.map_error(WriteError(path, _))
}
