//// Remote (server-driven) combobox story host — a realistic async, debounced,
//// paginated, **lazy-on-open** selector backed by GitHub repository search. Shows
//// how a host drives the combobox in `Manual` filter mode: it owns the data
//// (`set_items` on a new search, `append_items` on the next page) and the fetch;
//// the **component** owns the typing debounce (`Config.search_debounce`), emitting
//// a `SearchRequested` the host reads via `search_request`. Pagination comes from
//// `on_scroll_end` → `is_reached_end`. Single- and multiple-select share this host.
////
//// Nothing fetches until the combobox is opened: the first open kicks off the
//// default-query page; typing emits a debounced search; scrolling to the bottom
//// auto-loads the next page. Loading feedback is built into the field — the
//// combobox swaps its trailing chevron for a spinner while `is_loading`.
////
//// **Lazy DOM, not just lazy fetch.** The `list` — and the accumulated,
//// infinitely-paginated `option` nodes it holds — is rendered ONLY while the
//// popup is open (gated on `combobox.is_open`). Closed, the popup keeps just its
//// one-node `empty` announcer, so N closed comboboxes on a page cost ~0 option
//// nodes instead of N × every-page-ever-loaded. The native-popover *shell*
//// (`content`) stays mounted, so open/positioning/animation are unchanged — we
//// gate the *contents*, never the container. This is the userland pattern that
//// keeps the DOM small without virtualization (only a single huge *open* list
//// would still need windowing).

import gg_ui/positioning.{type Align, type Side, Bottom, Start}
import gg_ui/ui/combobox
import gg_ui/ui/text
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option.{Some}
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html

// The mock "server" needs a non-empty query; before the user types we browse all
// repos via a `stars:` qualifier (which the mock treats as "everything").
const default_query = "stars:>50000"

type Model {
  Model(
    cb: combobox.Model(String),
    anatomy: combobox.Anatomy,
    side: Side,
    align: Align,
    multiple: Bool,
    // What the server is currently serving — the query the in-flight/last fetch
    // was for ("" = browse). Kept separate from the combobox's input value (which
    // may hold a selected label) so the staleness guard + pagination key off the
    // *fetched* query, not the displayed text. Plus the pagination cursor.
    active_query: String,
    page: Int,
    total: Int,
    fetched: Bool,
  )
}

type Msg {
  ComboboxMsg(combobox.Msg)
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
        // The server filters (Manual), and the component debounces typing into a
        // single `SearchRequested` after 250ms — the host just fetches on it.
        filter: combobox.Manual,
        search_debounce: 250,
      ),
    )
  #(
    Model(
      cb:,
      anatomy: combobox.anatomy_with_id("combobox-remote"),
      side:,
      align:,
      multiple:,
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
      // Typing → a fresh search is coming; reset to page 1 *eagerly* (before the
      // debounce fires) so the spinner shows for a fresh search, not the bottom
      // "Loading more…" from a prior pagination.
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
        // Debounced search fired → fetch page 1 for that query.
        Some(query), _, _ -> fetch(model, query)
        // Scrolled near the bottom → next page.
        _, True, _ -> load_more(model)
        // Closed → open: fetch. If the input still holds a *selected* label (a
        // single-select reopened), browse the full list instead of filtering down
        // to just that one selection — opening a select should show the options.
        _, _, True -> fetch(model, browse_query(model))
        _, _, _ -> #(model, effect.none())
      }
      // Always run the combobox's own effect (show/focus/scroll) alongside.
      #(model, effect.batch([effect.map(eff, ComboboxMsg), fetch_eff]))
    }

    GotPage(query:, page:, items:, total:) ->
      // Drop a stale page (a newer fetch superseded this one while it was in
      // flight) — keyed on the *fetched* query, not the input text.
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

// On open, the query to browse with: empty (→ default browse) when the input only
// holds the current selection's label (a reopened single-select), otherwise the
// query as-is (a search the user had typed but not yet picked from).
fn browse_query(model: Model) -> String {
  let input = combobox.input_value(model.cb)
  case combobox.selected(model.cb) {
    Some(value) if value == input -> ""
    _ -> input
  }
}

// Run a fresh fetch for `query` → page 1, loading on, recording it as the active
// (server) query. (No debounce here — the component already debounced typing; an
// open/browse load fetches immediately.)
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

// Auto-pagination: fetch the next page of the *active* query while more remain
// and nothing's in flight.
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

// Assemble the parts (composition): field + popup holding the empty announcer, an
// optional first-load placeholder, and the list. Loading feedback is built into
// the field (the combobox swaps the trailing chevron for a spinner while
// `is_loading`), so the popup shows no loading row; on the *first* open, though,
// the list is still empty, so a min-height placeholder keeps the popup from being
// a collapsed empty box (and reserves the height so results don't jump in).
fn widget(model: Model) -> Element(combobox.Msg) {
  let a = model.anatomy
  let cb = model.cb
  let first_load = combobox.is_loading(cb) && combobox.visible_count(cb) == 0
  // The popup body — the first-open placeholder and the option-bearing `list` —
  // exists only while the popup is open. Closed, only the `empty` announcer
  // stays mounted (it must, so its live-region message can fire); the option
  // nodes leave the DOM entirely. See the module header.
  let body = case combobox.is_open(cb) {
    False -> []
    True ->
      list.flatten([
        case first_load {
          True -> [combobox.loading_state_text(text: "Loading…")]
          False -> []
        },
        [
          combobox.list(
            a,
            cb,
            [combobox.on_scroll_end(threshold: 48)],
            combobox.options(a, cb),
          ),
        ],
      ])
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
        combobox.empty([], [html.text("No repositories found.")]),
        ..body
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

@external(javascript, "./repos_ffi.ts", "searchRepos")
fn search_repos(
  _query: String,
  _page: Int,
  _on_ok: fn(Dynamic) -> Nil,
  _on_err: fn(String) -> Nil,
) -> Nil {
  Nil
}
