import gg_base_ui/positioning/positioning.{
  Bottom, Center, End, Left, Placement, Right, Start, Top,
}
import gleam/list
import gleam/string

pub fn anchor_name_is_derived_and_stable_test() {
  assert positioning.anchor_name("demo-anchor") == "--gg-demo-anchor"
  // Both sides derive the same name from the same id.
  assert positioning.anchor_name("x") == positioning.anchor_name("x")
}

/// The aligned placement that the Basic story uses. Regression guard: it must
/// stay in the logical keyword group, not `bottom span-inline-end` (which mixes
/// physical + logical, is invalid, and drops the popover to the corner).
pub fn position_area_aligned_is_logical_test() {
  assert positioning.position_area_value(Placement(Bottom, Start))
    == "block-end span-inline-end"
}

pub fn side_and_align_data_tokens_test() {
  assert positioning.side_to_string(Top) == "top"
  assert positioning.side_to_string(Bottom) == "bottom"
  assert positioning.align_to_string(Start) == "start"
  assert positioning.align_to_string(Center) == "center"
}

/// `position-area` forbids mixing physical keywords (`top`/`bottom`/`left`/
/// `right`) with logical spans (`span-inline-*`/`span-block-*`); a mixed value
/// is dropped wholesale. Assert no emitted value mixes the two groups.
pub fn position_area_never_mixes_keyword_groups_test() {
  let sides = [Top, Right, Bottom, Left]
  let aligns = [Start, Center, End]
  let physical = ["top", "right", "bottom", "left"]

  use side <- list.each(sides)
  use align <- list.each(aligns)
  let value = positioning.position_area_value(Placement(side, align))
  let has_logical =
    string.contains(value, "span-inline")
    || string.contains(value, "span-block")
  let has_physical =
    list.any(physical, fn(word) { string.contains(value, word) })
  assert !{ has_logical && has_physical }
}
