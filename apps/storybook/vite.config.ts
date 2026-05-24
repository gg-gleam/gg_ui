import { defineConfig } from "vite"
import { sharedPlugins } from "./vite-plugins"

export default defineConfig({
  plugins: [...sharedPlugins],
})
