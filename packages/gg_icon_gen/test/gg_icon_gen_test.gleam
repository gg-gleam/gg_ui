import gg_icon_gen/names
import gg_icon_gen/render
import gg_icon_gen/svg
import gleam/string
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

// --- names -------------------------------------------------------------------

pub fn snake_case_test() {
  names.snake_case("chevron-down") |> should.equal("chevron_down")
  names.snake_case("Arrow Up.Right") |> should.equal("arrow_up_right")
}

pub fn shard_test() {
  names.shard("chevron_down") |> should.equal("c")
  names.shard("24_hours") |> should.equal("0")
}

pub fn fn_name_test() {
  names.fn_name("chevron_down") |> should.equal("chevron_down")
  names.fn_name("24_hours") |> should.equal("n24_hours")
}

pub fn fn_name_reserved_word_test() {
  // Gleam keywords can't be bare function names — suffix `_`.
  names.fn_name("import") |> should.equal("import_")
  names.fn_name("type") |> should.equal("type_")
  names.fn_name("macro") |> should.equal("macro_")
  // A name merely containing a keyword is untouched.
  names.fn_name("book_type") |> should.equal("book_type")
}

// --- svg parse + emit --------------------------------------------------------

pub fn extract_inner_test() {
  "<svg viewBox=\"0 0 24 24\"><path d=\"m6 9 6 6 6-6\"/></svg>"
  |> svg.extract_inner
  |> should.equal("<path d=\"m6 9 6 6 6-6\"/>")
}

pub fn extract_inner_skips_leading_comment_test() {
  // lucide-static ships a license comment before <svg>; the `>` inside `-->`
  // must not be mistaken for the end of the opening tag.
  "<!-- @license lucide-static v1.17.0 - ISC --><svg viewBox=\"0 0 24 24\"><path d=\"m6 9 6 6 6-6\"/></svg>"
  |> svg.extract_inner
  |> should.equal("<path d=\"m6 9 6 6 6-6\"/>")
}

pub fn emit_single_path_test() {
  svg.parse("<path d=\"m6 9 6 6 6-6\"/>")
  |> svg.emit_children
  |> should.equal("svg.path([attribute.attribute(\"d\", \"m6 9 6 6 6-6\")])")
}

pub fn emit_multi_element_test() {
  let out =
    svg.parse("<path d=\"M18 6 6 18\"/><circle cx=\"12\" cy=\"12\" r=\"10\"/>")
    |> svg.emit_children
  should.be_true(string.contains(
    out,
    "svg.path([attribute.attribute(\"d\", \"M18 6 6 18\")])",
  ))
  should.be_true(string.contains(
    out,
    "svg.circle([attribute.attribute(\"cx\", \"12\"), attribute.attribute(\"cy\", \"12\"), attribute.attribute(\"r\", \"10\")])",
  ))
}

pub fn emit_group_with_children_test() {
  svg.parse("<g fill=\"none\"><path d=\"M1 1\"/></g>")
  |> svg.emit_children
  |> should.equal(
    "svg.g([attribute.attribute(\"fill\", \"none\")], [svg.path([attribute.attribute(\"d\", \"M1 1\")])])",
  )
}

// --- render ------------------------------------------------------------------

pub fn render_module_test() {
  let icon =
    render.Icon(
      kebab: "chevron-down",
      fn_name: "chevron_down",
      children_src: "svg.path([attribute.attribute(\"d\", \"m6 9 6 6 6-6\")])",
    )
  let out =
    render.module(
      set: "lucide",
      module_prefix: "gg_icons_lucide",
      variant: "lucide",
      shard: "c",
      view_box: "0 0 24 24",
      defaults_const: "lucide_defaults",
      icons: [icon],
    )

  should.be_true(string.contains(out, "import gg_icon/icon"))
  should.be_true(string.contains(out, "import gg_icons_lucide/internal"))
  should.be_true(string.contains(
    out,
    "pub fn chevron_down(attrs: List(Attribute(msg))) -> Element(msg) {",
  ))
  should.be_true(string.contains(out, "view_box: \"0 0 24 24\","))
  should.be_true(string.contains(out, "defaults: internal.lucide_defaults,"))
}

pub fn render_manifest_test() {
  let out =
    render.manifest(
      set: "tabler",
      variants: ["outline", "filled"],
      default_variant: "outline",
      icons: [
        #("outline", [#("chevron_down", "c")]),
        #("filled", [#("star", "s")]),
      ],
    )

  should.be_true(string.contains(out, "\"defaultVariant\": \"outline\""))
  should.be_true(string.contains(out, "\"chevron_down\": \"c\""))
  should.be_true(string.contains(out, "\"star\": \"s\""))
}
