%% id_gen FFI (Erlang target) — the `useId`-style unique id counter.
%%
%% `erlang:unique_integer([positive, monotonic])` is a zero-setup BEAM built-in
%% that returns integers unique for the lifetime of the runtime, increasing in
%% call order. No ETS table, counter process, or app-start hook required.
%%
%% The JavaScript counterpart lives in `id_gen_ffi.ts`. Keep the export name
%% (`next_id`) in sync with the `@external(erlang, ...)` binding in
%% `id_gen.gleam`.
-module(gg_base_ui_id_gen_ffi).
-export([next_id/1]).

next_id(Prefix) ->
    N = integer_to_binary(erlang:unique_integer([positive, monotonic])),
    <<Prefix/binary, $-, N/binary>>.
