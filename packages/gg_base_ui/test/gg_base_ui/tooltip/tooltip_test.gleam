import gg_base_ui/tooltip/tooltip

pub fn anatomy_with_id_derives_ids_from_base_id_test() {
  let a = tooltip.anatomy_with_id("demo")
  assert a.anchor_id == "demo-anchor"
  assert a.content_id == "demo-content"
}

pub fn anatomy_generates_unique_collision_free_ids_test() {
  let a = tooltip.anatomy()
  let b = tooltip.anatomy()
  // Two anatomies never collide on their anchor id.
  assert a.anchor_id != b.anchor_id
  assert a.content_id != b.content_id
}
