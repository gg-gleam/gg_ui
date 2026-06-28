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
    padding: string,
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

  // dialog stories — Playground wires the closedby/role/close-button controls
  // plus the trigger's variant/size; Alert + Imperative are selector-only.
  export const mount_dialog_playground: (
    selector: string,
    text: string,
    dismiss: string,
    role: string,
    closeButton: boolean,
    variant: string,
    size: string,
  ) => void
  // shadcn doc examples — all selector-only static renders.
  export const mount_dialog_demo: MountStatic
  export const mount_dialog_close_button: MountStatic
  export const mount_dialog_no_close_button: MountStatic
  export const mount_dialog_sticky_footer: MountStatic
  export const mount_dialog_scrollable: MountStatic
  export const mount_dialog_rtl: MountStatic
  // Controlled (lustre.application) dialog that lazily renders its body on open.
  export const mount_dialog_lazy_content: MountStatic

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

  // calendar story — stateful (lustre.application). Playground takes the
  // week-start / show-outside / mode / caption / months controls; the showcases
  // are selector-only.
  export const mount_calendar_playground: (
    selector: string,
    weekStart: string,
    showOutside: boolean,
    mode: string,
    caption: string,
    months: number,
  ) => void
  export const mount_calendar_with_selected: MountStatic
  export const mount_calendar_range: (
    selector: string,
    showOutside: boolean,
  ) => void
  export const mount_calendar_multiple: MountStatic
  export const mount_calendar_count_bounds: MountStatic
  export const mount_calendar_two_months: MountStatic
  export const mount_calendar_week_numbers: MountStatic
  export const mount_calendar_required: (
    selector: string,
    required: boolean,
  ) => void
  export const mount_calendar_dropdown: MountStatic
  export const mount_calendar_disabled: MountStatic
  export const mount_calendar_blocked: MountStatic
  export const mount_calendar_locale: (selector: string, locale: string) => void

  // date-picker stories — Popover + Calendar compositions (stateful).
  export const mount_date_picker_single: MountStatic
  export const mount_date_picker_dob: MountStatic
  export const mount_date_picker_time: MountStatic
  export const mount_date_picker_rtl: MountStatic
  export const mount_date_picker_input: MountStatic
  export const mount_date_picker_range: MountStatic

  // input stories — static styled native <input>.
  export const mount_input_playground: (
    selector: string,
    type: string,
    placeholder: string,
    disabled: boolean,
    invalid: boolean,
  ) => void
  export const mount_input_types: MountStatic
  export const mount_input_states: MountStatic

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
  export const mount_class_override: MountWithIcons
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
