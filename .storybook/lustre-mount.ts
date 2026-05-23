// Bridge between Storybook's "return an HTMLElement" render contract and
// Lustre's selector-based `lustre.start`. Each story gets a fresh `<div>` with
// a unique id; we hand its selector to the Gleam `mount` function on the next
// microtask so the element is in the DOM before Lustre queries for it.

type GleamMount = (selector: string) => void;

let counter = 0;

export function mountLustre(mount: GleamMount): HTMLElement {
  counter += 1;
  const id = `gg-ui-story-${counter}`;
  const root = document.createElement("div");
  root.id = id;
  queueMicrotask(() => mount(`#${id}`));
  return root;
}
