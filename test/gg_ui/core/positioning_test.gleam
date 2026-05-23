import gg_ui/core/positioning

pub fn anchor_name_is_derived_and_stable_test() {
  assert positioning.anchor_name("demo-anchor") == "--gg-demo-anchor"
  // Both sides derive the same name from the same id.
  assert positioning.anchor_name("x") == positioning.anchor_name("x")
}
