import gg_ui/core/popover

pub fn init_is_closed_with_derived_ids_test() {
  let state = popover.init("demo")
  assert popover.is_open(state) == False
  assert state.anchor_id == "demo-anchor"
  assert state.content_id == "demo-content"
}

pub fn toggle_opens_then_closes_test() {
  let state = popover.init("demo")
  let state = popover.update(state, popover.Toggled)
  assert popover.is_open(state) == True
  let state = popover.update(state, popover.Toggled)
  assert popover.is_open(state) == False
}

pub fn open_then_dismiss_closes_test() {
  let state = popover.init("x") |> popover.update(popover.Opened)
  assert popover.is_open(state) == True
  let state = popover.update(state, popover.DismissRequested)
  assert popover.is_open(state) == False
}
