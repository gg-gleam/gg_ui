// Ambient declarations for the TS tooling. Vite resolves these at build time;
// here we only need names typed loosely. Add new `mount_*` exports as more
// story variants land.
declare module "*.gleam" {
  export const main: () => void

  // popover stories
  type MountWithPlacement = (
    selector: string,
    side: string,
    align: string,
  ) => void
  type MountWithPlacementAndArrow = (
    selector: string,
    side: string,
    align: string,
    arrow: boolean,
  ) => void
  // Basic additionally exposes the trigger's button variant/size controls.
  export const mount_basic: (
    selector: string,
    side: string,
    align: string,
    arrow: boolean,
    variant: string,
    size: string,
  ) => void
  // Terse drives side/align/arrow through the Options record-update spread.
  export const mount_terse: MountWithPlacementAndArrow
  export const mount_scroll_collision: MountWithPlacementAndArrow
  export const mount_imperative: MountWithPlacement

  // button stories
  type MountStatic = (selector: string) => void
  export const mount_variants: MountStatic
  export const mount_sizes: MountStatic
  export const mount_with_icon: MountStatic
  export const mount_as_link: MountStatic
  export const mount_playground: (
    selector: string,
    variant: string,
    size: string,
    disabled: boolean,
  ) => void
}

declare module "*.css"
