import type { StorybookConfig } from "@storybook/html-vite";

// Storybook reuses our `vite.config.ts` (vite-plugin-gleam + @tailwindcss/vite)
// via the html-vite framework, so `.gleam` imports and Tailwind utilities work
// inside stories just like in the app.
const config: StorybookConfig = {
  framework: "@storybook/html-vite",
  stories: ["../src/**/*.stories.@(ts|tsx)"],
};

export default config;
