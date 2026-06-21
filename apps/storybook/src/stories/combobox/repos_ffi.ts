// Mock "search server" for the remote-combobox demo — filters + paginates the
// bundled `repos` dataset (300 popular GitHub repos) in-memory, standing in for a
// real `/search/repositories` endpoint. No network, no auth, no rate limit, so
// Storybook can deploy as a static site. A small simulated latency keeps the
// async/loading UX realistic. The dataset is deterministic, so the play tests run
// against this same server (no separate fixture needed).

import { repos } from "./repos"

declare global {
  // `var` is required to augment `globalThis`; `let`/`const` don't work here.
  var __vitest_browser__: boolean | undefined
}

const PER_PAGE = 20
// A realistic round-trip in the dev UI (exercises the spinner/loading states);
// instant under Vitest so the timing-sensitive play tests don't flake.
const latencyMs = (): number => (globalThis.__vitest_browser__ ? 0 : 350)

// The host's default "browse" query is a `stars:>…` qualifier — treat that (and
// an empty query) as "all repos" (the dataset is already star-sorted). Otherwise
// match the typed term as a case-insensitive substring of the full name.
function match(query: string): typeof repos {
  const q = query.trim().toLowerCase()
  if (q === "" || q.startsWith("stars:")) return repos
  return repos.filter((r) => r.full_name.toLowerCase().includes(q))
}

export function searchRepos(
  query: string,
  page: number,
  onOk: (json: unknown) => void,
  _onErr: (message: string) => void,
): void {
  // Simulate a server round-trip so the spinner/loading states are exercised.
  setTimeout(() => {
    const all = match(query)
    const start = (page - 1) * PER_PAGE
    const items = all.slice(start, start + PER_PAGE)
    // Same envelope as the real GitHub search API (the Gleam decoder reads
    // `full_name` + `total_count`; the extra fields are there for custom items).
    onOk({ total_count: all.length, items })
  }, latencyMs())
}
