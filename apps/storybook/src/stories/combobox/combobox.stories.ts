import type { Meta, StoryObj } from "@storybook/html-vite"
import { mountLustre } from "../../../.storybook/lustre-mount"
import { mount_combobox_playground } from "./combobox.gleam"

type SideArg = "top" | "right" | "bottom" | "left"
type AlignArg = "start" | "center" | "end"

interface ComboboxArgs {
  side: SideArg
  align: AlignArg
  clearable: boolean
}

const sides: SideArg[] = ["top", "right", "bottom", "left"]
const aligns: AlignArg[] = ["start", "center", "end"]

const meta: Meta<ComboboxArgs> = {
  title: "Components/Combobox",
  args: { side: "bottom", align: "start", clearable: false },
  argTypes: {
    side: { control: { type: "select" }, options: sides },
    align: { control: { type: "select" }, options: aligns },
    clearable: { control: { type: "boolean" } },
  },
}

export default meta

type Story = StoryObj<ComboboxArgs>

/** Type to filter, arrow/Enter to pick, click an option, Escape to dismiss.
 *  Chevron / check / clear icons are built in (lucide), not story-supplied. */
export const Playground: Story = {
  render: ({ side, align, clearable }) =>
    mountLustre((selector) =>
      mount_combobox_playground(selector, side, align, clearable),
    ),
}
