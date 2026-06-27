//// The baked-in Tailwind CSS v4 merge configuration — theme scales, class
//// groups, and the conflict tables.
////
//// Ported faithfully from cnfast's `src/lib/default-config.ts` (which itself
//// tracks tailwind-merge's default config). A `ClassDef` is the Gleam analogue
//// of tailwind-merge's class-definition union (`string | validator | theme
//// getter | nested object`); the validator closures capture the compiled
//// `Regexes` so a merge never recompiles a pattern.

import gg_cn/internal/validators.{type Regexes} as v
import gleam/dict.{type Dict}
import gleam/list

pub type ClassDef {
  /// A literal class part (`"block"`); `""` targets the current trie node.
  Lit(String)
  /// A validator for a dynamic/arbitrary part.
  Val(fn(String) -> Bool)
  /// A reference to a theme scale by key, resolved when the trie is built.
  Theme(String)
  /// A nested object: each `#(key, defs)` descends into `key` (split on `-`).
  Obj(List(#(String, List(ClassDef))))
}

pub type Config {
  Config(
    theme: Dict(String, List(ClassDef)),
    class_groups: List(#(String, List(ClassDef))),
    conflicting_class_groups: Dict(String, List(String)),
    conflicting_class_group_modifiers: Dict(String, List(String)),
    postfix_lookup_class_groups: List(String),
    order_sensitive_modifiers: List(String),
  )
}

pub fn default_config(rx: Regexes) -> Config {
  Config(
    theme: default_theme(rx),
    class_groups: default_class_groups(rx),
    conflicting_class_groups: dict.from_list(conflicting_class_groups()),
    conflicting_class_group_modifiers: dict.from_list([
      #("font-size", ["leading"]),
    ]),
    postfix_lookup_class_groups: ["container-type"],
    order_sensitive_modifiers: [
      "*", "**", "after", "backdrop", "before", "details-content", "file",
      "first-letter", "first-line", "marker", "placeholder", "selection",
    ],
  )
}

// --- validator constructors ---------------------------------------------------

fn lits(parts: List(String)) -> List(ClassDef) {
  list.map(parts, Lit)
}

fn vav(rx: Regexes) -> ClassDef {
  Val(fn(s) { v.is_arbitrary_variable(rx, s) })
}

fn vaval(rx: Regexes) -> ClassDef {
  Val(fn(s) { v.is_arbitrary_value(rx, s) })
}

fn vnum(rx: Regexes) -> ClassDef {
  Val(fn(s) { v.is_number(rx, s) })
}

fn vint(rx: Regexes) -> ClassDef {
  Val(fn(s) { v.is_integer(rx, s) })
}

fn vfrac(rx: Regexes) -> ClassDef {
  Val(fn(s) { v.is_fraction(rx, s) })
}

fn vpct(rx: Regexes) -> ClassDef {
  Val(fn(s) { v.is_percent(rx, s) })
}

fn vtshirt(rx: Regexes) -> ClassDef {
  Val(fn(s) { v.is_tshirt_size(rx, s) })
}

fn vany() -> ClassDef {
  Val(v.is_any)
}

fn vanynon(rx: Regexes) -> ClassDef {
  Val(fn(s) { v.is_any_non_arbitrary(rx, s) })
}

fn vnamedcq() -> ClassDef {
  Val(v.is_named_container_query)
}

fn valen(rx: Regexes) -> ClassDef {
  Val(fn(s) { v.is_arbitrary_length(rx, s) })
}

fn vavlen(rx: Regexes) -> ClassDef {
  Val(fn(s) { v.is_arbitrary_variable_length(rx, s) })
}

fn vanum(rx: Regexes) -> ClassDef {
  Val(fn(s) { v.is_arbitrary_number(rx, s) })
}

fn vaweight(rx: Regexes) -> ClassDef {
  Val(fn(s) { v.is_arbitrary_weight(rx, s) })
}

fn vavweight(rx: Regexes) -> ClassDef {
  Val(fn(s) { v.is_arbitrary_variable_weight(rx, s) })
}

fn vafam(rx: Regexes) -> ClassDef {
  Val(fn(s) { v.is_arbitrary_family_name(rx, s) })
}

fn vavfam(rx: Regexes) -> ClassDef {
  Val(fn(s) { v.is_arbitrary_variable_family_name(rx, s) })
}

fn vapos(rx: Regexes) -> ClassDef {
  Val(fn(s) { v.is_arbitrary_position(rx, s) })
}

fn vavpos(rx: Regexes) -> ClassDef {
  Val(fn(s) { v.is_arbitrary_variable_position(rx, s) })
}

fn vaimg(rx: Regexes) -> ClassDef {
  Val(fn(s) { v.is_arbitrary_image(rx, s) })
}

fn vavimg(rx: Regexes) -> ClassDef {
  Val(fn(s) { v.is_arbitrary_variable_image(rx, s) })
}

fn vashadow(rx: Regexes) -> ClassDef {
  Val(fn(s) { v.is_arbitrary_shadow(rx, s) })
}

fn vavshadow(rx: Regexes) -> ClassDef {
  Val(fn(s) { v.is_arbitrary_variable_shadow(rx, s) })
}

fn vasize(rx: Regexes) -> ClassDef {
  Val(fn(s) { v.is_arbitrary_size(rx, s) })
}

fn vavsize(rx: Regexes) -> ClassDef {
  Val(fn(s) { v.is_arbitrary_variable_size(rx, s) })
}

// --- scales -------------------------------------------------------------------

fn scale_break() -> List(ClassDef) {
  lits(["auto", "avoid", "all", "avoid-page", "page", "left", "right", "column"])
}

fn scale_position() -> List(ClassDef) {
  lits([
    "center", "top", "bottom", "left", "right", "top-left", "left-top",
    "top-right", "right-top", "bottom-right", "right-bottom", "bottom-left",
    "left-bottom",
  ])
}

fn scale_position_with_arbitrary(rx: Regexes) -> List(ClassDef) {
  list.append(scale_position(), [vav(rx), vaval(rx)])
}

fn scale_overflow() -> List(ClassDef) {
  lits(["auto", "hidden", "clip", "visible", "scroll"])
}

fn scale_overscroll() -> List(ClassDef) {
  lits(["auto", "contain", "none"])
}

fn scale_unambiguous_spacing(rx: Regexes) -> List(ClassDef) {
  [vav(rx), vaval(rx), Theme("spacing")]
}

fn scale_inset(rx: Regexes) -> List(ClassDef) {
  list.append(
    [vfrac(rx), Lit("full"), Lit("auto")],
    scale_unambiguous_spacing(rx),
  )
}

fn scale_grid_template_cols_rows(rx: Regexes) -> List(ClassDef) {
  [vint(rx), Lit("none"), Lit("subgrid"), vav(rx), vaval(rx)]
}

fn scale_grid_col_row_start_and_end(rx: Regexes) -> List(ClassDef) {
  [
    Lit("auto"),
    Obj([#("span", [Lit("full"), vint(rx), vav(rx), vaval(rx)])]),
    vint(rx),
    vav(rx),
    vaval(rx),
  ]
}

fn scale_grid_col_row_start_or_end(rx: Regexes) -> List(ClassDef) {
  [vint(rx), Lit("auto"), vav(rx), vaval(rx)]
}

fn scale_grid_auto_cols_rows(rx: Regexes) -> List(ClassDef) {
  [Lit("auto"), Lit("min"), Lit("max"), Lit("fr"), vav(rx), vaval(rx)]
}

fn scale_align_primary_axis() -> List(ClassDef) {
  lits([
    "start", "end", "center", "between", "around", "evenly", "stretch",
    "baseline", "center-safe", "end-safe",
  ])
}

fn scale_align_secondary_axis() -> List(ClassDef) {
  lits(["start", "end", "center", "stretch", "center-safe", "end-safe"])
}

fn scale_margin(rx: Regexes) -> List(ClassDef) {
  [Lit("auto"), ..scale_unambiguous_spacing(rx)]
}

fn scale_sizing(rx: Regexes) -> List(ClassDef) {
  list.append(
    [
      vfrac(rx),
      Lit("auto"),
      Lit("full"),
      Lit("dvw"),
      Lit("dvh"),
      Lit("lvw"),
      Lit("lvh"),
      Lit("svw"),
      Lit("svh"),
      Lit("min"),
      Lit("max"),
      Lit("fit"),
    ],
    scale_unambiguous_spacing(rx),
  )
}

fn scale_sizing_inline(rx: Regexes) -> List(ClassDef) {
  list.append(
    [
      vfrac(rx),
      Lit("screen"),
      Lit("full"),
      Lit("dvw"),
      Lit("lvw"),
      Lit("svw"),
      Lit("min"),
      Lit("max"),
      Lit("fit"),
    ],
    scale_unambiguous_spacing(rx),
  )
}

fn scale_sizing_block(rx: Regexes) -> List(ClassDef) {
  list.append(
    [
      vfrac(rx),
      Lit("screen"),
      Lit("full"),
      Lit("lh"),
      Lit("dvh"),
      Lit("lvh"),
      Lit("svh"),
      Lit("min"),
      Lit("max"),
      Lit("fit"),
    ],
    scale_unambiguous_spacing(rx),
  )
}

fn scale_color(rx: Regexes) -> List(ClassDef) {
  [Theme("color"), vav(rx), vaval(rx)]
}

fn scale_bg_position(rx: Regexes) -> List(ClassDef) {
  list.append(scale_position(), [
    vavpos(rx),
    vapos(rx),
    Obj([#("position", [vav(rx), vaval(rx)])]),
  ])
}

fn scale_bg_repeat() -> List(ClassDef) {
  [Lit("no-repeat"), Obj([#("repeat", lits(["", "x", "y", "space", "round"]))])]
}

fn scale_bg_size(rx: Regexes) -> List(ClassDef) {
  [
    Lit("auto"),
    Lit("cover"),
    Lit("contain"),
    vavsize(rx),
    vasize(rx),
    Obj([#("size", [vav(rx), vaval(rx)])]),
  ]
}

fn scale_gradient_stop_position(rx: Regexes) -> List(ClassDef) {
  [vpct(rx), vavlen(rx), valen(rx)]
}

fn scale_radius(rx: Regexes) -> List(ClassDef) {
  [Lit(""), Lit("none"), Lit("full"), Theme("radius"), vav(rx), vaval(rx)]
}

fn scale_border_width(rx: Regexes) -> List(ClassDef) {
  [Lit(""), vnum(rx), vavlen(rx), valen(rx)]
}

fn scale_line_style() -> List(ClassDef) {
  lits(["solid", "dashed", "dotted", "double"])
}

fn scale_blend_mode() -> List(ClassDef) {
  lits([
    "normal", "multiply", "screen", "overlay", "darken", "lighten",
    "color-dodge", "color-burn", "hard-light", "soft-light", "difference",
    "exclusion", "hue", "saturation", "color", "luminosity",
  ])
}

fn scale_mask_image_position(rx: Regexes) -> List(ClassDef) {
  [vnum(rx), vpct(rx), vavpos(rx), vapos(rx)]
}

fn scale_blur(rx: Regexes) -> List(ClassDef) {
  [Lit(""), Lit("none"), Theme("blur"), vav(rx), vaval(rx)]
}

fn scale_rotate(rx: Regexes) -> List(ClassDef) {
  [Lit("none"), vnum(rx), vav(rx), vaval(rx)]
}

fn scale_scale(rx: Regexes) -> List(ClassDef) {
  [Lit("none"), vnum(rx), vav(rx), vaval(rx)]
}

fn scale_skew(rx: Regexes) -> List(ClassDef) {
  [vnum(rx), vav(rx), vaval(rx)]
}

fn scale_translate(rx: Regexes) -> List(ClassDef) {
  [vfrac(rx), Lit("full"), ..scale_unambiguous_spacing(rx)]
}

// --- theme --------------------------------------------------------------------

fn default_theme(rx: Regexes) -> Dict(String, List(ClassDef)) {
  dict.from_list([
    #("animate", lits(["spin", "ping", "pulse", "bounce"])),
    #("aspect", lits(["video"])),
    #("blur", [vtshirt(rx)]),
    #("breakpoint", [vtshirt(rx)]),
    #("color", [vany()]),
    #("container", [vtshirt(rx)]),
    #("drop-shadow", [vtshirt(rx)]),
    #("ease", lits(["in", "out", "in-out"])),
    #("font", [vanynon(rx)]),
    #(
      "font-weight",
      lits([
        "thin", "extralight", "light", "normal", "medium", "semibold", "bold",
        "extrabold", "black",
      ]),
    ),
    #("inset-shadow", [vtshirt(rx)]),
    #("leading", lits(["none", "tight", "snug", "normal", "relaxed", "loose"])),
    #(
      "perspective",
      lits(["dramatic", "near", "normal", "midrange", "distant", "none"]),
    ),
    #("radius", [vtshirt(rx)]),
    #("shadow", [vtshirt(rx)]),
    #("spacing", [Lit("px"), vnum(rx)]),
    #("text", [vtshirt(rx)]),
    #("text-shadow", [vtshirt(rx)]),
    #(
      "tracking",
      lits(["tighter", "tight", "normal", "wide", "wider", "widest"]),
    ),
  ])
}

// --- class groups -------------------------------------------------------------

fn default_class_groups(rx: Regexes) -> List(#(String, List(ClassDef))) {
  list.flatten([
    layout(rx),
    flexbox_grid(rx),
    spacing(rx),
    sizing(rx),
    typography(rx),
    backgrounds(rx),
    borders(rx),
    effects(rx),
    filters(rx),
    tables(rx),
    transitions(rx),
    transforms(rx),
    interactivity(rx),
    svg(rx),
    accessibility(),
  ])
}

fn layout(rx: Regexes) -> List(#(String, List(ClassDef))) {
  [
    #("aspect", [
      Obj([
        #("aspect", [
          Lit("auto"),
          Lit("square"),
          vfrac(rx),
          vaval(rx),
          vav(rx),
          Theme("aspect"),
        ]),
      ]),
    ]),
    #("container", lits(["container"])),
    #("container-type", [
      Obj([
        #("@container", [
          Lit(""),
          Lit("normal"),
          Lit("size"),
          vav(rx),
          vaval(rx),
        ]),
      ]),
    ]),
    #("container-named", [vnamedcq()]),
    #("columns", [
      Obj([#("columns", [vnum(rx), vaval(rx), vav(rx), Theme("container")])]),
    ]),
    #("break-after", [Obj([#("break-after", scale_break())])]),
    #("break-before", [Obj([#("break-before", scale_break())])]),
    #("break-inside", [
      Obj([
        #("break-inside", lits(["auto", "avoid", "avoid-page", "avoid-column"])),
      ]),
    ]),
    #("box-decoration", [Obj([#("box-decoration", lits(["slice", "clone"]))])]),
    #("box", [Obj([#("box", lits(["border", "content"]))])]),
    #(
      "display",
      lits([
        "block", "inline-block", "inline", "flex", "inline-flex", "table",
        "inline-table", "table-caption", "table-cell", "table-column",
        "table-column-group", "table-footer-group", "table-header-group",
        "table-row-group", "table-row", "flow-root", "grid", "inline-grid",
        "contents", "list-item", "hidden",
      ]),
    ),
    #("sr", lits(["sr-only", "not-sr-only"])),
    #("float", [
      Obj([#("float", lits(["right", "left", "none", "start", "end"]))]),
    ]),
    #("clear", [
      Obj([#("clear", lits(["left", "right", "both", "none", "start", "end"]))]),
    ]),
    #("isolation", lits(["isolate", "isolation-auto"])),
    #("object-fit", [
      Obj([
        #("object", lits(["contain", "cover", "fill", "none", "scale-down"])),
      ]),
    ]),
    #("object-position", [Obj([#("object", scale_position_with_arbitrary(rx))])]),
    #("overflow", [Obj([#("overflow", scale_overflow())])]),
    #("overflow-x", [Obj([#("overflow-x", scale_overflow())])]),
    #("overflow-y", [Obj([#("overflow-y", scale_overflow())])]),
    #("overscroll", [Obj([#("overscroll", scale_overscroll())])]),
    #("overscroll-x", [Obj([#("overscroll-x", scale_overscroll())])]),
    #("overscroll-y", [Obj([#("overscroll-y", scale_overscroll())])]),
    #("position", lits(["static", "fixed", "absolute", "relative", "sticky"])),
    #("inset", [Obj([#("inset", scale_inset(rx))])]),
    #("inset-x", [Obj([#("inset-x", scale_inset(rx))])]),
    #("inset-y", [Obj([#("inset-y", scale_inset(rx))])]),
    #("start", [
      Obj([#("inset-s", scale_inset(rx)), #("start", scale_inset(rx))]),
    ]),
    #("end", [Obj([#("inset-e", scale_inset(rx)), #("end", scale_inset(rx))])]),
    #("inset-bs", [Obj([#("inset-bs", scale_inset(rx))])]),
    #("inset-be", [Obj([#("inset-be", scale_inset(rx))])]),
    #("top", [Obj([#("top", scale_inset(rx))])]),
    #("right", [Obj([#("right", scale_inset(rx))])]),
    #("bottom", [Obj([#("bottom", scale_inset(rx))])]),
    #("left", [Obj([#("left", scale_inset(rx))])]),
    #("visibility", lits(["visible", "invisible", "collapse"])),
    #("z", [Obj([#("z", [vint(rx), Lit("auto"), vav(rx), vaval(rx)])])]),
  ]
}

fn flexbox_grid(rx: Regexes) -> List(#(String, List(ClassDef))) {
  [
    #("basis", [
      Obj([
        #("basis", [
          vfrac(rx),
          Lit("full"),
          Lit("auto"),
          Theme("container"),
          ..scale_unambiguous_spacing(rx)
        ]),
      ]),
    ]),
    #("flex-direction", [
      Obj([#("flex", lits(["row", "row-reverse", "col", "col-reverse"]))]),
    ]),
    #("flex-wrap", [Obj([#("flex", lits(["nowrap", "wrap", "wrap-reverse"]))])]),
    #("flex", [
      Obj([
        #("flex", [
          vnum(rx),
          vfrac(rx),
          Lit("auto"),
          Lit("initial"),
          Lit("none"),
          vaval(rx),
        ]),
      ]),
    ]),
    #("grow", [Obj([#("grow", [Lit(""), vnum(rx), vav(rx), vaval(rx)])])]),
    #("shrink", [Obj([#("shrink", [Lit(""), vnum(rx), vav(rx), vaval(rx)])])]),
    #("order", [
      Obj([
        #("order", [
          vint(rx),
          Lit("first"),
          Lit("last"),
          Lit("none"),
          vav(rx),
          vaval(rx),
        ]),
      ]),
    ]),
    #("grid-cols", [Obj([#("grid-cols", scale_grid_template_cols_rows(rx))])]),
    #("col-start-end", [Obj([#("col", scale_grid_col_row_start_and_end(rx))])]),
    #("col-start", [Obj([#("col-start", scale_grid_col_row_start_or_end(rx))])]),
    #("col-end", [Obj([#("col-end", scale_grid_col_row_start_or_end(rx))])]),
    #("grid-rows", [Obj([#("grid-rows", scale_grid_template_cols_rows(rx))])]),
    #("row-start-end", [Obj([#("row", scale_grid_col_row_start_and_end(rx))])]),
    #("row-start", [Obj([#("row-start", scale_grid_col_row_start_or_end(rx))])]),
    #("row-end", [Obj([#("row-end", scale_grid_col_row_start_or_end(rx))])]),
    #("grid-flow", [
      Obj([
        #("grid-flow", lits(["row", "col", "dense", "row-dense", "col-dense"])),
      ]),
    ]),
    #("auto-cols", [Obj([#("auto-cols", scale_grid_auto_cols_rows(rx))])]),
    #("auto-rows", [Obj([#("auto-rows", scale_grid_auto_cols_rows(rx))])]),
    #("gap", [Obj([#("gap", scale_unambiguous_spacing(rx))])]),
    #("gap-x", [Obj([#("gap-x", scale_unambiguous_spacing(rx))])]),
    #("gap-y", [Obj([#("gap-y", scale_unambiguous_spacing(rx))])]),
    #("justify-content", [
      Obj([#("justify", [Lit("normal"), ..scale_align_primary_axis()])]),
    ]),
    #("justify-items", [
      Obj([#("justify-items", [Lit("normal"), ..scale_align_secondary_axis()])]),
    ]),
    #("justify-self", [
      Obj([#("justify-self", [Lit("auto"), ..scale_align_secondary_axis()])]),
    ]),
    #("align-content", [
      Obj([#("content", [Lit("normal"), ..scale_align_primary_axis()])]),
    ]),
    #("align-items", [
      Obj([
        #(
          "items",
          list.append(scale_align_secondary_axis(), [
            Obj([#("baseline", [Lit(""), Lit("last")])]),
          ]),
        ),
      ]),
    ]),
    #("align-self", [
      Obj([
        #(
          "self",
          list.append([Lit("auto"), ..scale_align_secondary_axis()], [
            Obj([#("baseline", [Lit(""), Lit("last")])]),
          ]),
        ),
      ]),
    ]),
    #("place-content", [Obj([#("place-content", scale_align_primary_axis())])]),
    #("place-items", [
      Obj([#("place-items", [Lit("baseline"), ..scale_align_secondary_axis()])]),
    ]),
    #("place-self", [
      Obj([#("place-self", [Lit("auto"), ..scale_align_secondary_axis()])]),
    ]),
  ]
}

fn spacing(rx: Regexes) -> List(#(String, List(ClassDef))) {
  [
    #("p", [Obj([#("p", scale_unambiguous_spacing(rx))])]),
    #("px", [Obj([#("px", scale_unambiguous_spacing(rx))])]),
    #("py", [Obj([#("py", scale_unambiguous_spacing(rx))])]),
    #("ps", [Obj([#("ps", scale_unambiguous_spacing(rx))])]),
    #("pe", [Obj([#("pe", scale_unambiguous_spacing(rx))])]),
    #("pbs", [Obj([#("pbs", scale_unambiguous_spacing(rx))])]),
    #("pbe", [Obj([#("pbe", scale_unambiguous_spacing(rx))])]),
    #("pt", [Obj([#("pt", scale_unambiguous_spacing(rx))])]),
    #("pr", [Obj([#("pr", scale_unambiguous_spacing(rx))])]),
    #("pb", [Obj([#("pb", scale_unambiguous_spacing(rx))])]),
    #("pl", [Obj([#("pl", scale_unambiguous_spacing(rx))])]),
    #("m", [Obj([#("m", scale_margin(rx))])]),
    #("mx", [Obj([#("mx", scale_margin(rx))])]),
    #("my", [Obj([#("my", scale_margin(rx))])]),
    #("ms", [Obj([#("ms", scale_margin(rx))])]),
    #("me", [Obj([#("me", scale_margin(rx))])]),
    #("mbs", [Obj([#("mbs", scale_margin(rx))])]),
    #("mbe", [Obj([#("mbe", scale_margin(rx))])]),
    #("mt", [Obj([#("mt", scale_margin(rx))])]),
    #("mr", [Obj([#("mr", scale_margin(rx))])]),
    #("mb", [Obj([#("mb", scale_margin(rx))])]),
    #("ml", [Obj([#("ml", scale_margin(rx))])]),
    #("space-x", [Obj([#("space-x", scale_unambiguous_spacing(rx))])]),
    #("space-x-reverse", lits(["space-x-reverse"])),
    #("space-y", [Obj([#("space-y", scale_unambiguous_spacing(rx))])]),
    #("space-y-reverse", lits(["space-y-reverse"])),
  ]
}

fn sizing(rx: Regexes) -> List(#(String, List(ClassDef))) {
  [
    #("size", [Obj([#("size", scale_sizing(rx))])]),
    #("inline-size", [
      Obj([#("inline", [Lit("auto"), ..scale_sizing_inline(rx)])]),
    ]),
    #("min-inline-size", [
      Obj([#("min-inline", [Lit("auto"), ..scale_sizing_inline(rx)])]),
    ]),
    #("max-inline-size", [
      Obj([#("max-inline", [Lit("none"), ..scale_sizing_inline(rx)])]),
    ]),
    #("block-size", [Obj([#("block", [Lit("auto"), ..scale_sizing_block(rx)])])]),
    #("min-block-size", [
      Obj([#("min-block", [Lit("auto"), ..scale_sizing_block(rx)])]),
    ]),
    #("max-block-size", [
      Obj([#("max-block", [Lit("none"), ..scale_sizing_block(rx)])]),
    ]),
    #("w", [
      Obj([#("w", [Theme("container"), Lit("screen"), ..scale_sizing(rx)])]),
    ]),
    #("min-w", [
      Obj([
        #("min-w", [
          Theme("container"),
          Lit("screen"),
          Lit("none"),
          ..scale_sizing(rx)
        ]),
      ]),
    ]),
    #("max-w", [
      Obj([
        #("max-w", [
          Theme("container"),
          Lit("screen"),
          Lit("none"),
          Lit("prose"),
          Obj([#("screen", [Theme("breakpoint")])]),
          ..scale_sizing(rx)
        ]),
      ]),
    ]),
    #("h", [Obj([#("h", [Lit("screen"), Lit("lh"), ..scale_sizing(rx)])])]),
    #("min-h", [
      Obj([
        #("min-h", [Lit("screen"), Lit("lh"), Lit("none"), ..scale_sizing(rx)]),
      ]),
    ]),
    #("max-h", [
      Obj([#("max-h", [Lit("screen"), Lit("lh"), ..scale_sizing(rx)])]),
    ]),
  ]
}

fn typography(rx: Regexes) -> List(#(String, List(ClassDef))) {
  [
    #("font-size", [
      Obj([#("text", [Lit("base"), Theme("text"), vavlen(rx), valen(rx)])]),
    ]),
    #("font-smoothing", lits(["antialiased", "subpixel-antialiased"])),
    #("font-style", lits(["italic", "not-italic"])),
    #("font-weight", [
      Obj([#("font", [Theme("font-weight"), vavweight(rx), vaweight(rx)])]),
    ]),
    #("font-stretch", [
      Obj([
        #("font-stretch", [
          Lit("ultra-condensed"),
          Lit("extra-condensed"),
          Lit("condensed"),
          Lit("semi-condensed"),
          Lit("normal"),
          Lit("semi-expanded"),
          Lit("expanded"),
          Lit("extra-expanded"),
          Lit("ultra-expanded"),
          vpct(rx),
          vaval(rx),
        ]),
      ]),
    ]),
    #("font-family", [
      Obj([#("font", [vavfam(rx), vafam(rx), Theme("font")])]),
    ]),
    #("font-features", [Obj([#("font-features", [vaval(rx)])])]),
    #("fvn-normal", lits(["normal-nums"])),
    #("fvn-ordinal", lits(["ordinal"])),
    #("fvn-slashed-zero", lits(["slashed-zero"])),
    #("fvn-figure", lits(["lining-nums", "oldstyle-nums"])),
    #("fvn-spacing", lits(["proportional-nums", "tabular-nums"])),
    #("fvn-fraction", lits(["diagonal-fractions", "stacked-fractions"])),
    #("tracking", [
      Obj([#("tracking", [Theme("tracking"), vav(rx), vaval(rx)])]),
    ]),
    #("line-clamp", [
      Obj([#("line-clamp", [vnum(rx), Lit("none"), vav(rx), vanum(rx)])]),
    ]),
    #("leading", [
      Obj([#("leading", [Theme("leading"), ..scale_unambiguous_spacing(rx)])]),
    ]),
    #("list-image", [
      Obj([#("list-image", [Lit("none"), vav(rx), vaval(rx)])]),
    ]),
    #("list-style-position", [Obj([#("list", lits(["inside", "outside"]))])]),
    #("list-style-type", [
      Obj([
        #("list", [Lit("disc"), Lit("decimal"), Lit("none"), vav(rx), vaval(rx)]),
      ]),
    ]),
    #("text-alignment", [
      Obj([
        #("text", lits(["left", "center", "right", "justify", "start", "end"])),
      ]),
    ]),
    #("placeholder-color", [Obj([#("placeholder", scale_color(rx))])]),
    #("text-color", [Obj([#("text", scale_color(rx))])]),
    #(
      "text-decoration",
      lits(["underline", "overline", "line-through", "no-underline"]),
    ),
    #("text-decoration-style", [
      Obj([#("decoration", [Lit("wavy"), ..scale_line_style()])]),
    ]),
    #("text-decoration-thickness", [
      Obj([
        #("decoration", [
          vnum(rx),
          Lit("from-font"),
          Lit("auto"),
          vav(rx),
          valen(rx),
        ]),
      ]),
    ]),
    #("text-decoration-color", [Obj([#("decoration", scale_color(rx))])]),
    #("underline-offset", [
      Obj([#("underline-offset", [vnum(rx), Lit("auto"), vav(rx), vaval(rx)])]),
    ]),
    #(
      "text-transform",
      lits(["uppercase", "lowercase", "capitalize", "normal-case"]),
    ),
    #("text-overflow", lits(["truncate", "text-ellipsis", "text-clip"])),
    #("text-wrap", [
      Obj([#("text", lits(["wrap", "nowrap", "balance", "pretty"]))]),
    ]),
    #("indent", [Obj([#("indent", scale_unambiguous_spacing(rx))])]),
    #("tab-size", [Obj([#("tab", [vint(rx), vav(rx), vaval(rx)])])]),
    #("vertical-align", [
      Obj([
        #("align", [
          Lit("baseline"),
          Lit("top"),
          Lit("middle"),
          Lit("bottom"),
          Lit("text-top"),
          Lit("text-bottom"),
          Lit("sub"),
          Lit("super"),
          vav(rx),
          vaval(rx),
        ]),
      ]),
    ]),
    #("whitespace", [
      Obj([
        #(
          "whitespace",
          lits([
            "normal", "nowrap", "pre", "pre-line", "pre-wrap", "break-spaces",
          ]),
        ),
      ]),
    ]),
    #("break", [Obj([#("break", lits(["normal", "words", "all", "keep"]))])]),
    #("wrap", [Obj([#("wrap", lits(["break-word", "anywhere", "normal"]))])]),
    #("hyphens", [Obj([#("hyphens", lits(["none", "manual", "auto"]))])]),
    #("content", [Obj([#("content", [Lit("none"), vav(rx), vaval(rx)])])]),
  ]
}

fn backgrounds(rx: Regexes) -> List(#(String, List(ClassDef))) {
  [
    #("bg-attachment", [Obj([#("bg", lits(["fixed", "local", "scroll"]))])]),
    #("bg-clip", [
      Obj([#("bg-clip", lits(["border", "padding", "content", "text"]))]),
    ]),
    #("bg-origin", [
      Obj([#("bg-origin", lits(["border", "padding", "content"]))]),
    ]),
    #("bg-position", [Obj([#("bg", scale_bg_position(rx))])]),
    #("bg-repeat", [Obj([#("bg", scale_bg_repeat())])]),
    #("bg-size", [Obj([#("bg", scale_bg_size(rx))])]),
    #("bg-image", [
      Obj([
        #("bg", [
          Lit("none"),
          Obj([
            #("linear", [
              Obj([#("to", lits(["t", "tr", "r", "br", "b", "bl", "l", "tl"]))]),
              vint(rx),
              vav(rx),
              vaval(rx),
            ]),
            #("radial", [Lit(""), vav(rx), vaval(rx)]),
            #("conic", [vint(rx), vav(rx), vaval(rx)]),
          ]),
          vavimg(rx),
          vaimg(rx),
        ]),
      ]),
    ]),
    #("bg-color", [Obj([#("bg", scale_color(rx))])]),
    #("gradient-from-pos", [Obj([#("from", scale_gradient_stop_position(rx))])]),
    #("gradient-via-pos", [Obj([#("via", scale_gradient_stop_position(rx))])]),
    #("gradient-to-pos", [Obj([#("to", scale_gradient_stop_position(rx))])]),
    #("gradient-from", [Obj([#("from", scale_color(rx))])]),
    #("gradient-via", [Obj([#("via", scale_color(rx))])]),
    #("gradient-to", [Obj([#("to", scale_color(rx))])]),
  ]
}

fn borders(rx: Regexes) -> List(#(String, List(ClassDef))) {
  [
    #("rounded", [Obj([#("rounded", scale_radius(rx))])]),
    #("rounded-s", [Obj([#("rounded-s", scale_radius(rx))])]),
    #("rounded-e", [Obj([#("rounded-e", scale_radius(rx))])]),
    #("rounded-t", [Obj([#("rounded-t", scale_radius(rx))])]),
    #("rounded-r", [Obj([#("rounded-r", scale_radius(rx))])]),
    #("rounded-b", [Obj([#("rounded-b", scale_radius(rx))])]),
    #("rounded-l", [Obj([#("rounded-l", scale_radius(rx))])]),
    #("rounded-ss", [Obj([#("rounded-ss", scale_radius(rx))])]),
    #("rounded-se", [Obj([#("rounded-se", scale_radius(rx))])]),
    #("rounded-ee", [Obj([#("rounded-ee", scale_radius(rx))])]),
    #("rounded-es", [Obj([#("rounded-es", scale_radius(rx))])]),
    #("rounded-tl", [Obj([#("rounded-tl", scale_radius(rx))])]),
    #("rounded-tr", [Obj([#("rounded-tr", scale_radius(rx))])]),
    #("rounded-br", [Obj([#("rounded-br", scale_radius(rx))])]),
    #("rounded-bl", [Obj([#("rounded-bl", scale_radius(rx))])]),
    #("border-w", [Obj([#("border", scale_border_width(rx))])]),
    #("border-w-x", [Obj([#("border-x", scale_border_width(rx))])]),
    #("border-w-y", [Obj([#("border-y", scale_border_width(rx))])]),
    #("border-w-s", [Obj([#("border-s", scale_border_width(rx))])]),
    #("border-w-e", [Obj([#("border-e", scale_border_width(rx))])]),
    #("border-w-bs", [Obj([#("border-bs", scale_border_width(rx))])]),
    #("border-w-be", [Obj([#("border-be", scale_border_width(rx))])]),
    #("border-w-t", [Obj([#("border-t", scale_border_width(rx))])]),
    #("border-w-r", [Obj([#("border-r", scale_border_width(rx))])]),
    #("border-w-b", [Obj([#("border-b", scale_border_width(rx))])]),
    #("border-w-l", [Obj([#("border-l", scale_border_width(rx))])]),
    #("divide-x", [Obj([#("divide-x", scale_border_width(rx))])]),
    #("divide-x-reverse", lits(["divide-x-reverse"])),
    #("divide-y", [Obj([#("divide-y", scale_border_width(rx))])]),
    #("divide-y-reverse", lits(["divide-y-reverse"])),
    #("border-style", [
      Obj([#("border", [Lit("hidden"), Lit("none"), ..scale_line_style()])]),
    ]),
    #("divide-style", [
      Obj([#("divide", [Lit("hidden"), Lit("none"), ..scale_line_style()])]),
    ]),
    #("border-color", [Obj([#("border", scale_color(rx))])]),
    #("border-color-x", [Obj([#("border-x", scale_color(rx))])]),
    #("border-color-y", [Obj([#("border-y", scale_color(rx))])]),
    #("border-color-s", [Obj([#("border-s", scale_color(rx))])]),
    #("border-color-e", [Obj([#("border-e", scale_color(rx))])]),
    #("border-color-bs", [Obj([#("border-bs", scale_color(rx))])]),
    #("border-color-be", [Obj([#("border-be", scale_color(rx))])]),
    #("border-color-t", [Obj([#("border-t", scale_color(rx))])]),
    #("border-color-r", [Obj([#("border-r", scale_color(rx))])]),
    #("border-color-b", [Obj([#("border-b", scale_color(rx))])]),
    #("border-color-l", [Obj([#("border-l", scale_color(rx))])]),
    #("divide-color", [Obj([#("divide", scale_color(rx))])]),
    #("outline-style", [
      Obj([#("outline", [Lit("none"), Lit("hidden"), ..scale_line_style()])]),
    ]),
    #("outline-offset", [
      Obj([#("outline-offset", [vnum(rx), vav(rx), vaval(rx)])]),
    ]),
    #("outline-w", [
      Obj([#("outline", [Lit(""), vnum(rx), vavlen(rx), valen(rx)])]),
    ]),
    #("outline-color", [Obj([#("outline", scale_color(rx))])]),
  ]
}

fn effects(rx: Regexes) -> List(#(String, List(ClassDef))) {
  [
    #("shadow", [
      Obj([
        #("shadow", [
          Lit(""),
          Lit("none"),
          Theme("shadow"),
          vavshadow(rx),
          vashadow(rx),
        ]),
      ]),
    ]),
    #("shadow-color", [Obj([#("shadow", scale_color(rx))])]),
    #("inset-shadow", [
      Obj([
        #("inset-shadow", [
          Lit("none"),
          Theme("inset-shadow"),
          vavshadow(rx),
          vashadow(rx),
        ]),
      ]),
    ]),
    #("inset-shadow-color", [Obj([#("inset-shadow", scale_color(rx))])]),
    #("ring-w", [Obj([#("ring", scale_border_width(rx))])]),
    #("ring-w-inset", lits(["ring-inset"])),
    #("ring-color", [Obj([#("ring", scale_color(rx))])]),
    #("ring-offset-w", [Obj([#("ring-offset", [vnum(rx), valen(rx)])])]),
    #("ring-offset-color", [Obj([#("ring-offset", scale_color(rx))])]),
    #("inset-ring-w", [Obj([#("inset-ring", scale_border_width(rx))])]),
    #("inset-ring-color", [Obj([#("inset-ring", scale_color(rx))])]),
    #("text-shadow", [
      Obj([
        #("text-shadow", [
          Lit("none"),
          Theme("text-shadow"),
          vavshadow(rx),
          vashadow(rx),
        ]),
      ]),
    ]),
    #("text-shadow-color", [Obj([#("text-shadow", scale_color(rx))])]),
    #("opacity", [Obj([#("opacity", [vnum(rx), vav(rx), vaval(rx)])])]),
    #("mix-blend", [
      Obj([
        #("mix-blend", [
          Lit("plus-darker"),
          Lit("plus-lighter"),
          ..scale_blend_mode()
        ]),
      ]),
    ]),
    #("bg-blend", [Obj([#("bg-blend", scale_blend_mode())])]),
    #("mask-clip", [
      Obj([
        #(
          "mask-clip",
          lits(["border", "padding", "content", "fill", "stroke", "view"]),
        ),
      ]),
      Lit("mask-no-clip"),
    ]),
    #("mask-composite", [
      Obj([#("mask", lits(["add", "subtract", "intersect", "exclude"]))]),
    ]),
    #("mask-image-linear-pos", [Obj([#("mask-linear", [vnum(rx)])])]),
    #("mask-image-linear-from-pos", [
      Obj([#("mask-linear-from", scale_mask_image_position(rx))]),
    ]),
    #("mask-image-linear-to-pos", [
      Obj([#("mask-linear-to", scale_mask_image_position(rx))]),
    ]),
    #("mask-image-linear-from-color", [
      Obj([#("mask-linear-from", scale_color(rx))]),
    ]),
    #("mask-image-linear-to-color", [
      Obj([#("mask-linear-to", scale_color(rx))]),
    ]),
    #("mask-image-t-from-pos", [
      Obj([#("mask-t-from", scale_mask_image_position(rx))]),
    ]),
    #("mask-image-t-to-pos", [
      Obj([#("mask-t-to", scale_mask_image_position(rx))]),
    ]),
    #("mask-image-t-from-color", [Obj([#("mask-t-from", scale_color(rx))])]),
    #("mask-image-t-to-color", [Obj([#("mask-t-to", scale_color(rx))])]),
    #("mask-image-r-from-pos", [
      Obj([#("mask-r-from", scale_mask_image_position(rx))]),
    ]),
    #("mask-image-r-to-pos", [
      Obj([#("mask-r-to", scale_mask_image_position(rx))]),
    ]),
    #("mask-image-r-from-color", [Obj([#("mask-r-from", scale_color(rx))])]),
    #("mask-image-r-to-color", [Obj([#("mask-r-to", scale_color(rx))])]),
    #("mask-image-b-from-pos", [
      Obj([#("mask-b-from", scale_mask_image_position(rx))]),
    ]),
    #("mask-image-b-to-pos", [
      Obj([#("mask-b-to", scale_mask_image_position(rx))]),
    ]),
    #("mask-image-b-from-color", [Obj([#("mask-b-from", scale_color(rx))])]),
    #("mask-image-b-to-color", [Obj([#("mask-b-to", scale_color(rx))])]),
    #("mask-image-l-from-pos", [
      Obj([#("mask-l-from", scale_mask_image_position(rx))]),
    ]),
    #("mask-image-l-to-pos", [
      Obj([#("mask-l-to", scale_mask_image_position(rx))]),
    ]),
    #("mask-image-l-from-color", [Obj([#("mask-l-from", scale_color(rx))])]),
    #("mask-image-l-to-color", [Obj([#("mask-l-to", scale_color(rx))])]),
    #("mask-image-x-from-pos", [
      Obj([#("mask-x-from", scale_mask_image_position(rx))]),
    ]),
    #("mask-image-x-to-pos", [
      Obj([#("mask-x-to", scale_mask_image_position(rx))]),
    ]),
    #("mask-image-x-from-color", [Obj([#("mask-x-from", scale_color(rx))])]),
    #("mask-image-x-to-color", [Obj([#("mask-x-to", scale_color(rx))])]),
    #("mask-image-y-from-pos", [
      Obj([#("mask-y-from", scale_mask_image_position(rx))]),
    ]),
    #("mask-image-y-to-pos", [
      Obj([#("mask-y-to", scale_mask_image_position(rx))]),
    ]),
    #("mask-image-y-from-color", [Obj([#("mask-y-from", scale_color(rx))])]),
    #("mask-image-y-to-color", [Obj([#("mask-y-to", scale_color(rx))])]),
    #("mask-image-radial", [Obj([#("mask-radial", [vav(rx), vaval(rx)])])]),
    #("mask-image-radial-from-pos", [
      Obj([#("mask-radial-from", scale_mask_image_position(rx))]),
    ]),
    #("mask-image-radial-to-pos", [
      Obj([#("mask-radial-to", scale_mask_image_position(rx))]),
    ]),
    #("mask-image-radial-from-color", [
      Obj([#("mask-radial-from", scale_color(rx))]),
    ]),
    #("mask-image-radial-to-color", [
      Obj([#("mask-radial-to", scale_color(rx))]),
    ]),
    #("mask-image-radial-shape", [
      Obj([#("mask-radial", lits(["circle", "ellipse"]))]),
    ]),
    #("mask-image-radial-size", [
      Obj([
        #("mask-radial", [
          Obj([
            #("closest", lits(["side", "corner"])),
            #("farthest", lits(["side", "corner"])),
          ]),
        ]),
      ]),
    ]),
    #("mask-image-radial-pos", [Obj([#("mask-radial-at", scale_position())])]),
    #("mask-image-conic-pos", [Obj([#("mask-conic", [vnum(rx)])])]),
    #("mask-image-conic-from-pos", [
      Obj([#("mask-conic-from", scale_mask_image_position(rx))]),
    ]),
    #("mask-image-conic-to-pos", [
      Obj([#("mask-conic-to", scale_mask_image_position(rx))]),
    ]),
    #("mask-image-conic-from-color", [
      Obj([#("mask-conic-from", scale_color(rx))]),
    ]),
    #("mask-image-conic-to-color", [Obj([#("mask-conic-to", scale_color(rx))])]),
    #("mask-mode", [Obj([#("mask", lits(["alpha", "luminance", "match"]))])]),
    #("mask-origin", [
      Obj([
        #(
          "mask-origin",
          lits(["border", "padding", "content", "fill", "stroke", "view"]),
        ),
      ]),
    ]),
    #("mask-position", [Obj([#("mask", scale_bg_position(rx))])]),
    #("mask-repeat", [Obj([#("mask", scale_bg_repeat())])]),
    #("mask-size", [Obj([#("mask", scale_bg_size(rx))])]),
    #("mask-type", [Obj([#("mask-type", lits(["alpha", "luminance"]))])]),
    #("mask-image", [Obj([#("mask", [Lit("none"), vav(rx), vaval(rx)])])]),
  ]
}

fn filters(rx: Regexes) -> List(#(String, List(ClassDef))) {
  [
    #("filter", [
      Obj([#("filter", [Lit(""), Lit("none"), vav(rx), vaval(rx)])]),
    ]),
    #("blur", [Obj([#("blur", scale_blur(rx))])]),
    #("brightness", [Obj([#("brightness", [vnum(rx), vav(rx), vaval(rx)])])]),
    #("contrast", [Obj([#("contrast", [vnum(rx), vav(rx), vaval(rx)])])]),
    #("drop-shadow", [
      Obj([
        #("drop-shadow", [
          Lit(""),
          Lit("none"),
          Theme("drop-shadow"),
          vavshadow(rx),
          vashadow(rx),
        ]),
      ]),
    ]),
    #("drop-shadow-color", [Obj([#("drop-shadow", scale_color(rx))])]),
    #("grayscale", [
      Obj([#("grayscale", [Lit(""), vnum(rx), vav(rx), vaval(rx)])]),
    ]),
    #("hue-rotate", [Obj([#("hue-rotate", [vnum(rx), vav(rx), vaval(rx)])])]),
    #("invert", [Obj([#("invert", [Lit(""), vnum(rx), vav(rx), vaval(rx)])])]),
    #("saturate", [Obj([#("saturate", [vnum(rx), vav(rx), vaval(rx)])])]),
    #("sepia", [Obj([#("sepia", [Lit(""), vnum(rx), vav(rx), vaval(rx)])])]),
    #("backdrop-filter", [
      Obj([#("backdrop-filter", [Lit(""), Lit("none"), vav(rx), vaval(rx)])]),
    ]),
    #("backdrop-blur", [Obj([#("backdrop-blur", scale_blur(rx))])]),
    #("backdrop-brightness", [
      Obj([#("backdrop-brightness", [vnum(rx), vav(rx), vaval(rx)])]),
    ]),
    #("backdrop-contrast", [
      Obj([#("backdrop-contrast", [vnum(rx), vav(rx), vaval(rx)])]),
    ]),
    #("backdrop-grayscale", [
      Obj([#("backdrop-grayscale", [Lit(""), vnum(rx), vav(rx), vaval(rx)])]),
    ]),
    #("backdrop-hue-rotate", [
      Obj([#("backdrop-hue-rotate", [vnum(rx), vav(rx), vaval(rx)])]),
    ]),
    #("backdrop-invert", [
      Obj([#("backdrop-invert", [Lit(""), vnum(rx), vav(rx), vaval(rx)])]),
    ]),
    #("backdrop-opacity", [
      Obj([#("backdrop-opacity", [vnum(rx), vav(rx), vaval(rx)])]),
    ]),
    #("backdrop-saturate", [
      Obj([#("backdrop-saturate", [vnum(rx), vav(rx), vaval(rx)])]),
    ]),
    #("backdrop-sepia", [
      Obj([#("backdrop-sepia", [Lit(""), vnum(rx), vav(rx), vaval(rx)])]),
    ]),
  ]
}

fn tables(rx: Regexes) -> List(#(String, List(ClassDef))) {
  [
    #("border-collapse", [Obj([#("border", lits(["collapse", "separate"]))])]),
    #("border-spacing", [
      Obj([#("border-spacing", scale_unambiguous_spacing(rx))]),
    ]),
    #("border-spacing-x", [
      Obj([#("border-spacing-x", scale_unambiguous_spacing(rx))]),
    ]),
    #("border-spacing-y", [
      Obj([#("border-spacing-y", scale_unambiguous_spacing(rx))]),
    ]),
    #("table-layout", [Obj([#("table", lits(["auto", "fixed"]))])]),
    #("caption", [Obj([#("caption", lits(["top", "bottom"]))])]),
  ]
}

fn transitions(rx: Regexes) -> List(#(String, List(ClassDef))) {
  [
    #("transition", [
      Obj([
        #("transition", [
          Lit(""),
          Lit("all"),
          Lit("colors"),
          Lit("opacity"),
          Lit("shadow"),
          Lit("transform"),
          Lit("none"),
          vav(rx),
          vaval(rx),
        ]),
      ]),
    ]),
    #("transition-behavior", [
      Obj([#("transition", lits(["normal", "discrete"]))]),
    ]),
    #("duration", [
      Obj([#("duration", [vnum(rx), Lit("initial"), vav(rx), vaval(rx)])]),
    ]),
    #("ease", [
      Obj([
        #("ease", [
          Lit("linear"),
          Lit("initial"),
          Theme("ease"),
          vav(rx),
          vaval(rx),
        ]),
      ]),
    ]),
    #("delay", [Obj([#("delay", [vnum(rx), vav(rx), vaval(rx)])])]),
    #("animate", [
      Obj([#("animate", [Lit("none"), Theme("animate"), vav(rx), vaval(rx)])]),
    ]),
  ]
}

fn transforms(rx: Regexes) -> List(#(String, List(ClassDef))) {
  [
    #("backface", [Obj([#("backface", lits(["hidden", "visible"]))])]),
    #("perspective", [
      Obj([#("perspective", [Theme("perspective"), vav(rx), vaval(rx)])]),
    ]),
    #("perspective-origin", [
      Obj([#("perspective-origin", scale_position_with_arbitrary(rx))]),
    ]),
    #("rotate", [Obj([#("rotate", scale_rotate(rx))])]),
    #("rotate-x", [Obj([#("rotate-x", scale_rotate(rx))])]),
    #("rotate-y", [Obj([#("rotate-y", scale_rotate(rx))])]),
    #("rotate-z", [Obj([#("rotate-z", scale_rotate(rx))])]),
    #("scale", [Obj([#("scale", scale_scale(rx))])]),
    #("scale-x", [Obj([#("scale-x", scale_scale(rx))])]),
    #("scale-y", [Obj([#("scale-y", scale_scale(rx))])]),
    #("scale-z", [Obj([#("scale-z", scale_scale(rx))])]),
    #("scale-3d", lits(["scale-3d"])),
    #("skew", [Obj([#("skew", scale_skew(rx))])]),
    #("skew-x", [Obj([#("skew-x", scale_skew(rx))])]),
    #("skew-y", [Obj([#("skew-y", scale_skew(rx))])]),
    #("transform", [
      Obj([
        #("transform", [
          vav(rx),
          vaval(rx),
          Lit(""),
          Lit("none"),
          Lit("gpu"),
          Lit("cpu"),
        ]),
      ]),
    ]),
    #("transform-origin", [
      Obj([#("origin", scale_position_with_arbitrary(rx))]),
    ]),
    #("transform-style", [Obj([#("transform", lits(["3d", "flat"]))])]),
    #("translate", [Obj([#("translate", scale_translate(rx))])]),
    #("translate-x", [Obj([#("translate-x", scale_translate(rx))])]),
    #("translate-y", [Obj([#("translate-y", scale_translate(rx))])]),
    #("translate-z", [Obj([#("translate-z", scale_translate(rx))])]),
    #("translate-none", lits(["translate-none"])),
    #("zoom", [Obj([#("zoom", [vint(rx), vav(rx), vaval(rx)])])]),
  ]
}

fn interactivity(rx: Regexes) -> List(#(String, List(ClassDef))) {
  [
    #("accent", [Obj([#("accent", scale_color(rx))])]),
    #("appearance", [Obj([#("appearance", lits(["none", "auto"]))])]),
    #("caret-color", [Obj([#("caret", scale_color(rx))])]),
    #("color-scheme", [
      Obj([
        #(
          "scheme",
          lits([
            "normal", "dark", "light", "light-dark", "only-dark", "only-light",
          ]),
        ),
      ]),
    ]),
    #("cursor", [
      Obj([
        #("cursor", [
          Lit("auto"),
          Lit("default"),
          Lit("pointer"),
          Lit("wait"),
          Lit("text"),
          Lit("move"),
          Lit("help"),
          Lit("not-allowed"),
          Lit("none"),
          Lit("context-menu"),
          Lit("progress"),
          Lit("cell"),
          Lit("crosshair"),
          Lit("vertical-text"),
          Lit("alias"),
          Lit("copy"),
          Lit("no-drop"),
          Lit("grab"),
          Lit("grabbing"),
          Lit("all-scroll"),
          Lit("col-resize"),
          Lit("row-resize"),
          Lit("n-resize"),
          Lit("e-resize"),
          Lit("s-resize"),
          Lit("w-resize"),
          Lit("ne-resize"),
          Lit("nw-resize"),
          Lit("se-resize"),
          Lit("sw-resize"),
          Lit("ew-resize"),
          Lit("ns-resize"),
          Lit("nesw-resize"),
          Lit("nwse-resize"),
          Lit("zoom-in"),
          Lit("zoom-out"),
          vav(rx),
          vaval(rx),
        ]),
      ]),
    ]),
    #("field-sizing", [Obj([#("field-sizing", lits(["fixed", "content"]))])]),
    #("pointer-events", [Obj([#("pointer-events", lits(["auto", "none"]))])]),
    #("resize", [Obj([#("resize", lits(["none", "", "y", "x"]))])]),
    #("scroll-behavior", [Obj([#("scroll", lits(["auto", "smooth"]))])]),
    #("scrollbar-thumb-color", [Obj([#("scrollbar-thumb", scale_color(rx))])]),
    #("scrollbar-track-color", [Obj([#("scrollbar-track", scale_color(rx))])]),
    #("scrollbar-gutter", [
      Obj([#("scrollbar-gutter", lits(["auto", "stable", "both"]))]),
    ]),
    #("scrollbar-w", [Obj([#("scrollbar", lits(["auto", "thin", "none"]))])]),
    #("scroll-m", [Obj([#("scroll-m", scale_unambiguous_spacing(rx))])]),
    #("scroll-mx", [Obj([#("scroll-mx", scale_unambiguous_spacing(rx))])]),
    #("scroll-my", [Obj([#("scroll-my", scale_unambiguous_spacing(rx))])]),
    #("scroll-ms", [Obj([#("scroll-ms", scale_unambiguous_spacing(rx))])]),
    #("scroll-me", [Obj([#("scroll-me", scale_unambiguous_spacing(rx))])]),
    #("scroll-mbs", [Obj([#("scroll-mbs", scale_unambiguous_spacing(rx))])]),
    #("scroll-mbe", [Obj([#("scroll-mbe", scale_unambiguous_spacing(rx))])]),
    #("scroll-mt", [Obj([#("scroll-mt", scale_unambiguous_spacing(rx))])]),
    #("scroll-mr", [Obj([#("scroll-mr", scale_unambiguous_spacing(rx))])]),
    #("scroll-mb", [Obj([#("scroll-mb", scale_unambiguous_spacing(rx))])]),
    #("scroll-ml", [Obj([#("scroll-ml", scale_unambiguous_spacing(rx))])]),
    #("scroll-p", [Obj([#("scroll-p", scale_unambiguous_spacing(rx))])]),
    #("scroll-px", [Obj([#("scroll-px", scale_unambiguous_spacing(rx))])]),
    #("scroll-py", [Obj([#("scroll-py", scale_unambiguous_spacing(rx))])]),
    #("scroll-ps", [Obj([#("scroll-ps", scale_unambiguous_spacing(rx))])]),
    #("scroll-pe", [Obj([#("scroll-pe", scale_unambiguous_spacing(rx))])]),
    #("scroll-pbs", [Obj([#("scroll-pbs", scale_unambiguous_spacing(rx))])]),
    #("scroll-pbe", [Obj([#("scroll-pbe", scale_unambiguous_spacing(rx))])]),
    #("scroll-pt", [Obj([#("scroll-pt", scale_unambiguous_spacing(rx))])]),
    #("scroll-pr", [Obj([#("scroll-pr", scale_unambiguous_spacing(rx))])]),
    #("scroll-pb", [Obj([#("scroll-pb", scale_unambiguous_spacing(rx))])]),
    #("scroll-pl", [Obj([#("scroll-pl", scale_unambiguous_spacing(rx))])]),
    #("snap-align", [
      Obj([#("snap", lits(["start", "end", "center", "align-none"]))]),
    ]),
    #("snap-stop", [Obj([#("snap", lits(["normal", "always"]))])]),
    #("snap-type", [Obj([#("snap", lits(["none", "x", "y", "both"]))])]),
    #("snap-strictness", [Obj([#("snap", lits(["mandatory", "proximity"]))])]),
    #("touch", [Obj([#("touch", lits(["auto", "none", "manipulation"]))])]),
    #("touch-x", [Obj([#("touch-pan", lits(["x", "left", "right"]))])]),
    #("touch-y", [Obj([#("touch-pan", lits(["y", "up", "down"]))])]),
    #("touch-pz", lits(["touch-pinch-zoom"])),
    #("select", [Obj([#("select", lits(["none", "text", "all", "auto"]))])]),
    #("will-change", [
      Obj([
        #("will-change", [
          Lit("auto"),
          Lit("scroll"),
          Lit("contents"),
          Lit("transform"),
          vav(rx),
          vaval(rx),
        ]),
      ]),
    ]),
  ]
}

fn svg(rx: Regexes) -> List(#(String, List(ClassDef))) {
  [
    #("fill", [Obj([#("fill", [Lit("none"), ..scale_color(rx)])])]),
    #("stroke-w", [
      Obj([#("stroke", [vnum(rx), vavlen(rx), valen(rx), vanum(rx)])]),
    ]),
    #("stroke", [Obj([#("stroke", [Lit("none"), ..scale_color(rx)])])]),
  ]
}

fn accessibility() -> List(#(String, List(ClassDef))) {
  [
    #("forced-color-adjust", [
      Obj([#("forced-color-adjust", lits(["auto", "none"]))]),
    ]),
  ]
}

// --- conflict tables ----------------------------------------------------------

fn conflicting_class_groups() -> List(#(String, List(String))) {
  [
    #("container-named", ["container-type"]),
    #("overflow", ["overflow-x", "overflow-y"]),
    #("overscroll", ["overscroll-x", "overscroll-y"]),
    #("inset", [
      "inset-x", "inset-y", "inset-bs", "inset-be", "start", "end", "top",
      "right", "bottom", "left",
    ]),
    #("inset-x", ["right", "left"]),
    #("inset-y", ["top", "bottom"]),
    #("flex", ["basis", "grow", "shrink"]),
    #("gap", ["gap-x", "gap-y"]),
    #("p", ["px", "py", "ps", "pe", "pbs", "pbe", "pt", "pr", "pb", "pl"]),
    #("px", ["pr", "pl"]),
    #("py", ["pt", "pb"]),
    #("m", ["mx", "my", "ms", "me", "mbs", "mbe", "mt", "mr", "mb", "ml"]),
    #("mx", ["mr", "ml"]),
    #("my", ["mt", "mb"]),
    #("size", ["w", "h"]),
    #("font-size", ["leading"]),
    #("fvn-normal", [
      "fvn-ordinal", "fvn-slashed-zero", "fvn-figure", "fvn-spacing",
      "fvn-fraction",
    ]),
    #("fvn-ordinal", ["fvn-normal"]),
    #("fvn-slashed-zero", ["fvn-normal"]),
    #("fvn-figure", ["fvn-normal"]),
    #("fvn-spacing", ["fvn-normal"]),
    #("fvn-fraction", ["fvn-normal"]),
    #("line-clamp", ["display", "overflow"]),
    #("rounded", [
      "rounded-s", "rounded-e", "rounded-t", "rounded-r", "rounded-b",
      "rounded-l", "rounded-ss", "rounded-se", "rounded-ee", "rounded-es",
      "rounded-tl", "rounded-tr", "rounded-br", "rounded-bl",
    ]),
    #("rounded-s", ["rounded-ss", "rounded-es"]),
    #("rounded-e", ["rounded-se", "rounded-ee"]),
    #("rounded-t", ["rounded-tl", "rounded-tr"]),
    #("rounded-r", ["rounded-tr", "rounded-br"]),
    #("rounded-b", ["rounded-br", "rounded-bl"]),
    #("rounded-l", ["rounded-tl", "rounded-bl"]),
    #("border-spacing", ["border-spacing-x", "border-spacing-y"]),
    #("border-w", [
      "border-w-x", "border-w-y", "border-w-s", "border-w-e", "border-w-bs",
      "border-w-be", "border-w-t", "border-w-r", "border-w-b", "border-w-l",
    ]),
    #("border-w-x", ["border-w-r", "border-w-l"]),
    #("border-w-y", ["border-w-t", "border-w-b"]),
    #("border-color", [
      "border-color-x", "border-color-y", "border-color-s", "border-color-e",
      "border-color-bs", "border-color-be", "border-color-t", "border-color-r",
      "border-color-b", "border-color-l",
    ]),
    #("border-color-x", ["border-color-r", "border-color-l"]),
    #("border-color-y", ["border-color-t", "border-color-b"]),
    #("translate", ["translate-x", "translate-y", "translate-none"]),
    #("translate-none", [
      "translate",
      "translate-x",
      "translate-y",
      "translate-z",
    ]),
    #("scroll-m", [
      "scroll-mx", "scroll-my", "scroll-ms", "scroll-me", "scroll-mbs",
      "scroll-mbe", "scroll-mt", "scroll-mr", "scroll-mb", "scroll-ml",
    ]),
    #("scroll-mx", ["scroll-mr", "scroll-ml"]),
    #("scroll-my", ["scroll-mt", "scroll-mb"]),
    #("scroll-p", [
      "scroll-px", "scroll-py", "scroll-ps", "scroll-pe", "scroll-pbs",
      "scroll-pbe", "scroll-pt", "scroll-pr", "scroll-pb", "scroll-pl",
    ]),
    #("scroll-px", ["scroll-pr", "scroll-pl"]),
    #("scroll-py", ["scroll-pt", "scroll-pb"]),
    #("touch", ["touch-x", "touch-y", "touch-pz"]),
    #("touch-x", ["touch"]),
    #("touch-y", ["touch"]),
    #("touch-pz", ["touch"]),
  ]
}
