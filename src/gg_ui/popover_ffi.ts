// Popover FFI: Floating UI positioning + dismissal wiring.
//
// Referenced from Gleam via `@external(javascript, "/src/gg_ui/popover_ffi",
// …)`. `gleam build` passes that absolute path through verbatim; Vite (rooted
// at the package) resolves it to this `.ts` and transpiles it. Keep every
// export's name in sync with the Gleam bindings in `popover/positioning.gleam`.

import {
  autoUpdate,
  computePosition,
  flip,
  offset,
  type Placement,
  shift,
} from "@floating-ui/dom";

// content id -> teardown fn, so re-opening or closing never leaks listeners.
const positioners = new Map<string, () => void>();
const dismissers = new Map<string, () => void>();

export function startPositioning(
  anchorId: string,
  contentId: string,
  placement: string,
): void {
  stopPositioning(contentId);

  const anchor = document.getElementById(anchorId);
  const content = document.getElementById(contentId);
  if (anchor === null || content === null) return;

  // Fixed strategy keeps the content correctly placed regardless of any
  // scrolling/overflow ancestor, without needing a portal for this first pass.
  content.style.position = "fixed";
  content.style.top = "0";
  content.style.left = "0";

  const stop = autoUpdate(anchor, content, () => {
    void computePosition(anchor, content, {
      placement: placement as Placement,
      middleware: [offset(6), flip(), shift({ padding: 8 })],
    }).then(({ x, y }) => {
      content.style.transform = `translate(${Math.round(x)}px, ${Math.round(y)}px)`;
    });
  });

  positioners.set(contentId, stop);
}

export function stopPositioning(contentId: string): void {
  const stop = positioners.get(contentId);
  if (stop !== undefined) {
    stop();
    positioners.delete(contentId);
  }
}

export function startDismiss(
  anchorId: string,
  contentId: string,
  onDismiss: () => void,
): void {
  stopDismiss(contentId);

  const onPointerDown = (event: PointerEvent): void => {
    const target = event.target as Node | null;
    const anchor = document.getElementById(anchorId);
    const content = document.getElementById(contentId);
    if (content?.contains(target) === true) return;
    if (anchor?.contains(target) === true) return;
    onDismiss();
  };

  const onKeyDown = (event: KeyboardEvent): void => {
    if (event.key === "Escape") onDismiss();
  };

  // Capture phase so we win even if inner handlers stop propagation.
  document.addEventListener("pointerdown", onPointerDown, true);
  document.addEventListener("keydown", onKeyDown, true);

  dismissers.set(contentId, () => {
    document.removeEventListener("pointerdown", onPointerDown, true);
    document.removeEventListener("keydown", onKeyDown, true);
  });
}

export function stopDismiss(contentId: string): void {
  const stop = dismissers.get(contentId);
  if (stop !== undefined) {
    stop();
    dismissers.delete(contentId);
  }
}
