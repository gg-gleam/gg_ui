// Story-local FFI for the remote-combobox example: GitHub repository search.
// Live against the real API in the dev Storybook; deterministically **mocked**
// under Vitest by setting `globalThis.__comboboxFetchMock` (see the story). The
// parsed JSON is handed back to the Gleam decoder via `onOk` (kept opaque here so
// the shape lives in one place — the Gleam side).
//
// GitHub search requires a non-empty `q` and caps results at 1000
// (`page * per_page <= 1000`); the host supplies a default query and stops
// paging at `total_count`.

type FetchMock = (query: string, page: number) => Promise<unknown>

declare global {
  // `var` is required to augment `globalThis`; `let`/`const` don't work here.
  var __comboboxFetchMock: FetchMock | undefined
}

export function searchRepos(
  query: string,
  page: number,
  onOk: (json: unknown) => void,
  onErr: (message: string) => void,
): void {
  const mock = globalThis.__comboboxFetchMock
  if (mock) {
    mock(query, page)
      .then(onOk)
      .catch((err: unknown) => onErr(String(err)))
    return
  }

  const url =
    `https://api.github.com/search/repositories?q=${encodeURIComponent(query)}` +
    `&page=${page}&per_page=20`
  fetch(url, { headers: { Accept: "application/vnd.github+json" } })
    .then((res) => {
      if (!res.ok) throw new Error(`GitHub ${res.status}`)
      return res.json()
    })
    .then(onOk)
    .catch((err: unknown) =>
      onErr(err instanceof Error ? err.message : String(err)),
    )
}
