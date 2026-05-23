import tailwindcss from "@tailwindcss/vite";
import { defineConfig } from "vite";
import gleam from "vite-plugin-gleam";

// `gleam()` compiles the Gleam sources and lets `.gleam` modules be imported
// directly; their emitted FFI imports (e.g. "/src/gg_ui/popover_ffi") resolve
// against this project root, where Vite transpiles the matching `.ts`.
export default defineConfig({
  plugins: [gleam({}), tailwindcss()],
});
