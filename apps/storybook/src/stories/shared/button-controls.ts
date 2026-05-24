// Shared Storybook control vocabulary for the styled `Button`'s variant / size.
//
// Mirrors the Gleam `gg_ui/ui/button` `Variant` / `Size` constructors; the
// Gleam `mount_*` functions lowercase these strings back into the typed enums
// (each with a safe fallback). Reused by every story whose component embeds a
// `Button` — the button stories themselves and any component that renders one
// (e.g. the popover trigger) — so the option lists and the argTypes fragment
// live in exactly one place instead of being re-declared per story file.

export const buttonVariants = [
  "default",
  "destructive",
  "outline",
  "secondary",
  "ghost",
  "link",
] as const

export const buttonSizes = [
  "default",
  "xs",
  "sm",
  "lg",
  "icon",
  "icon-xs",
  "icon-sm",
  "icon-lg",
] as const

export type ButtonVariantArg = (typeof buttonVariants)[number]
export type ButtonSizeArg = (typeof buttonSizes)[number]

// Drop into a story `meta`'s `argTypes` via spread. Carries only the control
// shape + options (no default value — defaults stay in each story's `args`, so
// a button can default to `default`/`default` while a popover trigger defaults
// to `outline`/`default`).
export const buttonVariantSizeArgTypes = {
  variant: { control: { type: "select" }, options: buttonVariants },
  size: { control: { type: "select" }, options: buttonSizes },
} as const
