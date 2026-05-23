// Ambient declarations for the TS tooling. Vite resolves these at build time;
// here we only need names typed loosely. Add new `mount_*` exports as more
// story variants land.
declare module "*.gleam" {
  export const main: () => void;
  export const mount_basic: (selector: string) => void;
  export const mount_clipping: (selector: string) => void;
}

declare module "*.css";
