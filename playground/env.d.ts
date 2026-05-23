// Ambient declarations so the TS tooling accepts the playground glue imports.
// Vite resolves these at build time; here we just give them minimal types.
declare module "*.gleam" {
  export const main: () => void;
}

declare module "*.css";
