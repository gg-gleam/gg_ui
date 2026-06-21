import type { Meta, StoryObj } from "@storybook/html-vite"
import { expect, userEvent, waitFor, within } from "storybook/test"
import { mountLustre } from "../../../.storybook/lustre-mount"
import { mount_combobox_avatars } from "./combobox_avatars.gleam"

// Remote combobox with custom items (owner avatar + repo name) and custom chips
// (avatar + owner). Same mock GitHub-search server as the plain remote story; the
// play exercises that the avatar markup renders in both the options and the chips.

const meta: Meta = {
  title: "Components/Combobox",
  parameters: { controls: { disable: true } },
}
export default meta
type Story = StoryObj

declare global {
  // `var` is required to augment `globalThis`; `let`/`const` don't work here.
  var __vitest_browser__: boolean | undefined
}
const inVitestBrowser = (): boolean => globalThis.__vitest_browser__ === true
const testOnly =
  (fn: NonNullable<Story["play"]>): NonNullable<Story["play"]> =>
  async (context) => {
    if (inVitestBrowser() || context.globals.runPlay === "on") {
      await fn(context)
    }
  }

const FIRST_REPO = "codecrafters-io/build-your-own-x"
const PER_PAGE = 20

const isOpen = (canvasElement: HTMLElement): boolean => {
  const el = canvasElement.querySelector<HTMLElement>("[popover]")
  if (!el) throw new Error("popup not mounted")
  return el.matches(":popover-open")
}

export const RemoteAvatars: Story = {
  name: "Remote (custom items + chips)",
  render: () => mountLustre((selector) => mount_combobox_avatars(selector)),
  play: testOnly(async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    const input = canvas.getByRole<HTMLInputElement>("combobox")

    // Open → the default page loads, and each option carries an avatar image.
    await userEvent.click(input)
    await waitFor(() => expect(isOpen(canvasElement)).toBe(true))
    await waitFor(
      () => expect(canvas.getAllByRole("option")).toHaveLength(PER_PAGE),
      { timeout: 2000 },
    )
    {
      const option = canvas.getAllByRole("option")[0]
      expect(option.querySelector("[data-slot='avatar-image']")).not.toBeNull()
    }

    // Pick one → a chip appears, and the chip also carries an avatar.
    await userEvent.click(canvas.getByText(FIRST_REPO))
    await expect(isOpen(canvasElement)).toBe(true)
    await waitFor(() => {
      const chip = canvasElement.querySelector<HTMLElement>(
        "[data-slot='combobox-chip']",
      )
      if (!chip) throw new Error("chip not mounted")
      expect(chip.querySelector("[data-slot='avatar-image']")).not.toBeNull()
      expect(
        within(chip).getByRole("button", { name: `Remove ${FIRST_REPO}` }),
      ).toBeVisible()
    })
  }),
}
