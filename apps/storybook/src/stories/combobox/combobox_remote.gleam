//// Remote (server-driven) combobox story host — a realistic async, debounced,
//// paginated, **lazy-on-open** selector backed by GitHub repository search. Shows
//// how a host drives the combobox in `Manual` filter mode: it owns the data
//// (`set_items` on a new search, `append_items` on the next page), the loading
//// announcer (`set_loading`), the debounce (host-side; see `schedule_search`),
//// and pagination (`on_scroll_end` → `is_reached_end` → fetch
//// the next page). Single- and multiple-select share this host.
////
//// Nothing fetches until the combobox is opened: the first open kicks off the
//// default-query page; typing debounces a fresh search; scrolling to the bottom
//// auto-loads the next page.

import gg_ui/positioning.{type Align, type Side, Bottom, Start}
import gg_ui/ui/combobox
import gg_ui/ui/text
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/int
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html

// GitHub search needs a non-empty `q`; before the user types we browse popular
// repos. `per_page=20` and the 1000-result cap come from the API.
const default_query = "stars:>50000"

type Model {
  Model(
    cb: combobox.Model(String),
    anatomy: combobox.Anatomy,
    side: Side,
    align: Align,
    multiple: Bool,
    // The active search text (default = "" → browse) and pagination cursor.
    query: String,
    page: Int,
    total: Int,
    fetched: Bool,
  )
}

type Msg {
  ComboboxMsg(combobox.Msg)
  // The debounce timer elapsed → run the search for this query if it's still
  // current. (Debounce lives in the host, not the input — debouncing a controlled
  // input's dispatch drops characters.)
  RunSearch(query: String)
  // A fetched page: the query it was for (staleness guard), the page number, the
  // repos, and the total available.
  GotPage(
    query: String,
    page: Int,
    items: List(combobox.Item(String)),
    total: Int,
  )
  FetchFailed(String)
}

fn init(flags: #(Side, Align, Bool)) -> #(Model, Effect(Msg)) {
  let #(side, align, multiple) = flags
  let mode = case multiple {
    True -> combobox.Multiple
    False -> combobox.Single
  }
  let cb =
    combobox.init(
      items: [],
      config: combobox.Config(
        loop: True,
        auto_highlight: False,
        mode:,
        // The server filters; debounce the input so typing fires one fetch.
        filter: combobox.Manual,
      ),
    )
  #(
    Model(
      cb:,
      anatomy: combobox.anatomy_with_id("combobox-remote"),
      side:,
      align:,
      multiple:,
      query: "",
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
      // Thread the combobox through its own update first, then react to *what
      // changed* — three independent triggers for a fetch, each its own case:
      let was_open = combobox.is_open(model.cb)
      let old_query = combobox.input_value(model.cb)
      let #(cb, eff) = combobox.update(model.anatomy, model.cb, cb_msg)
      let model = Model(..model, cb:, query: combobox.input_value(cb))
      let passthrough = #(model, effect.map(eff, ComboboxMsg))

      let opened = !was_open && combobox.is_open(cb)
      let query_changed = combobox.is_open(cb) && model.query != old_query
      case combobox.is_reached_end(cb_msg), opened, query_changed {
        // Scrolled near the bottom → auto-load the next page.
        True, _, _ -> load_more(model)
        // Closed → open: the lazy first fetch (default query).
        _, True, _ -> search(model)
        // Query changed while open → debounce, then fetch.
        _, _, True -> schedule_search(model)
        _, _, _ -> passthrough
      }
    }

    // Fire only if the query is still current (the debounce coalesced keystrokes).
    RunSearch(query:) ->
      case query == model.query {
        True -> #(model, fetch_page(query, 1))
        False -> #(model, effect.none())
      }

    GotPage(query:, page:, items:, total:) ->
      // Drop a stale page (the query moved on while it was in flight).
      case query == model.query {
        False -> #(model, effect.none())
        True -> {
          let cb = case page {
            1 -> combobox.set_items(model.cb, items)
            _ -> combobox.append_items(model.cb, items)
          }
          #(
            Model(
              ..model,
              cb: combobox.set_loading(cb, False),
              page:,
              // GitHub search only serves the first 1000 results, even though
              // `total_count` reports the full match count.
              total: int.min(total, 1000),
            ),
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

// The lazy first open → fetch the default page now (no debounce needed).
fn search(model: Model) -> #(Model, Effect(Msg)) {
  #(
    Model(
      ..model,
      cb: combobox.set_loading(model.cb, True),
      page: 1,
      fetched: True,
    ),
    fetch_page(model.query, 1),
  )
}

// A changed query → show the spinner now, but debounce the fetch (host-side, via
// `debounce`) so fast typing fires one request after it settles.
fn schedule_search(model: Model) -> #(Model, Effect(Msg)) {
  let query = model.query
  #(
    Model(
      ..model,
      cb: combobox.set_loading(model.cb, True),
      page: 1,
      fetched: True,
    ),
    effect.from(fn(dispatch) {
      debounce("combobox-remote", 250, fn() { dispatch(RunSearch(query:)) })
    }),
  )
}

// Auto-pagination: fetch the next page while more remain and nothing's in flight.
fn load_more(model: Model) -> #(Model, Effect(Msg)) {
  let loaded = combobox.visible_count(model.cb)
  case loaded < model.total && !combobox.is_loading(model.cb) {
    True -> {
      let next = model.page + 1
      #(
        Model(..model, cb: combobox.set_loading(model.cb, True), page: next),
        fetch_page(model.query, next),
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
) -> Result(#(List(combobox.Item(String)), Int), List(decode.DecodeError)) {
  let repo = {
    use full_name <- decode.field("full_name", decode.string)
    decode.success(combobox.Item(
      value: full_name,
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
    [
      element.map(widget(model), ComboboxMsg),
      status_line(model),
    ],
  )
}

// Assemble the parts (composition): field + popup holding the empty announcer, a
// loading announcer while fetching, and the list. The list carries `on_scroll_end`
// so reaching the bottom auto-loads the next page.
fn widget(model: Model) -> Element(combobox.Msg) {
  let a = model.anatomy
  let cb = model.cb
  // The loading announcer sits **after** the list (a footer), so toggling it
  // doesn't shove the list down/up — and the empty message is suppressed while
  // loading (no "No repositories" flash mid-fetch). The list top stays put.
  let footer = case combobox.is_loading(cb) {
    True -> [combobox.loading([], [html.text("Searching repositories…")])]
    False -> [combobox.empty([], [html.text("No repositories found.")])]
  }
  html.div([], [
    combobox.input(
      a,
      cb,
      placeholder: "Search GitHub repositories…",
      clearable: !model.multiple,
      attrs: [],
    ),
    combobox.content(
      a,
      cb,
      side: model.side,
      align: model.align,
      attrs: [],
      children: [
        combobox.list(
          a,
          cb,
          [combobox.on_scroll_end(threshold: 48)],
          combobox.options(a, cb),
        ),
        ..footer
      ],
    ),
  ])
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

fn start(flags: #(Side, Align, Bool), selector: String) -> Nil {
  let assert Ok(_) =
    lustre.start(lustre.application(init, update, view), selector, flags)
  Nil
}

pub fn mount_combobox_remote_single(selector: String) -> Nil {
  start(#(Bottom, Start, False), selector)
}

pub fn mount_combobox_remote_multiple(selector: String) -> Nil {
  start(#(Bottom, Start, True), selector)
}

@external(javascript, "./github_ffi.ts", "searchRepos")
fn search_repos(
  _query: String,
  _page: Int,
  _on_ok: fn(Dynamic) -> Nil,
  _on_err: fn(String) -> Nil,
) -> Nil {
  Nil
}

@external(javascript, "./github_ffi.ts", "debounce")
fn debounce(_key: String, _delay_ms: Int, _callback: fn() -> Nil) -> Nil {
  Nil
}
