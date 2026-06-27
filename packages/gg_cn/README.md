# gg_cn

A **pure-Gleam `tailwind-merge`** — resolves conflicting Tailwind CSS utility
classes by keeping the last one per conflict group, so `px-2 px-4` collapses to
`px-4`. Ported from [cnfast](https://github.com/aidenybai/cnfast)'s logic engine
(itself a faithful reimplementation of `tailwind-merge` v4).

It is **pure Gleam, no FFI**, so it compiles and behaves identically on **both**
the JavaScript and Erlang targets.

> **Not the same as `gg_ui`'s `cn`.** `gg_ui/helpers/cn` is a deliberate plain
> whitespace-collapsing *join* — gg_ui emits non-conflicting semantic `cn-*`
> names, so there is nothing to merge and it carries no merge dependency.
> `gg_cn` is the real conflict-resolution engine, for consumers who *do* mix raw
> Tailwind utilities. gg_ui does **not** depend on it.

## Usage

```gleam
import gg_cn

pub fn main() {
  // Build the merger once (it compiles regexes + builds the class trie) and
  // reuse it across calls.
  let merge = gg_cn.new()

  gg_cn.tw_merge(merge, "px-2 py-1 px-4")
  // -> "py-1 px-4"

  // clsx-style conditional joining + merging in one (`cn` = clsx + twMerge):
  gg_cn.cn(merge, [
    gg_cn.Class("px-2 py-1"),
    gg_cn.When(is_active, "px-4"),
    gg_cn.When(has_error, "text-red-500"),
  ])
  // -> "py-1 px-4 text-red-500"  (when both conditions hold)

  // Just the join step (clsx / twJoin), no conflict resolution:
  gg_cn.tw_join([gg_cn.Class("text-white"), gg_cn.Class("bg-black")])
  // -> "text-white bg-black"
}
```

`new()` builds the class trie once — moderately expensive, so bind it once and
reuse it on hot paths rather than rebuilding per merge. The configuration is the
baked-in Tailwind v4 default; it is not (yet) configurable.

## What was ported, and what was not

Ported: the full `clsx`/`twJoin` join, the class-name parser, modifier sorting,
the class-group trie + conflict tables, and the complete Tailwind v4 default
config (theme scales, ~300 class groups, conflict maps). Behaviour is verified
against the upstream `tailwind-merge` parity suite (see `test/`).

Not ported (out of scope): cnfast's `cnfast migrate` CLI and its V8-specific
performance layers (the tagged-template identity cache, integer interning of
conflict keys, monomorphic-shape and LRU micro-optimizations). Those are
JS-engine tuning that has no meaning in a pure dual-target Gleam library; the
merge result is identical without them.

## Development

```bash
gleam test                      # Erlang target
gleam test --target javascript  # JS target
gleam format src test
```
