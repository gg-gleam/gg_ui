import type { Meta, StoryObj } from "@storybook/html-vite"
import { mountLustre } from "../../../.storybook/lustre-mount"
import {
  mount_input_group_alignments,
  mount_input_group_invalid,
  mount_input_group_playground,
} from "./input_group.gleam"

type AlignArg = "inline-start" | "inline-end" | "block-start" | "block-end"

interface InputGroupArgs {
  align: AlignArg
}

const aligns: AlignArg[] = [
  "inline-start",
  "inline-end",
  "block-start",
  "block-end",
]

const meta: Meta<InputGroupArgs> = {
  title: "Components/InputGroup",
  args: { align: "inline-start" },
  argTypes: {
    align: { control: { type: "select" }, options: aligns },
  },
}

export default meta

type Story = StoryObj<InputGroupArgs>

/** Drive the addon `align` live from the controls. The glyph follows the Icon
 *  set / variant toolbar globals. */
export const Playground: Story = {
  render: ({ align }, { globals }) => {
    const { iconSet, iconVariant } = globals as {
      iconSet: string
      iconVariant: string
    }
    return mountLustre((selector) =>
      mount_input_group_playground(selector, align, iconSet, iconVariant),
    )
  },
}

/** Leading icon, trailing icon button, trailing text, and both edges at once. */
export const Alignments: Story = {
  parameters: { controls: { disable: true } },
  render: (_args, { globals }) => {
    const { iconSet, iconVariant } = globals as {
      iconSet: string
      iconVariant: string
    }
    return mountLustre((selector) =>
      mount_input_group_alignments(selector, iconSet, iconVariant),
    )
  },
}

/** Error state: a slotted `aria-invalid` control turns the whole group
 *  destructive (border statically; the ring on focus). */
export const Invalid: Story = {
  parameters: { controls: { disable: true } },
  render: (_args, { globals }) => {
    const { iconSet, iconVariant } = globals as {
      iconSet: string
      iconVariant: string
    }
    return mountLustre((selector) =>
      mount_input_group_invalid(selector, iconSet, iconVariant),
    )
  },
}
