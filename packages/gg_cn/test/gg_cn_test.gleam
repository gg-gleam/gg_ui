import gleeunit
import gleeunit/should

import gg_cn

pub fn main() {
  gleeunit.main()
}

// One shared merger per assertion is fine for tests; `new()` is cheap enough at
// test scale and keeps each case self-contained.
fn m(input: String) -> String {
  gg_cn.new() |> gg_cn.tw_merge(input)
}

// --- tw_merge (tw-merge.test.ts) ---------------------------------------------

pub fn tw_merge_test() {
  m("mix-blend-normal mix-blend-multiply") |> should.equal("mix-blend-multiply")
  m("h-10 h-min") |> should.equal("h-min")
  m("stroke-black stroke-1") |> should.equal("stroke-black stroke-1")
  m("stroke-2 stroke-[3]") |> should.equal("stroke-[3]")
  m("outline-black outline-1") |> should.equal("outline-black outline-1")
  m("grayscale-0 grayscale-[50%]") |> should.equal("grayscale-[50%]")
  m("grow grow-[2]") |> should.equal("grow-[2]")
}

// --- conflicts across class groups -------------------------------------------

pub fn conflicts_across_class_groups_test() {
  m("inset-1 inset-x-1") |> should.equal("inset-1 inset-x-1")
  m("inset-x-1 inset-1") |> should.equal("inset-1")
  m("inset-x-1 left-1 inset-1") |> should.equal("inset-1")
  m("inset-x-1 inset-1 left-1") |> should.equal("inset-1 left-1")
  m("inset-x-1 right-1 inset-1") |> should.equal("inset-1")
  m("inset-x-1 right-1 inset-x-1") |> should.equal("inset-x-1")
  m("inset-x-1 right-1 inset-y-1")
  |> should.equal("inset-x-1 right-1 inset-y-1")
  m("right-1 inset-x-1 inset-y-1") |> should.equal("inset-x-1 inset-y-1")
  m("inset-x-1 hover:left-1 inset-1") |> should.equal("hover:left-1 inset-1")
}

pub fn ring_and_shadow_no_conflict_test() {
  m("ring shadow") |> should.equal("ring shadow")
  m("ring-2 shadow-md") |> should.equal("ring-2 shadow-md")
  m("shadow ring") |> should.equal("shadow ring")
  m("shadow-md ring-2") |> should.equal("shadow-md ring-2")
}

pub fn touch_conflicts_test() {
  m("touch-pan-x touch-pan-right") |> should.equal("touch-pan-right")
  m("touch-none touch-pan-x") |> should.equal("touch-pan-x")
  m("touch-pan-x touch-none") |> should.equal("touch-none")
  m("touch-pan-x touch-pan-y touch-pinch-zoom")
  |> should.equal("touch-pan-x touch-pan-y touch-pinch-zoom")
  m("touch-manipulation touch-pan-x touch-pan-y touch-pinch-zoom")
  |> should.equal("touch-pan-x touch-pan-y touch-pinch-zoom")
  m("touch-pan-x touch-pan-y touch-pinch-zoom touch-auto")
  |> should.equal("touch-auto")
}

pub fn line_clamp_conflicts_test() {
  m("overflow-auto inline line-clamp-1") |> should.equal("line-clamp-1")
  m("line-clamp-1 overflow-auto inline")
  |> should.equal("line-clamp-1 overflow-auto inline")
}

// --- class group conflicts ----------------------------------------------------

pub fn same_group_conflicts_test() {
  m("overflow-x-auto overflow-x-hidden") |> should.equal("overflow-x-hidden")
  m("basis-full basis-auto") |> should.equal("basis-auto")
  m("w-full w-fit") |> should.equal("w-fit")
  m("overflow-x-auto overflow-x-hidden overflow-x-scroll")
  |> should.equal("overflow-x-scroll")
  m("overflow-x-auto hover:overflow-x-hidden overflow-x-scroll")
  |> should.equal("hover:overflow-x-hidden overflow-x-scroll")
  m(
    "overflow-x-auto hover:overflow-x-hidden hover:overflow-x-auto overflow-x-scroll",
  )
  |> should.equal("hover:overflow-x-auto overflow-x-scroll")
  m("col-span-1 col-span-full") |> should.equal("col-span-full")
  m("gap-2 gap-px basis-px basis-3") |> should.equal("gap-px basis-3")
}

pub fn font_variant_numeric_test() {
  m("lining-nums tabular-nums diagonal-fractions")
  |> should.equal("lining-nums tabular-nums diagonal-fractions")
  m("normal-nums tabular-nums diagonal-fractions")
  |> should.equal("tabular-nums diagonal-fractions")
  m("tabular-nums diagonal-fractions normal-nums")
  |> should.equal("normal-nums")
  m("tabular-nums proportional-nums") |> should.equal("proportional-nums")
}

// --- arbitrary values ---------------------------------------------------------

pub fn arbitrary_value_conflicts_test() {
  m("m-[2px] m-[10px]") |> should.equal("m-[10px]")
  m(
    "m-[2px] m-[11svmin] m-[12in] m-[13lvi] m-[14vb] m-[15vmax] m-[16mm] m-[17%] m-[18em] m-[19px] m-[10dvh]",
  )
  |> should.equal("m-[10dvh]")
  m("h-[10px] h-[11cqw] h-[12cqh] h-[13cqi] h-[14cqb] h-[15cqmin] h-[16cqmax]")
  |> should.equal("h-[16cqmax]")
  m("z-20 z-[99]") |> should.equal("z-[99]")
  m("my-[2px] m-[10rem]") |> should.equal("m-[10rem]")
  m("cursor-pointer cursor-[grab]") |> should.equal("cursor-[grab]")
  m("m-[2px] m-[calc(100%-var(--arbitrary))]")
  |> should.equal("m-[calc(100%-var(--arbitrary))]")
  m("m-[2px] m-[length:var(--mystery-var)]")
  |> should.equal("m-[length:var(--mystery-var)]")
  m("opacity-10 opacity-[0.025]") |> should.equal("opacity-[0.025]")
  m("scale-75 scale-[1.7]") |> should.equal("scale-[1.7]")
  m("brightness-90 brightness-[1.75]") |> should.equal("brightness-[1.75]")
  m("min-h-[0.5px] min-h-[0]") |> should.equal("min-h-[0]")
  m("text-[0.5px] text-[color:0]")
  |> should.equal("text-[0.5px] text-[color:0]")
  m("text-[0.5px] text-(--my-0)") |> should.equal("text-[0.5px] text-(--my-0)")
}

pub fn arbitrary_length_labels_test() {
  m("hover:m-[2px] hover:m-[length:var(--c)]")
  |> should.equal("hover:m-[length:var(--c)]")
  m("hover:focus:m-[2px] focus:hover:m-[length:var(--c)]")
  |> should.equal("focus:hover:m-[length:var(--c)]")
  m("border-b border-[color:rgb(var(--color-gray-500-rgb)/50%))]")
  |> should.equal("border-b border-[color:rgb(var(--color-gray-500-rgb)/50%))]")
  m("border-[color:rgb(var(--color-gray-500-rgb)/50%))] border-b")
  |> should.equal("border-[color:rgb(var(--color-gray-500-rgb)/50%))] border-b")
  m(
    "border-b border-[color:rgb(var(--color-gray-500-rgb)/50%))] border-some-coloooor",
  )
  |> should.equal("border-b border-some-coloooor")
}

pub fn complex_arbitrary_value_conflicts_test() {
  m("grid-rows-[1fr,auto] grid-rows-2") |> should.equal("grid-rows-2")
  m("grid-rows-[repeat(20,minmax(0,1fr))] grid-rows-3")
  |> should.equal("grid-rows-3")
}

pub fn ambiguous_arbitrary_values_test() {
  m("mt-2 mt-[calc(theme(fontSize.4xl)/1.125)]")
  |> should.equal("mt-[calc(theme(fontSize.4xl)/1.125)]")
  m("p-2 p-[calc(theme(fontSize.4xl)/1.125)_10px]")
  |> should.equal("p-[calc(theme(fontSize.4xl)/1.125)_10px]")
  m("mt-2 mt-[length:theme(someScale.someValue)]")
  |> should.equal("mt-[length:theme(someScale.someValue)]")
  m("mt-2 mt-[theme(someScale.someValue)]")
  |> should.equal("mt-[theme(someScale.someValue)]")
  m("text-2xl text-[length:theme(someScale.someValue)]")
  |> should.equal("text-[length:theme(someScale.someValue)]")
  m("text-2xl text-[calc(theme(fontSize.4xl)/1.125)]")
  |> should.equal("text-[calc(theme(fontSize.4xl)/1.125)]")
  m(
    "bg-cover bg-[percentage:30%] bg-[size:200px_100px] bg-[length:200px_100px]",
  )
  |> should.equal("bg-[percentage:30%] bg-[length:200px_100px]")
  m(
    "bg-none bg-[url(.)] bg-[image:.] bg-[url:.] bg-[linear-gradient(.)] bg-linear-to-r",
  )
  |> should.equal("bg-linear-to-r")
  m(
    "border-[color-mix(in_oklab,var(--background),var(--calendar-color)_30%)] border",
  )
  |> should.equal(
    "border-[color-mix(in_oklab,var(--background),var(--calendar-color)_30%)] border",
  )
  m("font-[400] font-[600]") |> should.equal("font-[600]")
  m("font-[var(--a)] font-[var(--b)]") |> should.equal("font-[var(--b)]")
  m("font-[weight:var(--a)] font-[var(--b)]") |> should.equal("font-[var(--b)]")
  m("font-[400] font-[weight:var(--b)]")
  |> should.equal("font-[weight:var(--b)]")
  m("font-[weight:var(--a)] font-[weight:var(--b)]")
  |> should.equal("font-[weight:var(--b)]")
  m("font-[family-name:var(--a)] font-[var(--b)]")
  |> should.equal("font-[family-name:var(--a)] font-[var(--b)]")
}

pub fn arbitrary_custom_properties_test() {
  m("bg-red bg-(--other-red) bg-bottom bg-(position:-my-pos)")
  |> should.equal("bg-(--other-red) bg-(position:-my-pos)")
  m(
    "shadow-xs shadow-(shadow:--something) shadow-red shadow-(--some-other-shadow) shadow-(color:--some-color)",
  )
  |> should.equal("shadow-(--some-other-shadow) shadow-(color:--some-color)")
  m("font-(--a) font-(--b)") |> should.equal("font-(--b)")
  m("font-(weight:--a) font-(--b)") |> should.equal("font-(--b)")
  m("font-(family-name:--a) font-(--b)")
  |> should.equal("font-(family-name:--a) font-(--b)")
}

// --- important modifier -------------------------------------------------------

pub fn important_modifier_test() {
  m("font-medium! font-bold!") |> should.equal("font-bold!")
  m("font-medium! font-bold! font-thin") |> should.equal("font-bold! font-thin")
  m("right-2! -inset-x-px!") |> should.equal("-inset-x-px!")
  m("focus:inline! focus:block!") |> should.equal("focus:block!")
  m("[--my-var:20px]! [--my-var:30px]!") |> should.equal("[--my-var:30px]!")
  m("font-medium! !font-bold") |> should.equal("!font-bold")
  m("!font-medium !font-bold") |> should.equal("!font-bold")
  m("!font-medium !font-bold font-thin") |> should.equal("!font-bold font-thin")
  m("!right-2 !-inset-x-px") |> should.equal("!-inset-x-px")
  m("focus:!inline focus:!block") |> should.equal("focus:!block")
  m("![--my-var:20px] ![--my-var:30px]") |> should.equal("![--my-var:30px]")
}

// --- modifiers ----------------------------------------------------------------

pub fn prefix_modifier_conflicts_test() {
  m("hover:block hover:inline") |> should.equal("hover:inline")
  m("hover:block hover:focus:inline")
  |> should.equal("hover:block hover:focus:inline")
  m("hover:block hover:focus:inline focus:hover:inline")
  |> should.equal("hover:block focus:hover:inline")
  m("focus-within:inline focus-within:block")
  |> should.equal("focus-within:block")
}

pub fn postfix_modifier_conflicts_test() {
  m("text-lg/7 text-lg/8") |> should.equal("text-lg/8")
  m("text-lg/none leading-9") |> should.equal("text-lg/none leading-9")
  m("leading-9 text-lg/none") |> should.equal("text-lg/none")
  m("w-full w-1/2") |> should.equal("w-1/2")
}

pub fn sort_modifiers_test() {
  m("c:d:e:block d:c:e:inline") |> should.equal("d:c:e:inline")
  m("*:before:block *:before:inline") |> should.equal("*:before:inline")
  m("*:before:block before:*:inline")
  |> should.equal("*:before:block before:*:inline")
  m("x:y:*:z:block y:x:*:z:inline") |> should.equal("y:x:*:z:inline")
}

// --- pseudo variants ----------------------------------------------------------

pub fn pseudo_variants_test() {
  m("empty:p-2 empty:p-3") |> should.equal("empty:p-3")
  m("hover:empty:p-2 hover:empty:p-3") |> should.equal("hover:empty:p-3")
  m("read-only:p-2 read-only:p-3") |> should.equal("read-only:p-3")
}

pub fn pseudo_variant_groups_test() {
  m("group-empty:p-2 group-empty:p-3") |> should.equal("group-empty:p-3")
  m("peer-empty:p-2 peer-empty:p-3") |> should.equal("peer-empty:p-3")
  m("group-empty:p-2 peer-empty:p-3")
  |> should.equal("group-empty:p-2 peer-empty:p-3")
  m("hover:group-empty:p-2 hover:group-empty:p-3")
  |> should.equal("hover:group-empty:p-3")
  m("group-read-only:p-2 group-read-only:p-3")
  |> should.equal("group-read-only:p-3")
}

// --- arbitrary properties -----------------------------------------------------

pub fn arbitrary_property_conflicts_test() {
  m("[paint-order:markers] [paint-order:normal]")
  |> should.equal("[paint-order:normal]")
  m("[paint-order:markers] [--my-var:2rem] [paint-order:normal] [--my-var:4px]")
  |> should.equal("[paint-order:normal] [--my-var:4px]")
}

pub fn arbitrary_property_conflicts_with_modifiers_test() {
  m("[paint-order:markers] hover:[paint-order:normal]")
  |> should.equal("[paint-order:markers] hover:[paint-order:normal]")
  m("hover:[paint-order:markers] hover:[paint-order:normal]")
  |> should.equal("hover:[paint-order:normal]")
  m("hover:focus:[paint-order:markers] focus:hover:[paint-order:normal]")
  |> should.equal("focus:hover:[paint-order:normal]")
  m(
    "[paint-order:markers] [paint-order:normal] [--my-var:2rem] lg:[--my-var:4px]",
  )
  |> should.equal("[paint-order:normal] [--my-var:2rem] lg:[--my-var:4px]")
  m("bg-[#B91C1C] bg-radial-[at_50%_75%] bg-radial-[at_25%_25%]")
  |> should.equal("bg-[#B91C1C] bg-radial-[at_25%_25%]")
}

pub fn complex_arbitrary_property_conflicts_test() {
  m("[-unknown-prop:::123:::] [-unknown-prop:url(https://hi.com)]")
  |> should.equal("[-unknown-prop:url(https://hi.com)]")
}

pub fn arbitrary_property_important_test() {
  m("![some:prop] [some:other]") |> should.equal("![some:prop] [some:other]")
  m("![some:prop] [some:other] [some:one] ![some:another]")
  |> should.equal("[some:one] ![some:another]")
}

// --- negative values ----------------------------------------------------------

pub fn negative_value_conflicts_test() {
  m("-m-2 -m-5") |> should.equal("-m-5")
  m("-top-12 -top-2000") |> should.equal("-top-2000")
  m("-m-2 m-auto") |> should.equal("m-auto")
  m("top-12 -top-69") |> should.equal("-top-69")
  m("-right-1 inset-x-1") |> should.equal("inset-x-1")
  m("hover:focus:-right-1 focus:hover:inset-x-1")
  |> should.equal("focus:hover:inset-x-1")
}

// --- non-conflicting & standalone --------------------------------------------

pub fn non_conflicting_classes_test() {
  m("border-t border-white/10") |> should.equal("border-t border-white/10")
  m("border-t border-white") |> should.equal("border-t border-white")
  m("text-3.5xl text-black") |> should.equal("text-3.5xl text-black")
}

pub fn standalone_classes_test() {
  m("inline block") |> should.equal("block")
  m("hover:block hover:inline") |> should.equal("hover:inline")
  m("hover:block hover:block") |> should.equal("hover:block")
  m("inline hover:inline focus:inline hover:block hover:focus:block")
  |> should.equal("inline focus:inline hover:block hover:focus:block")
  m("underline line-through") |> should.equal("line-through")
  m("line-through no-underline") |> should.equal("no-underline")
}

// --- non-tailwind classes -----------------------------------------------------

pub fn non_tailwind_classes_test() {
  m("non-tailwind-class inline block")
  |> should.equal("non-tailwind-class block")
  m("inline block inline-1") |> should.equal("block inline-1")
  m("inline block i-inline") |> should.equal("block i-inline")
  m("focus:inline focus:block focus:inline-1")
  |> should.equal("focus:block focus:inline-1")
}

// --- wonky inputs -------------------------------------------------------------

pub fn wonky_inputs_test() {
  m(" block") |> should.equal("block")
  m("block ") |> should.equal("block")
  m(" block ") |> should.equal("block")
  m("  block  px-2     py-4  ") |> should.equal("block px-2 py-4")
  m("block\npx-2") |> should.equal("block px-2")
  m("\nblock\npx-2\n") |> should.equal("block px-2")
  m("  block\n        \n        px-2   \n          py-4  ")
  |> should.equal("block px-2 py-4")
  m("\r  block\n\r        \n        px-2   \n          py-4  ")
  |> should.equal("block px-2 py-4")
}

// --- colors / content / per-side borders --------------------------------------

pub fn color_conflicts_test() {
  m("bg-grey-5 bg-hotpink") |> should.equal("bg-hotpink")
  m("hover:bg-grey-5 hover:bg-hotpink") |> should.equal("hover:bg-hotpink")
  m("stroke-[hsl(350_80%_0%)] stroke-[10px]")
  |> should.equal("stroke-[hsl(350_80%_0%)] stroke-[10px]")
}

pub fn content_utilities_test() {
  m("content-['hello'] content-[attr(data-content)]")
  |> should.equal("content-[attr(data-content)]")
}

pub fn per_side_border_colors_test() {
  m("border-t-some-blue border-t-other-blue")
  |> should.equal("border-t-other-blue")
  m("border-t-some-blue border-some-blue") |> should.equal("border-some-blue")
  m("border-some-blue border-s-some-blue")
  |> should.equal("border-some-blue border-s-some-blue")
  m("border-e-some-blue border-some-blue") |> should.equal("border-some-blue")
}

// --- tailwind css versions ----------------------------------------------------

pub fn v3_3_features_test() {
  m("text-red text-lg/7 text-lg/8") |> should.equal("text-red text-lg/8")
  m(
    "start-0 end-0 inset-0 ps-0 pe-0 p-0 ms-0 me-0 m-0 rounded-ss rounded-es rounded-s",
  )
  |> should.equal("inset-0 p-0 m-0 rounded-s")
  m("hyphens-auto hyphens-manual") |> should.equal("hyphens-manual")
  m(
    "from-0% from-10% from-[12.5%] via-0% via-10% via-[12.5%] to-0% to-10% to-[12.5%]",
  )
  |> should.equal("from-[12.5%] via-[12.5%] to-[12.5%]")
  m("from-0% from-red") |> should.equal("from-0% from-red")
  m(
    "list-image-none list-image-[url(./my-image.png)] list-image-[var(--value)]",
  )
  |> should.equal("list-image-[var(--value)]")
  m("caption-top caption-bottom") |> should.equal("caption-bottom")
  m("line-clamp-2 line-clamp-none line-clamp-[10]")
  |> should.equal("line-clamp-[10]")
  m("delay-150 delay-0 duration-150 duration-0")
  |> should.equal("delay-0 duration-0")
  m("justify-normal justify-center justify-stretch")
  |> should.equal("justify-stretch")
  m("content-normal content-center content-stretch")
  |> should.equal("content-stretch")
  m("whitespace-nowrap whitespace-break-spaces")
  |> should.equal("whitespace-break-spaces")
}

pub fn v3_4_features_test() {
  m("h-svh h-dvh w-svw w-dvw") |> should.equal("h-dvh w-dvw")
  m(
    "has-[[data-potato]]:p-1 has-[[data-potato]]:p-2 group-has-[:checked]:grid group-has-[:checked]:flex",
  )
  |> should.equal("has-[[data-potato]]:p-2 group-has-[:checked]:flex")
  m("text-wrap text-pretty") |> should.equal("text-pretty")
  m("w-5 h-3 size-10 w-12") |> should.equal("size-10 w-12")
  m("grid-cols-2 grid-cols-subgrid grid-rows-5 grid-rows-subgrid")
  |> should.equal("grid-cols-subgrid grid-rows-subgrid")
  m("min-w-0 min-w-50 min-w-px max-w-0 max-w-50 max-w-px")
  |> should.equal("min-w-px max-w-px")
  m("forced-color-adjust-none forced-color-adjust-auto")
  |> should.equal("forced-color-adjust-auto")
  m("appearance-none appearance-auto") |> should.equal("appearance-auto")
  m("float-start float-end clear-start clear-end")
  |> should.equal("float-end clear-end")
  m("*:p-10 *:p-20 hover:*:p-10 hover:*:p-20")
  |> should.equal("*:p-20 hover:*:p-20")
}

pub fn v4_0_features_test() {
  m("transform-3d transform-flat") |> should.equal("transform-flat")
  m("rotate-12 rotate-x-2 rotate-none rotate-y-3")
  |> should.equal("rotate-x-2 rotate-none rotate-y-3")
  m("perspective-dramatic perspective-none perspective-midrange")
  |> should.equal("perspective-midrange")
  m("perspective-origin-center perspective-origin-top-left")
  |> should.equal("perspective-origin-top-left")
  m("bg-linear-to-r bg-linear-45") |> should.equal("bg-linear-45")
  m("bg-linear-to-r bg-radial-[something] bg-conic-10")
  |> should.equal("bg-conic-10")
  m("ring-4 ring-orange inset-ring inset-ring-3 inset-ring-blue")
  |> should.equal("ring-4 ring-orange inset-ring-3 inset-ring-blue")
  m("field-sizing-content field-sizing-fixed")
  |> should.equal("field-sizing-fixed")
  m("scheme-normal scheme-dark") |> should.equal("scheme-dark")
  m("font-stretch-expanded font-stretch-[66.66%] font-stretch-50%")
  |> should.equal("font-stretch-50%")
  m("col-span-full col-2 row-span-3 row-4") |> should.equal("col-2 row-4")
  m("via-red-500 via-(--mobile-header-gradient)")
  |> should.equal("via-(--mobile-header-gradient)")
  m("via-red-500 via-(length:--mobile-header-gradient)")
  |> should.equal("via-red-500 via-(length:--mobile-header-gradient)")
}

pub fn v4_1_features_test() {
  m("items-baseline items-baseline-last")
  |> should.equal("items-baseline-last")
  m("self-baseline self-baseline-last") |> should.equal("self-baseline-last")
  m("place-content-center place-content-end-safe place-content-center-safe")
  |> should.equal("place-content-center-safe")
  m("items-center-safe items-baseline items-end-safe")
  |> should.equal("items-end-safe")
  m("wrap-break-word wrap-normal wrap-anywhere")
  |> should.equal("wrap-anywhere")
  m("text-shadow-none text-shadow-2xl") |> should.equal("text-shadow-2xl")
  m(
    "text-shadow-none text-shadow-md text-shadow-red text-shadow-red-500 shadow-red shadow-3xs",
  )
  |> should.equal("text-shadow-md text-shadow-red-500 shadow-red shadow-3xs")
  m("mask-add mask-subtract") |> should.equal("mask-subtract")
  m("mask-type-luminance mask-type-alpha") |> should.equal("mask-type-alpha")
  m("shadow-md shadow-lg/25 text-shadow-md text-shadow-lg/25")
  |> should.equal("shadow-lg/25 text-shadow-lg/25")
  m(
    "drop-shadow-some-color drop-shadow-[#123456] drop-shadow-lg drop-shadow-[10px_0]",
  )
  |> should.equal("drop-shadow-[#123456] drop-shadow-[10px_0]")
  m("drop-shadow-[#123456] drop-shadow-some-color")
  |> should.equal("drop-shadow-some-color")
  m("drop-shadow-2xl drop-shadow-[shadow:foo]")
  |> should.equal("drop-shadow-[shadow:foo]")
}

pub fn v4_1_mask_image_test() {
  m(
    "mask-(--foo) mask-[foo] mask-none mask-linear-1 mask-linear-2 mask-linear-from-[position:test] mask-linear-from-3 mask-linear-to-[position:test] mask-linear-to-3 mask-linear-from-color-red mask-linear-from-color-3 mask-linear-to-color-red mask-linear-to-color-3 mask-t-from-[position:test] mask-t-from-3 mask-t-to-[position:test] mask-t-to-3 mask-t-from-color-red mask-t-from-color-3 mask-radial-(--test) mask-radial-[test] mask-radial-from-[position:test] mask-radial-from-3 mask-radial-to-[position:test] mask-radial-to-3 mask-radial-from-color-red mask-radial-from-color-3",
  )
  |> should.equal(
    "mask-none mask-linear-2 mask-linear-from-3 mask-linear-to-3 mask-linear-from-color-3 mask-linear-to-color-3 mask-t-from-3 mask-t-to-3 mask-t-from-color-3 mask-radial-[test] mask-radial-from-3 mask-radial-to-3 mask-radial-from-color-3",
  )
  m(
    "mask-(--something) mask-[something] mask-top-left mask-center mask-(position:--var) mask-[position:1px_1px] mask-position-(--var) mask-position-[1px_1px]",
  )
  |> should.equal("mask-[something] mask-position-[1px_1px]")
  m(
    "mask-(--something) mask-[something] mask-auto mask-[size:foo] mask-(size:--foo) mask-size-[foo] mask-size-(--foo) mask-cover mask-contain",
  )
  |> should.equal("mask-[something] mask-contain")
}

pub fn v4_1_5_features_test() {
  m("h-12 h-lh") |> should.equal("h-lh")
  m("min-h-12 min-h-lh") |> should.equal("min-h-lh")
  m("max-h-12 max-h-lh") |> should.equal("max-h-lh")
}

pub fn v4_2_logical_inset_test() {
  m("inset-s-1 inset-s-2") |> should.equal("inset-s-2")
  m("inset-e-1 inset-e-2") |> should.equal("inset-e-2")
  m("inset-bs-1 inset-bs-2") |> should.equal("inset-bs-2")
  m("inset-be-1 inset-be-2") |> should.equal("inset-be-2")
  m("start-1 inset-s-2") |> should.equal("inset-s-2")
  m("inset-s-1 start-2") |> should.equal("start-2")
  m("end-1 inset-e-2") |> should.equal("inset-e-2")
  m("inset-e-1 end-2") |> should.equal("end-2")
  m("inset-s-1 inset-e-2 inset-bs-3 inset-be-4 inset-0")
  |> should.equal("inset-0")
  m("inset-0 inset-s-1 inset-bs-1")
  |> should.equal("inset-0 inset-s-1 inset-bs-1")
  m("inset-y-1 inset-bs-2 inset-be-3")
  |> should.equal("inset-y-1 inset-bs-2 inset-be-3")
  m("top-1 inset-bs-2 bottom-3 inset-be-4")
  |> should.equal("top-1 inset-bs-2 bottom-3 inset-be-4")
}

pub fn v4_2_logical_spacing_test() {
  m("pbs-1 pbs-2") |> should.equal("pbs-2")
  m("pbe-1 pbe-2") |> should.equal("pbe-2")
  m("mbs-1 mbs-2") |> should.equal("mbs-2")
  m("mbe-1 mbe-2") |> should.equal("mbe-2")
  m("pt-1 pbs-2") |> should.equal("pt-1 pbs-2")
  m("pb-1 pbe-2") |> should.equal("pb-1 pbe-2")
  m("p-0 pbs-1 pbe-1") |> should.equal("p-0 pbs-1 pbe-1")
  m("pbs-1 pbe-1 p-0") |> should.equal("p-0")
  m("py-1 pbs-2 pbe-3") |> should.equal("py-1 pbs-2 pbe-3")
}

pub fn v4_2_logical_border_test() {
  m("border-bs-1 border-bs-2") |> should.equal("border-bs-2")
  m("border-be-1 border-be-2") |> should.equal("border-be-2")
  m("border-bs-red border-bs-blue") |> should.equal("border-bs-blue")
  m("border-2 border-bs-4 border-be-6")
  |> should.equal("border-2 border-bs-4 border-be-6")
  m("border-bs-4 border-be-6 border-2") |> should.equal("border-2")
  m("border-y-2 border-bs-4 border-be-6")
  |> should.equal("border-y-2 border-bs-4 border-be-6")
  m("border-t-2 border-bs-4 border-b-6 border-be-8")
  |> should.equal("border-t-2 border-bs-4 border-b-6 border-be-8")
}

pub fn v4_2_logical_size_test() {
  m("inline-1/2 inline-3/4") |> should.equal("inline-3/4")
  m("block-1/2 block-3/4") |> should.equal("block-3/4")
  m("min-inline-auto min-inline-full") |> should.equal("min-inline-full")
  m("max-inline-none max-inline-10") |> should.equal("max-inline-10")
  m("min-block-auto min-block-lh min-block-10") |> should.equal("min-block-10")
  m("max-block-none max-block-lh max-block-10") |> should.equal("max-block-10")
  m("w-10 inline-20") |> should.equal("w-10 inline-20")
  m("size-10 inline-20 block-30") |> should.equal("size-10 inline-20 block-30")
}

pub fn v4_2_font_features_and_fractions_test() {
  m("font-features-[\"smcp\"] font-features-[\"onum\"]")
  |> should.equal("font-features-[\"onum\"]")
  m("tabular-nums font-features-[\"smcp\"]")
  |> should.equal("tabular-nums font-features-[\"smcp\"]")
  m("aspect-8/11 aspect-8.5/11") |> should.equal("aspect-8.5/11")
  m("w-8/11 w-8.5/11") |> should.equal("w-8.5/11")
  m("inset-1/2 inset-1.25/2.5") |> should.equal("inset-1.25/2.5")
}

pub fn v4_3_scrollbar_test() {
  m("scrollbar-auto scrollbar-thin scrollbar-none")
  |> should.equal("scrollbar-none")
  m("scrollbar-gutter-auto scrollbar-gutter-stable scrollbar-gutter-both")
  |> should.equal("scrollbar-gutter-both")
  m("scrollbar-thumb-red-500 scrollbar-thumb-blue-500")
  |> should.equal("scrollbar-thumb-blue-500")
  m("scrollbar-thumb-red-500 scrollbar-thumb-red-500/50")
  |> should.equal("scrollbar-thumb-red-500/50")
  m("scrollbar-track-red-500 scrollbar-track-[color:var(--track-color)]")
  |> should.equal("scrollbar-track-[color:var(--track-color)]")
  m("scrollbar-thin scrollbar-thumb-red-500 scrollbar-track-blue-500")
  |> should.equal(
    "scrollbar-thin scrollbar-thumb-red-500 scrollbar-track-blue-500",
  )
}

pub fn v4_3_container_query_test() {
  m("@container @container-normal @container-size")
  |> should.equal("@container-size")
  m("@container-[inline-size] @container-(--container-type)")
  |> should.equal("@container-(--container-type)")
  m("@container @container-size/sidebar")
  |> should.equal("@container-size/sidebar")
  m("@container-normal @container-size/sidebar")
  |> should.equal("@container-size/sidebar")
  m("@container-size/sidebar @container")
  |> should.equal("@container-size/sidebar @container")
  m("@container/sidebar @container-normal")
  |> should.equal("@container/sidebar @container-normal")
  m("@container/sidebar @container-normal/sidebar @container-size/content")
  |> should.equal("@container-size/content")
  m("@container/sidebar @container-normal/content @container-size")
  |> should.equal("@container-normal/content @container-size")
  m("@container-size @container/sidebar") |> should.equal("@container/sidebar")
  m("@container-foo/sidebar @container-size/sidebar")
  |> should.equal("@container-foo/sidebar @container-size/sidebar")
}

pub fn v4_3_zoom_tab_test() {
  m("zoom-50 zoom-100") |> should.equal("zoom-100")
  m("zoom-100 zoom-[var(--zoom)]") |> should.equal("zoom-[var(--zoom)]")
  m("zoom-[1.5] zoom-(--zoom)") |> should.equal("zoom-(--zoom)")
  m("zoom-50 scale-125") |> should.equal("zoom-50 scale-125")
  m("tab-2 tab-8") |> should.equal("tab-8")
  m("tab-8 tab-[12px]") |> should.equal("tab-[12px]")
  m("tab-[3] tab-(--tab-size)") |> should.equal("tab-(--tab-size)")
  m("tab-4 tabular-nums") |> should.equal("tab-4 tabular-nums")
}

// --- clsx / tw_join / cn ------------------------------------------------------

pub fn tw_join_test() {
  gg_cn.tw_join([
    gg_cn.Class("px-2 py-1"),
    gg_cn.When(True, "px-4"),
    gg_cn.When(False, "hidden"),
    gg_cn.Group([gg_cn.Class("text-red-500")]),
  ])
  |> should.equal("px-2 py-1 px-4 text-red-500")
}

pub fn cn_test() {
  let merger = gg_cn.new()
  merger
  |> gg_cn.cn([
    gg_cn.Class("px-2 py-1"),
    gg_cn.When(True, "px-4"),
    gg_cn.When(False, "px-8"),
  ])
  |> should.equal("py-1 px-4")
}

// The result cache (JS) must never change output: repeated merges of the same
// input — and the `default()` merger that backs gg_ui — return the same result
// as a fresh merge. (On the BEAM the cache is a no-op; this just confirms
// correctness is preserved on both.)
pub fn cache_is_transparent_test() {
  let input = "px-2 px-4 flex justify-center justify-between"
  let expected = "px-4 flex justify-between"

  let m = gg_cn.new()
  gg_cn.tw_merge(m, input) |> should.equal(expected)
  // second call hits the cache on JS
  gg_cn.tw_merge(m, input) |> should.equal(expected)
  // the process-global default merger resolves identically
  gg_cn.tw_merge(gg_cn.default(), input) |> should.equal(expected)
  gg_cn.tw_merge(gg_cn.default(), input) |> should.equal(expected)
}
