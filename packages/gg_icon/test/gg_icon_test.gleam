import gg_icon/icon
import gleam/string
import gleeunit
import gleeunit/should
import lustre/attribute
import lustre/element
import lustre/element/svg

pub fn main() {
  gleeunit.main()
}

fn render(el) -> String {
  element.to_string(el)
}

pub fn svg_bakes_viewbox_defaults_and_base_class_test() {
  let html =
    render(
      icon.svg(
        view_box: "0 0 24 24",
        defaults: [#("fill", "none"), #("stroke", "currentColor")],
        attrs: [],
        children: [svg.path([attribute.attribute("d", "m6 9 6 6 6-6")])],
      ),
    )

  should.be_true(string.contains(html, "viewBox=\"0 0 24 24\""))
  should.be_true(string.contains(html, "class=\"cn-icon\""))
  should.be_true(string.contains(html, "stroke=\"currentColor\""))
  should.be_true(string.contains(html, "m6 9 6 6 6-6"))
}

pub fn caller_attrs_win_test() {
  // Lustre renders the last-passed duplicate first, and HTML keeps the first
  // attribute in markup — so a caller override (appended last) is serialised
  // *before* the baked default and wins in the browser.
  let html =
    render(
      icon.svg(
        view_box: "0 0 24 24",
        defaults: [#("stroke-width", "2")],
        attrs: [attribute.attribute("stroke-width", "1.5")],
        children: [],
      ),
    )

  let assert Ok(#(before_default, _)) =
    string.split_once(html, "stroke-width=\"2\"")
  should.be_true(string.contains(before_default, "stroke-width=\"1.5\""))
}

pub fn class_attributes_merge_test() {
  // The base `cn-icon` class and a caller size class combine into one list, so
  // both reach the DOM (size wins via CSS source order, not attribute order).
  let html =
    render(
      icon.svg(
        view_box: "0 0 24 24",
        defaults: [],
        attrs: [icon.size(icon.Sm)],
        children: [],
      ),
    )

  should.be_true(string.contains(html, "cn-icon"))
  should.be_true(string.contains(html, "cn-icon-size-sm"))
}

pub fn size_emits_token_carrying_class_test() {
  // Named sizes must contain the `size-` token so they defeat a container's
  // `[&_svg:not([class*='size-'])]` default.
  let html =
    render(
      icon.svg(
        view_box: "0 0 24 24",
        defaults: [],
        attrs: [icon.size(icon.Lg)],
        children: [],
      ),
    )

  should.be_true(string.contains(html, "cn-icon-size-lg"))
}

pub fn placeholder_renders_fallback_box_test() {
  let html = render(icon.placeholder(lucide: "x", tabler: "x", attrs: []))

  // Fallback box: a square path, not a real glyph.
  should.be_true(string.contains(html, "M4 4h16v16H4z"))
}
