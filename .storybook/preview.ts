// Load the theme tokens into every story so utilities like `bg-popover`,
// `text-foreground`, `border-input` resolve. Tailwind is processed by
// @tailwindcss/vite (configured in vite.config.ts).
import "../src/gg_ui/theme.css";

import type { Preview } from "@storybook/html-vite";

const preview: Preview = {
  parameters: {
    layout: "centered",
  },
};

export default preview;
