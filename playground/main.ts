// Vite entry for the dev playground. `vite-plugin-gleam` resolves the `.gleam`
// import to its compiled output; the theme stylesheet supplies the tokens the
// styled components reference.
import "../src/gg_ui/theme.css";
import { main } from "../src/playground.gleam";

main();
