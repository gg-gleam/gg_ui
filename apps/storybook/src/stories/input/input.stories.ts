import type { Meta, StoryObj } from "@storybook/html-vite"
import { expect, within } from "storybook/test"
import { mountLustre } from "../../../.storybook/lustre-mount"
import {
  mount_input_playground,
  mount_input_states,
  mount_input_types,
} from "./input.gleam"

const types = ["text", "email", "password", "number", "time", "date", "search"]

interface InputArgs {
  type: string
  placeholder: string
  disabled: boolean
  invalid: boolean
}

const meta: Meta<InputArgs> = {
  title: "Components/Input",
  args: {
    type: "text",
    placeholder: "Type here",
    disabled: false,
    invalid: false,
  },
  argTypes: {
    type: { control: { type: "select" }, options: types },
    placeholder: { control: { type: "text" } },
    disabled: { control: { type: "boolean" } },
    invalid: { control: { type: "boolean" } },
  },
}
export default meta

type Story = StoryObj<InputArgs>

/** A single input bound to the controls (type / placeholder / disabled / invalid). */
export const Playground: Story = {
  render: ({ type, placeholder, disabled, invalid }) =>
    mountLustre((selector) =>
      mount_input_playground(selector, type, placeholder, disabled, invalid),
    ),
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(canvas.getByRole("textbox")).toBeVisible()
  },
}

/** The native input types the recipe covers. */
export const Types: Story = {
  parameters: { controls: { disable: true } },
  render: () => mountLustre(mount_input_types),
}

/** Default, `aria-invalid` (destructive ring), and disabled. */
export const States: Story = {
  parameters: { controls: { disable: true } },
  render: () => mountLustre(mount_input_states),
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(canvas.getByDisplayValue("Invalid value")).toHaveAttribute(
      "aria-invalid",
      "true",
    )
    await expect(canvas.getByDisplayValue("Disabled")).toBeDisabled()
  },
}
