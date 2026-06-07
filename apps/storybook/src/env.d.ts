// Ambient declarations for the TS tooling. Vite resolves these at build time;
// here we only need names typed loosely. Add new `mount_*` exports as more
// story variants land.
declare module "*.gleam" {
  export const main: () => void

  // Shared mount shapes.
  type MountStatic = (selector: string) => void
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
  // Icon-aware stories take the `iconSet` / `iconVariant` toolbar globals as
  // their trailing two args, threaded in from the `.stories.ts` render.
  type MountWithIcons = (
    selector: string,
    iconSet: string,
    iconVariant: string,
  ) => void

  // popover stories — triggers/close carry catalog glyphs that follow the icon
  // globals, so the placement mounts also take iconSet/iconVariant.
  export const mount_basic: (
    selector: string,
    side: string,
    align: string,
    arrow: boolean,
    variant: string,
    size: string,
    iconSet: string,
    iconVariant: string,
  ) => void
  // Terse stays text-only (it demonstrates the terse, no-icon API).
  export const mount_terse: MountWithPlacementAndArrow
  export const mount_scroll_collision: (
    selector: string,
    side: string,
    align: string,
    arrow: boolean,
    iconSet: string,
    iconVariant: string,
  ) => void
  export const mount_imperative: (
    selector: string,
    side: string,
    align: string,
    iconSet: string,
    iconVariant: string,
  ) => void

  // tooltip stories
  // Basic additionally exposes the trigger's variant/size + the open delay (ms).
  export const mount_tooltip_basic: (
    selector: string,
    side: string,
    align: string,
    arrow: boolean,
    variant: string,
    size: string,
    delay: number,
  ) => void
  export const mount_sides: MountStatic
  export const mount_icon: (
    selector: string,
    side: string,
    iconSet: string,
    iconVariant: string,
  ) => void

  // button stories
  export const mount_variants: MountStatic
  export const mount_as_link: MountStatic
  export const mount_sizes: MountWithIcons // icon-only buttons follow the globals
  export const mount_playground: (
    selector: string,
    variant: string,
    size: string,
    disabled: boolean,
    iconSet: string,
    iconVariant: string,
  ) => void

  // icon catalog stories
  export const mount_with_icon: MountWithIcons // button (decorative glyphs)
  export const mount_gallery: MountWithIcons // icons/gallery
}

declare module "*.css"
