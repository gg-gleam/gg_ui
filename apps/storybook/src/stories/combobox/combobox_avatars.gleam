//// Remote combobox with **custom items and custom chips** — the same GitHub-repo
//// search as `combobox_remote`, but each option shows the owner's avatar and each
//// selected chip is an avatar + owner. Two things make it work:
////
//// - **A rich `value`.** The combobox is generic over its value, so here it's a
////   `Repo` record (full_name + owner + avatar_url), not a bare `String`. The
////   custom item renderer reads `item.value.avatar_url`; the chips do too — and
////   because the chip carries its own `Repo`, the picks survive a list refresh
////   (a new search replaces the options but not the selection).
//// - **The render hooks.** `combobox.items` + `combobox.item` supply per-option
////   content; `combobox.input_custom_chips` supplies per-chip content. The shells
////   (option a11y, chip roving-focus, the built-in remove ✕) stay built in.
////
//// Multiple-select, so both hooks are on show at once: avatars in the dropdown,
//// avatar-chips in the field. The async/debounce/pagination plumbing is the same
//// as `combobox_remote` (see that file's header).

import gg_ui/positioning.{type Align, type Side, Bottom, Start}
import gg_ui/ui/avatar
import gg_ui/ui/combobox
import gg_ui/ui/text
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option.{Some}
import gleam/string
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html

const default_query = "stars:>50000"

// The rich option value — everything a custom item / chip needs to render.
pub type Repo {
  Repo(full_name: String, owner: String, avatar_url: String)
}

type Model {
  Model(
    cb: combobox.Model(Repo),
    anatomy: combobox.Anatomy,
    side: Side,
    align: Align,
    active_query: String,
    page: Int,
    total: Int,
    fetched: Bool,
  )
}

type Msg {
  ComboboxMsg(combobox.Msg)
  GotPage(
    query: String,
    page: Int,
    items: List(combobox.Item(Repo)),
    total: Int,
  )
  FetchFailed(String)
}

fn init(flags: #(Side, Align)) -> #(Model, Effect(Msg)) {
  let #(side, align) = flags
  let cb =
    combobox.init(
      items: [],
      config: combobox.Config(
        loop: True,
        auto_highlight: False,
        mode: combobox.Multiple,
        filter: combobox.Manual,
        search_debounce: 250,
      ),
    )
  #(
    Model(
      cb:,
      anatomy: combobox.anatomy_with_id("combobox-avatars"),
      side:,
      align:,
      active_query: "",
      page: 1,
      total: 0,
      fetched: False,
    ),
    effect.none(),
  )
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    ComboboxMsg(cb_msg) -> {
      let was_open = combobox.is_open(model.cb)
      let old_value = combobox.input_value(model.cb)
      let #(cb, eff) = combobox.update(model.anatomy, model.cb, cb_msg)
      let new_value = combobox.input_value(cb)
      let model = Model(..model, cb:)
      let model = case new_value != old_value {
        True -> Model(..model, page: 1)
        False -> model
      }
      let opened = !was_open && combobox.is_open(cb)
      let #(model, fetch_eff) = case
        combobox.search_request(cb_msg),
        combobox.is_reached_end(cb_msg),
        opened
      {
        Some(query), _, _ -> fetch(model, query)
        _, True, _ -> load_more(model)
        // Chips hold the selection, so the input is just the typed query — browse
        // with it as-is on (re)open.
        _, _, True -> fetch(model, combobox.input_value(model.cb))
        _, _, _ -> #(model, effect.none())
      }
      #(model, effect.batch([effect.map(eff, ComboboxMsg), fetch_eff]))
    }

    GotPage(query:, page:, items:, total:) ->
      case query == model.active_query {
        False -> #(model, effect.none())
        True -> {
          let cb = case page {
            1 -> combobox.set_items(model.cb, items)
            _ -> combobox.append_items(model.cb, items)
          }
          #(
            Model(..model, cb: combobox.set_loading(cb, False), page:, total:),
            effect.none(),
          )
        }
      }

    FetchFailed(_) -> #(
      Model(..model, cb: combobox.set_loading(model.cb, False)),
      effect.none(),
    )
  }
}

fn fetch(model: Model, query: String) -> #(Model, Effect(Msg)) {
  #(
    Model(
      ..model,
      cb: combobox.set_loading(model.cb, True),
      active_query: query,
      page: 1,
      fetched: True,
    ),
    fetch_page(query, 1),
  )
}

fn load_more(model: Model) -> #(Model, Effect(Msg)) {
  let loaded = combobox.visible_count(model.cb)
  case loaded < model.total && !combobox.is_loading(model.cb) {
    True -> {
      let next = model.page + 1
      #(
        Model(..model, cb: combobox.set_loading(model.cb, True), page: next),
        fetch_page(model.active_query, next),
      )
    }
    False -> #(model, effect.none())
  }
}

fn fetch_page(query: String, page: Int) -> Effect(Msg) {
  let q = case query {
    "" -> default_query
    _ -> query
  }
  effect.from(fn(dispatch) {
    search_repos(
      q,
      page,
      fn(json) {
        case decode_page(json) {
          Ok(#(items, total)) ->
            dispatch(GotPage(query:, page:, items:, total:))
          Error(_) -> dispatch(FetchFailed("decode"))
        }
      },
      fn(err) { dispatch(FetchFailed(err)) },
    )
  })
}

fn decode_page(
  json: Dynamic,
) -> Result(#(List(combobox.Item(Repo)), Int), List(decode.DecodeError)) {
  let repo = {
    use full_name <- decode.field("full_name", decode.string)
    use owner <- decode.field("owner", decode.string)
    use avatar_url <- decode.field("avatar_url", decode.string)
    decode.success(combobox.Item(
      value: Repo(full_name:, owner:, avatar_url:),
      label: full_name,
      disabled: False,
    ))
  }
  let page = {
    use total <- decode.field("total_count", decode.int)
    use items <- decode.field("items", decode.list(repo))
    decode.success(#(items, total))
  }
  decode.run(json, page)
}

fn view(model: Model) -> Element(Msg) {
  html.div(
    [attribute.class("flex min-h-72 w-80 flex-col gap-3 text-foreground")],
    [element.map(widget(model), ComboboxMsg), status_line(model)],
  )
}

fn widget(model: Model) -> Element(combobox.Msg) {
  let a = model.anatomy
  let cb = model.cb
  let first_load = combobox.is_loading(cb) && combobox.visible_count(cb) == 0
  let placeholder = case first_load {
    True -> [combobox.loading_state_text(text: "Loading…")]
    False -> []
  }
  html.div([], [
    combobox.input_custom_chips(
      a,
      cb,
      placeholder: "Search GitHub repositories…",
      clearable: False,
      chip: chip_content,
      attrs: [],
    ),
    combobox.content(
      a,
      cb,
      side: model.side,
      align: model.align,
      attrs: [],
      children: list.flatten([
        [combobox.empty([], [html.text("No repositories found.")])],
        placeholder,
        [
          combobox.list(
            a,
            cb,
            [combobox.on_scroll_end(threshold: 48)],
            combobox.items(cb, fn(it, pos) {
              combobox.item(a, cb, pos, it, [item_content(it)])
            }),
          ),
        ],
      ]),
    ),
  ])
}

// A custom option: the owner's avatar, then the repo name over the owner login.
fn item_content(it: combobox.Item(Repo)) -> Element(combobox.Msg) {
  html.div([attribute.class("flex min-w-0 items-center gap-2")], [
    repo_avatar(it.value, avatar.Sm, avatar.Circle),
    html.div([attribute.class("flex min-w-0 flex-col")], [
      text.s6([text.truncate(text.Ellipsis)], [html.text(it.value.full_name)]),
      text.s7([text.color(text.Muted), text.truncate(text.Ellipsis)], [
        html.text(it.value.owner),
      ]),
    ]),
  ])
}

// A custom chip: the owner's avatar + login (the remove ✕ is appended built-in).
// The chip avatar is chip-sized `Xs` + a `Rounded` shape, so it nests neatly in
// the chip's rounded box instead of reading as a too-large circle.
fn chip_content(it: combobox.Item(Repo)) -> List(Element(combobox.Msg)) {
  [
    repo_avatar(it.value, avatar.Xs, avatar.Rounded),
    text.s6([], [html.text(it.value.owner)]),
  ]
}

fn repo_avatar(
  repo: Repo,
  size: avatar.Size,
  shape: avatar.Shape,
) -> Element(msg) {
  avatar.avatar(size, shape, [], [
    avatar.image(src: repo.avatar_url, alt: repo.owner, attrs: []),
    avatar.fallback([], [
      text.s7([text.color(text.Inherit)], [html.text(initials(repo.owner))]),
    ]),
  ])
}

fn initials(owner: String) -> String {
  string.slice(owner, 0, 2) |> string.uppercase
}

fn status_line(model: Model) -> Element(Msg) {
  let count = combobox.visible_count(model.cb)
  let label = case model.fetched {
    False -> "Open to load repositories"
    True ->
      int.to_string(count) <> " of " <> int.to_string(model.total) <> " loaded"
  }
  text.s6([text.color(text.Muted)], [html.text(label)])
}

// --- mount ---------------------------------------------------------------

fn start(flags: #(Side, Align), selector: String) -> Nil {
  let assert Ok(_) =
    lustre.start(lustre.application(init, update, view), selector, flags)
  Nil
}

pub fn mount_combobox_avatars(selector: String) -> Nil {
  start(#(Bottom, Start), selector)
}

@external(javascript, "./repos_ffi.ts", "searchRepos")
fn search_repos(
  _query: String,
  _page: Int,
  _on_ok: fn(Dynamic) -> Nil,
  _on_err: fn(String) -> Nil,
) -> Nil {
  Nil
}
