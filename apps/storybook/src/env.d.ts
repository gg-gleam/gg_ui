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

  // input-group stories — addon glyphs follow the icon globals.
  export const mount_input_group_playground: (
    selector: string,
    align: string,
    iconSet: string,
    iconVariant: string,
  ) => void
  export const mount_input_group_alignments: MountWithIcons
  export const mount_input_group_invalid: MountWithIcons

  // combobox story — stateful (lustre.application); side/align controls + icons.
  export const mount_combobox_playground: (
    selector: string,
    side: string,
    align: string,
    clearable: boolean,
  ) => void
  // PR 4 variants: multiple-select (chips), grouped sections, async status.
  type MountComboboxVariant = (
    selector: string,
    side: string,
    align: string,
  ) => void
  export const mount_combobox_multiple: MountComboboxVariant
  export const mount_combobox_grouped: MountComboboxVariant
  export const mount_combobox_grouped_multiple: MountComboboxVariant
  // remote (GitHub-search) combobox — no side/align controls, just a selector.
  export const mount_combobox_remote_single: (selector: string) => void
  export const mount_combobox_remote_multiple: (selector: string) => void
  // remote combobox with custom items (owner avatar + name) and custom chips.
  export const mount_combobox_avatars: (selector: string) => void

  // avatar stories — static (lustre.element). Playground takes size + shape + a
  // broken toggle + the fallback initials; the showcases just take a selector.
  export const mount_avatar_playground: (
    selector: string,
    size: string,
    shape: string,
    broken: boolean,
    initials: string,
  ) => void
  export const mount_avatar_sizes: MountStatic
  export const mount_avatar_shapes: MountStatic
  export const mount_avatar_fallbacks: MountStatic
  export const mount_avatar_badge: MountStatic
  export const mount_avatar_group: MountStatic
  export const mount_avatar_menu: MountStatic

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

  // text component stories
  // Playground: kitchen sink — one arg per tokenized axis (all strings except
  // italic/selectable booleans and lines).
  export const mount_text_playground: (
    selector: string,
    style: string,
    color: string,
    weight: string,
    align: string,
    transform: string,
    decoration: string,
    italic: boolean,
    truncate: string,
    lines: number,
    whitespace: string,
    wordBreak: string,
    wrap: string,
    opacity: string,
    selectable: boolean,
    content: string,
  ) => void
  export const mount_scale: MountStatic
  export const mount_colors: MountStatic
  export const mount_weights: MountStatic
  export const mount_as_element: MountStatic

  // icon catalog stories
  export const mount_with_icon: MountWithIcons // button (decorative glyphs)
  export const mount_gallery: MountWithIcons // icons/gallery
  export const mount_size_scale: MountWithIcons // icons/sizes — the full scale
}

declare module "*.css"

// @fontsource-variable/* packages are CSS-only (side-effect imports inject
// @font-face); they ship no JS/types. See .storybook/fonts.ts.
declare module "@fontsource-variable/*"
