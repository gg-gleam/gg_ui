import tailwindcss from "@tailwindcss/vite"
import type { PluginOption } from "vite"
import gleam from "vite-plugin-gleam"

export const sharedPlugins: PluginOption[] = [
  gleam({}) as PluginOption,
  tailwindcss(),
]
