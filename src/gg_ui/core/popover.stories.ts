import type { Meta, StoryObj } from "@storybook/html-vite";
import { mountLustre } from "../../../.storybook/lustre-mount";
import {
  mount_basic,
  mount_clipping,
} from "../../stories/popover.gleam";

const meta: Meta = {
  title: "Core/Popover",
};

export default meta;

type Story = StoryObj;

export const Basic: Story = {
  render: () => mountLustre(mount_basic),
};

/// Trigger sits inside an `overflow: hidden` + `transform` wrapper — the
/// classic clip trap. The popover should still appear in the top layer,
/// anchored below the trigger.
export const InsideClippingBox: Story = {
  render: () => mountLustre(mount_clipping),
};
