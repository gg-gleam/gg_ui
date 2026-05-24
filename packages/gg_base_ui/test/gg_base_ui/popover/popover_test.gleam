import gg_base_ui/popover/popover
import gleam/string

pub fn anatomy_with_id_derives_ids_from_base_id_test() {
  let a = popover.anatomy_with_id("demo")
  assert a.anchor_id == "demo-anchor"
  assert a.content_id == "demo-content"
  assert a.title_id == "demo-title"
  assert a.description_id == "demo-description"
}

pub fn anatomy_generates_unique_collision_free_ids_test() {
  let a = popover.anatomy()
  let b = popover.anatomy()
  // Each part shares one freshly-generated base...
  assert string.ends_with(a.anchor_id, "-anchor")
  assert string.ends_with(a.content_id, "-content")
  assert string.ends_with(a.title_id, "-title")
  assert string.ends_with(a.description_id, "-description")
  // ...and two anatomies never collide.
  assert a.anchor_id != b.anchor_id
}
