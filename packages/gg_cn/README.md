# gg_cn

A **pure-Gleam `tailwind-merge`** — resolves conflicting Tailwind CSS utility
classes by keeping the last one per conflict group, so `px-2 px-4` collapses to
`px-4`. Ported from [cnfast](https://github.com/aidenybai/cnfast)'s logic engine
(itself a faithful reimplementation of `tailwind-merge` v4).

It is **pure Gleam, no FFI**, so it compiles and behaves identically on **both**
the JavaScript and Erlang targets.

> **Backs `gg_ui`'s `cn`.** `gg_base_ui/helpers/cn` (used by `gg_ui` and the
> components it ships) is `clsx + tailwind-merge` built on `gg_cn`, so a
> consumer's `class` override resolves against a component's raw structural
> utilities. `gg_cn` itself is framework-agnostic (no Lustre dependency) and can
> also be used standalone anywhere you mix raw Tailwind and need conflict
> resolution.

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
reuse it on hot paths rather than rebuilding per merge. For render-time use,
prefer `gg_cn.default()` — a process-global `Merger` built once (persistent_term
on the BEAM, a singleton on JS). The configuration is the baked-in Tailwind v4
default; it is not (yet) configurable.

`tw_merge` also memoizes by input string: a whole-string result LRU (size 500,
two-generation), **JS only** — that's where the same class strings get merged
repeatedly (a Lustre `view` re-running). On the BEAM it recomputes (SSR renders
once). Because the cache only changes speed, JS-cached and BEAM-uncached emit
identical bytes, so it stays dual-target-safe.

## What was ported, and what was not

Ported: the full `clsx`/`twJoin` join, the class-name parser, modifier sorting,
the class-group trie + conflict tables, the complete Tailwind v4 default config
(theme scales, ~300 class groups, conflict maps), and a whole-string result LRU
(JS only — see above). Behaviour is verified against the upstream
`tailwind-merge` parity suite (see `test/`).

Not ported (out of scope): cnfast's `cnfast migrate` CLI and its remaining
V8-specific micro-optimizations (the tagged-template identity cache, integer
interning of conflict keys, monomorphic-shape factories). Those are JS-engine
tuning with no meaning in a pure dual-target Gleam library; the merge result is
identical without them.

## Development

```bash
gleam test                      # Erlang target
gleam test --target javascript  # JS target
gleam format src test
```
