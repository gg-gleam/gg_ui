//// gg_ui's public positioning vocabulary — the **facade** over
//// `gg_base_ui/positioning`. Consumers name `Side` / `Align` and pass them
//// **independently** (never a combined value); the styled components convert to
//// the headless `Placement` at the seam via `to_base` before handing
//// positioning down to `gg_base_ui`. Popover uses this today; tooltip / menu /
//// select reuse it later.
////
//// Why gg_ui owns its own copy rather than re-exporting: Gleam can't re-export
//// a *constructor*, so a `pub type Side = base.Side` alias would still force
//// callers to write `gg_base_ui/...{Top}`. Defining the enums here (plus the
//// one-way `to_base` mapping) is the only way to keep `gg_base_ui` a true
//// internal dependency. Mirrors how the styled `button` owns its own
//// `Variant` / `Size` rather than leaking the headless button's types.

import gg_base_ui/positioning/positioning as base

/// Which side of the anchor the floating element opens on.
pub type Side {
  Top
  Right
  Bottom
  Left
}

/// How the floating element aligns along the anchor's cross axis.
pub type Align {
  Start
  Center
  End
}

/// Combine a `Side` + `Align` into the headless `Placement` — the internal seam
/// the styled components cross before handing positioning to `gg_base_ui`.
/// Callers pass side and align separately; they never construct a combined
/// value, and this isn't part of the consumer-facing surface.
pub fn to_base(side: Side, align: Align) -> base.Placement {
  base.Placement(side_to_base(side), align_to_base(align))
}

fn side_to_base(side: Side) -> base.Side {
  case side {
    Top -> base.Top
    Right -> base.Right
    Bottom -> base.Bottom
    Left -> base.Left
  }
}

fn align_to_base(align: Align) -> base.Align {
  case align {
    Start -> base.Start
    Center -> base.Center
    End -> base.End
  }
}
