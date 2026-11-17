# PrettyFrames generated-art prompts

The source PNG files in this directory were generated with the built-in image-generation tool. The TGA files are resized, game-ready derivatives consumed by the addon.

## CastBarEndCap

The canonical 128 x 128 asset is a lossless crop of the original Verdant cast-bar ornament's left cap. Only that cap is stored; runtime horizontally mirrors it for the right end. No center ornament or rail texture is retained.

## CastBarInterruptibleGlow-v1

Transparent cast-bar highlight with exactly two parallel green-gold luminous
horizontal edges, a fully transparent center, no vertical sides, and smooth
alpha fades well before both ends so the glow disappears beneath the bronze
end caps. Generated as a transparent raster asset, cleaned by retaining only
the upper and lower highlight bands, and exported at 1024x128.

## PortraitRing

Use case: stylized-concept  
Asset type: reusable World of Warcraft addon UI texture, circular 3D portrait bezel overlay  
Primary request: an ornate fantasy bronze-and-copper circular portrait frame inspired by autumn woodland craftsmanship, with subtle curling vines and a few small maple leaves integrated into the outer rim  
Scene/backdrop: none; isolated asset  
Subject: a perfectly centered circular open ring with a completely empty transparent center for a live 3D character portrait  
Style/medium: polished hand-painted MMORPG interface art, crisp readable silhouette, premium game UI asset  
Composition/framing: square canvas, ring fills most of canvas with even padding; front-facing, perfectly circular, no perspective; ornament stays close to ring  
Lighting/mood: warm amber highlights, dark bronze recesses, elegant rather than gaudy  
Color palette: antique bronze, copper, burnt orange, muted gold  
Materials/textures: carved metal, restrained engraved vine details  
Constraints: genuinely transparent background; transparent open center; no character, no portrait, no bars, no text, no icons, no glow, no shadow extending far outside; strong clean alpha edges; intended to overlay a live 3D model in game  
Avoid: copyrighted logos, Warcraft faction insignia, photorealistic scene, square backing plate, opaque black center, watermark

## StatusBarFoliage

Use case: stylized-concept  
Asset type: reusable horizontal status-bar fill texture for a fantasy MMORPG addon  
Primary request: a long seamless-looking embossed foliage and faceted-stone texture in neutral grayscale, designed to be color-tinted by game code for health and mana bars  
Scene/backdrop: flat texture only, no scene  
Subject: subtle overlapping leaves and low-relief carved facets flowing horizontally  
Style/medium: polished hand-painted MMORPG UI texture, crisp at small size  
Composition/framing: extremely wide horizontal strip centered on a landscape canvas; uniform density edge-to-edge; no border, no end caps, no empty margins  
Lighting/mood: gentle top highlight and darker lower recesses, readable but restrained  
Color palette: strictly neutral white-to-charcoal grayscale with no colored tint  
Materials/textures: embossed stone and leaf relief  
Constraints: no text, no icons, no frame, no metal border, no glow, no transparent holes, no watermark; texture must remain readable when compressed to a 512x64 bar

## IntegratedFrame-v2

Use case: stylized-concept  
Asset type: production-ready single-piece transparent overlay texture for a World of Warcraft unit frame addon  
Input images: the original large ornate autumn unit-frame mockup is the primary style and layout reference; the latest in-game screenshot is a diagnostic reference showing the current frame that must be substantially improved; earlier generated ring and foliage textures are supporting style references  
Primary request: create ONE continuous integrated fantasy UI frame skin that matches the original reference as closely as practical: a large circular portrait ring fused seamlessly into a long fixed-width rectangular frame, with a sculpted nameplate at top and two stacked horizontal status-bar openings beneath it  
Subject: antique bronze and copper frame with carved dark leather nameplate, curling vine filigree, substantial layered maple/oak leaves around the portrait ring and at the far-right corners, and elegant raised border elements running continuously around the entire rectangular frame  
Style/medium: highly polished hand-painted premium MMORPG interface art, dimensional sculpted metal and leather, crisp at small on-screen size  
Composition/framing: very wide 3:1 unit-frame silhouette, front-facing and orthographic; portrait circle occupies the left quarter and overlaps the rectangle; nameplate occupies the upper right; two equal long bar openings below; all elements physically connect and flow together with no visible seams or floating pieces  
Lighting/mood: warm amber edge highlights with dark bronze recesses, dramatic but readable  
Color palette: antique bronze, warm copper, muted gold, dark brown leather, autumn orange/red leaves  
Materials/textures: engraved metal, carved vines, embossed leather, layered leaves  
Constraints: genuinely transparent background outside the frame; genuinely transparent open portrait center; genuinely transparent interiors of the nameplate and both status-bar openings so live game widgets can show through; no character, no portrait, no health or mana fill, no text, no numbers, no icons, no level badge, no watermark; border thickness remains practical and consistent; strong clean alpha edges; one cohesive frame rather than separate ring and rectangles  
Avoid: separate disconnected components, thin wire-like ring, sparse tiny leaves, square backing panel, black or opaque fills inside openings, modern sci-fi styling, faction logos

## PlayerFrame-WithPet-v2

Use case: precise-object-edit  
Asset type: transparent production Player-plus-Pet unit-frame skin for a World of Warcraft addon  
Input image: PlayerFrame-WithPet-v1 is the exact edit target and basis of the result  
Primary request: modify only the attached smaller Pet frame beneath the main Player frame so it supports two live status bars instead of one; preserve the existing pet nameplate and pet health opening at their current positions; add one second, slightly shorter transparent power-bar opening directly beneath pet health, separated by a thin matching bronze rail; extend and rebuild only the pet frame's lower boundary downward enough to surround the new opening cleanly  
Invariants: preserve the complete main Player frame, main portrait ring, main nameplate, main health and power openings, foliage, metals, leather, scrollwork, highlights, proportions, transparent areas, Pet portrait ring position and size, Pet nameplate position and width, Pet health position and width, horizontal alignment, wide canvas aspect, and front-facing orthographic view  
Style/medium: exact existing hand-painted Verdant fantasy UI style, antique bronze and copper, dark embossed leather, autumn foliage  
Constraints: genuinely transparent outer background, portraits, and all status-bar openings; no portraits, characters, text, numbers, icons, colored fills, scene, glow, watermark, extra sockets, or disconnected pieces; add exactly one new Pet power opening and no other structural changes  
Avoid: redesigning the Player frame, moving the Pet portrait, nameplate, or health bar, changing leaf placement or palette, shrinking existing elements, filling transparent openings, or adding a third Pet bar

## IndicatorRing-v2

Use case: stylized-concept  
Asset type: reusable circular indicator bezel overlay for the same World of Warcraft unit-frame skin shown in the references  
Input images: the current in-game PrettyFrames screenshot is a placement reference; the integrated ornate frame artwork is the exact style/material reference  
Primary request: create one small circular medallion bezel that matches the frame's antique bronze, copper, dark carved leather, curling vine, and autumn-leaf craftsmanship; it will be reused around a level number and a class icon  
Subject: compact round bronze badge ring with a thick readable rim, restrained vine curls, and two or three small but substantial autumn leaves fused into the outside edge  
Style/medium: polished hand-painted premium MMORPG interface art, designed to stay legible at roughly 44 pixels on screen  
Composition/framing: perfectly centered front-facing circle on a square canvas, ornament close to the ring, balanced silhouette  
Color palette: antique bronze, warm copper, muted gold, burnt orange and red leaves  
Materials/textures: carved metal, dark leather recesses, layered leaves  
Constraints: genuinely transparent background; genuinely transparent circular center so code can place a class icon or leather fill underneath; no text, no number, no symbol, no class logo, no character, no square plate, no glow, no watermark; clean alpha edges  
Avoid: thin delicate wire, oversized ornament that overwhelms the center, disconnected pieces, modern styling

## IndicatorRing-v3

Use case: stylized-concept  
Asset type: tiny reusable circular indicator bezel overlay for the current PrettyFrames World of Warcraft addon  
Input images: the latest in-game screenshot shows the existing indicator at the wrong scale; the prior ornate indicator is a material reference but must be substantially simplified  
Primary request: create a compact leafless circular bronze bezel specifically optimized to remain clean and readable at 34 to 42 pixels on screen  
Subject: a simple thick round antique-bronze rim with one subtle inner copper ring and a very restrained dark-leather recessed band  
Style/medium: polished hand-painted MMORPG interface art matching the current integrated frame, but intentionally low-detail and icon-scale  
Composition/framing: perfectly centered, front-facing, perfectly circular; tight even padding; symmetrical silhouette  
Color palette: antique bronze, warm copper, muted gold highlights, dark brown leather recess  
Materials/textures: lightly engraved metal and restrained leather; broad shapes rather than fine decoration  
Constraints: genuinely transparent background; genuinely transparent circular center; absolutely no leaves, no vines, no curls, no spikes, no flourishes, no text, no number, no icon, no logo, no character, no square plate, no glow, no watermark; strong clean alpha edges; ring should occupy about 22 percent of the circle radius so the center remains large  
Avoid: autumn foliage, ornate filigree, cracks, tiny details, asymmetric decoration, thin wire-like rim

## PortraitSnake-v1

Use case: stylized-concept  
Asset type: seamless portrait-background texture for the current PrettyFrames World of Warcraft addon  
Input images: the latest in-game screenshot is the color, scale, and UI-style reference  
Primary request: a very dark brown, nearly black snakeskin texture to sit behind a live 3D character portrait and prevent the world scene from showing through  
Subject: subtle overlapping snake scales with shallow embossed relief; texture only, no animal  
Style/medium: refined hand-painted premium MMORPG interface texture, understated and readable at about 100 pixels  
Composition/framing: straight-on flat square material swatch, uniform edge-to-edge coverage, seamless-looking repetition, no central object and no vignette  
Lighting/mood: extremely low-key soft amber-brown highlights on near-black scales, elegant and unobtrusive  
Color palette: near black, espresso brown, very dark umber, tiny restrained warm bronze highlights  
Materials/textures: matte snakeskin or embossed leather, fine regular scales  
Constraints: opaque edge-to-edge texture; no border, no frame, no leaves, no vines, no character, no snake head or body, no eyes, no text, no symbol, no glow, no watermark; low contrast so the portrait remains dominant  
Avoid: bright tan, green, colorful iridescence, photorealistic living snake, large scales, dramatic highlights

## PetFrame-v1

Use case: stylized-concept  
Asset type: production-ready standalone transparent pet-frame overlay texture for the PrettyFrames World of Warcraft addon  
Input images: Image 1 is the current in-game player frame and is the exact material, color, leaf, metalwork, and rendering-style reference; Image 2 is the original mockup and is the primary pet-frame layout and integration reference  
Primary request: create ONE cohesive compact pet unit frame that visually tucks beneath and grows out of the current player frame, while remaining a separate image resource that can disappear independently  
Subject: a circular pet portrait ring on the left fused into a compact dark-leather nameplate above one long horizontal health-bar opening; antique bronze/copper border, restrained curling vines, and a small cluster of autumn leaves behind the portrait and connector area; a graceful upper connector flourish should extend toward the player frame so the two frames feel joined when overlaid  
Style/medium: highly polished hand-painted premium MMORPG interface art matching Image 1 exactly  
Composition/framing: wide 3:1 silhouette, front-facing and orthographic; portrait circle occupies the left third; compact nameplate and single health opening occupy the right two-thirds; the frame should read clearly when displayed around 330x110 pixels  
Lighting/mood: warm amber highlights, dark bronze recesses, elegant and readable  
Color palette: antique bronze, warm copper, muted gold, dark espresso leather, restrained burnt-orange/red autumn leaves  
Materials/textures: engraved metal, carved vines, embossed leather, layered leaves  
Constraints: genuinely transparent background outside the frame; genuinely transparent open portrait center; genuinely transparent health-bar interior; opaque dark leather nameplate; no character, no pet portrait, no health fill, no text, no numbers, no icons, no paw symbol, no level badge, no watermark; strong clean alpha edges; all visual pieces connected rather than floating; ornament simplified enough to remain readable at 330x110  
Avoid: two status bars, oversized leaves, disconnected portrait ring, square backing panel, bright gold, modern styling, faction logos

## CombinedPlayerPet-v2 / PetIntegratedOverlay-v2

Use case: precise-object-edit  
Asset type: combined production UI artwork used to derive a detachable pet overlay for a World of Warcraft addon  
Input images: Image 1 is the exact player-frame edit target; Image 2 is the layout/integration reference  
Primary request: preserve Image 1's player frame exactly above and through the mana-bar area, then expand the composition downward and edit the lower border so a compact pet frame grows organically out of it like Image 2; the pet frame must look like a continuous branch of the player frame rather than a separate object pushed underneath  
Pet frame structure: circular pet portrait opening below the mana bar near the middle-left, fused into a compact leather nameplate above one green health-bar opening extending right; use continuous bronze rails, shared vines, and transitional scrollwork that visibly originate from the player frame's lower border; the player lower border may change substantially wherever necessary to make the connection seamless  
Style/medium: preserve Image 1's exact hand-painted antique bronze, copper, leather, autumn-leaf, lighting, and rendering style  
Composition/framing: player frame remains at the top at its original proportions; pet frame sits below the mana bar and extends toward the right as in Image 2; include enough transparent canvas below for the complete pet frame  
Constraints: keep all of Image 1 above the player's mana bar unchanged; genuinely transparent outer background; genuinely transparent player portrait and both player bar openings; genuinely transparent pet portrait and pet health opening; pet nameplate is opaque dark leather; no characters, portraits, text, numbers, status fills, icons, paw symbols, badges, logos, or watermark; strong clean alpha edges; one continuous connected ornament  
Avoid: a visible gap, two overlapping independent frames, duplicate lower rails, a pet frame merely placed on top, mismatched metal color, oversized leaves, opaque black in any portrait or bar opening

`PetIntegratedOverlay-v2` is cropped from the combined edit and contains only the altered lower-player connection plus the pet frame.

## UnifiedPlayerPet-v3

Use case: precise-object-edit  
Asset type: final unified Player+Pet unit-frame skin for a World of Warcraft addon  
Input images: Image 1 is the current player-only skin and exact style reference; Image 2 demonstrates the prior unified attempt and its continuous connection; Image 3 is the primary layout reference  
Primary request: create ONE indivisible, continuous Player+Pet UI element. Preserve the player frame's established portrait-left, leather-nameplate, green-health, blue-mana hierarchy and exact material style, while redesigning everything below and around the mana bar as needed so a larger pet frame grows organically from the player frame with shared rails, vines, leaves, and uninterrupted metalwork. There must be no visual seam or sense of two overlapping frames  
Pet prominence: pet portrait diameter should be approximately 55–60 percent of the player portrait diameter; pet nameplate and single health opening should extend right so the pet portion is roughly 58–62 percent of the total player-frame width; make it clearly more prominent than Image 2  
Style/medium: exact match for Image 1's polished hand-painted antique bronze, copper, dark leather, autumn leaves, lighting, line weight, and rendering quality  
Composition/framing: wide unified silhouette on transparent canvas; player frame occupies the upper portion; pet portrait sits below the mana bar around the middle-left and overlaps the shared lower rail; pet nameplate above one pet-health opening extends right; shared bronze scrollwork must physically branch from the player lower border into the pet frame as in Image 3  
Constraints: genuinely transparent outer background; transparent player portrait center; transparent player health and mana openings; transparent pet portrait center; transparent pet health opening; opaque dark leather nameplates; no characters, portraits, text, numbers, status fills, icons, badges, paw symbols, logos, or watermark; clean alpha edges; all elements physically connected  
Avoid: detachable overlay appearance, a visible gap, duplicated or crossing rails, a pet frame merely pushed under the player, mismatched scale or stroke thickness, tiny pet frame, opaque black inside openings

## IntegratedFrame-OneBar-v1

Use case: precise-object-edit  
Asset type: production one-resource-bar unit-frame skin for the PrettyFrames World of Warcraft addon  
Input image: Image 1 is the exact edit target and must remain the exact visual and geometric reference  
Primary request: remove the entire lower power/mana/energy bar opening and its surrounding divider, then pull the existing ornate bottom border upward so the frame contains only the unchanged leather nameplate and the unchanged upper status-bar opening  
Invariants: preserve the portrait ring, portrait opening, leaf clusters, level-badge attachment area, nameplate shape and position, upper health-bar opening, class-medallion attachment area, right-side ornament, antique bronze/copper materials, lighting, line weight, texture, and overall horizontal proportions as exactly as possible; change only the area at and below the removed lower bar  
Composition/framing: same wide front-facing orthographic frame; after collapsing the lower row, use one continuous lower bronze rail with the same vine flourish and right-corner leaves, naturally rejoined beneath the remaining health opening  
Constraints: genuinely transparent outer background; genuinely transparent portrait opening; genuinely transparent single health-bar opening; opaque dark leather nameplate; no second bar opening; no character, text, number, icon, badge, fill, logo, or watermark; clean alpha edges; all metalwork physically continuous  
Avoid: redesigning the portrait ring, moving or resizing the nameplate or health opening, style drift, duplicated rails, empty gap where the power bar was, disconnected ornament, opaque black inside transparent openings

## PartyFrame-v1

Use case: ui-mockup  
Asset type: transparent raster skin for a World of Warcraft unit-frame addon  
Primary request: create one compact ornate fantasy Party unit frame that feels like a smaller sibling of the established Player frame and reads as one seamless continuous UI element  
Composition/framing: wide 3:1 silhouette; a slightly oversized circular portrait opening on the left; a connected center stack containing a dark leather nameplate, transparent health opening, and transparent mana/power opening; an integrated circular Party-role opening on the right with approximately the combined height of the two status bars; a small level medallion attached below the portrait and a small class-icon socket in the nameplate  
Style/medium: polished hand-painted premium MMORPG interface art, carved warm bronze and copper, dark embossed leather, braided vine motifs, restrained autumn woodland ornament  
Color palette: warm copper, antique gold, dark espresso leather, tiny accents of burnt orange and deep red  
Constraints: genuinely transparent outer background and genuinely transparent portrait, health, power, and role interiors; no characters, icons, text, numbers, colored fills, background scene, watermark, or pet frame; substantially fewer and smaller leaves than the Player frame; compact silhouette with minimal protrusions; every component physically connected  
Avoid: separate floating pieces, oversized foliage, modern styling, opaque fills inside live-widget openings

## PartyFrame-v2

Use case: precise-object-edit  
Asset type: corrected transparent production Party-frame skin  
Input image: PartyFrame-v1 is the exact edit target  
Primary request: shrink the left portrait bezel so its complete outer diameter is only 10–15 percent taller than the name+health+power stack, and shrink the right Party-role bezel so its outer diameter is approximately the height of the health+power rows together  
Target display geometry at 360x120: portrait outer diameter about 76–80 pixels with a 54–60 pixel opening; role outer diameter about 48–52 pixels with a 28–34 pixel opening  
Invariants: preserve the three-row center construction, leather nameplate, transparent status openings, level and class sockets, warm bronze/copper materials, restrained leaves, 3:1 canvas, and seamless single-piece construction  
Constraints: genuinely transparent outer background and portrait, health, power, and role openings; no text, numbers, characters, icons, fills, scene, pet frame, or watermark  
Avoid: oversized circular sections, center-bay drift, disconnected medallions, opaque debris inside openings

## PartyFrame-v3

Use case: precise-object-edit  
Asset type: Party-frame skin with an uninterrupted class-icon area  
Input image: PartyFrame-v2 is the exact edit target  
Primary request: remove only the small circular class socket embedded near the right end of the top leather nameplate, including its transparent center, bronze rim, and pointed ornament; replace it with a seamless continuation of the embossed leather and straight upper/lower bronze rails so no circle ever appears to have existed  
Invariants: preserve the portrait bezel, lower-left level socket, far-right Party-role bezel, three center rows, all remaining ornament, dimensions, transparency, lighting, and proportions exactly  
Constraints: no replacement socket, badge, icon, text, character, fills, scene, or watermark; portrait, level, health, power, and role openings remain genuinely transparent  
Avoid: altering the far-right role circle, leaving a dark circular patch, shifting frame geometry, or introducing opaque debris into live-widget openings

## PartyFrame-v4

PartyFrame-v4 retains PartyFrame-v3's uninterrupted class area while restoring the complete lower-left level bezel from the aligned pre-cleanup PartyFrame-v2 source. Only pixels with differing alpha in the local level-medallion region were restored, preventing seams or changes elsewhere. The level opening is deliberately excluded from subsequent transparency cleanup.

## TargetTargetFrame-v1

Use case: precise-object-edit  
Asset type: compact transparent Target-of-Target two-bar unit-frame skin  
Input image: PartyFrame-v4 is the exact style and proportion reference  
Primary request: preserve the portrait ring, attached level ring, name plaque, and two rectangular status openings while completely removing the far-right Party-role socket; rebuild that end as one compact seamless rounded bronze-and-dark-leather cap with one restrained autumn-leaf accent  
Constraints: transparent exterior, portrait opening, and status openings; no text, icons, portrait, bar fills, role circle, extra sockets, disconnected pieces, or watermark; preserve the wide 3:1 canvas and continuous handcrafted construction

## TargetTargetFrame-OneBar-v1

Use case: precise-object-edit  
Asset type: compact transparent Target-of-Target health-only companion skin  
Input image: TargetTargetFrame-v1 is the exact edit target  
Primary request: preserve the complete silhouette and all ornament exactly; replace the two stacked status openings with one vertically balanced transparent health opening and fill the former lower row with continuous embossed dark leather and restrained bronze vine filigree  
Constraints: exact same dimensions and silhouette as TargetTargetFrame-v1; transparent exterior, portrait, and health opening; no text, icons, portrait, fills, role socket, or watermark

## TargetTargetFrame-OneBar-v2

Use case: precise-object-edit  
Asset type: collapsed compact Target-of-Target health-only frame skin  
Input image: TargetTargetFrame-OneBar-v1 is the exact edit target  
Primary request: remove the entire filled leather and vine region formerly occupied by the second bar; move the lower bronze outer rail directly beneath the single health opening and reconnect it seamlessly to the portrait scrollwork and rounded right cap  
Invariants: preserve the portrait and level rings, name plaque, health opening, top ornament, width, canvas dimensions, palette, and all artwork above the health bar  
Constraints: the vacated lower area is genuinely transparent; no second-bar backing, filled lower panel, decorative vine in the removed row, text, icons, portrait, bar fill, role socket, disconnected parts, or watermark

## RaidFrame-v1

Use case: stylized-concept  
Asset type: production-ready transparent raid unit-frame overlay texture for the PrettyFrames World of Warcraft addon  
Input images: PartyFrame-v4 is the compact style/material reference; NameplateFrame-v2 is the compact density reference; IntegratedFrame-v2 is the palette and rendering reference  
Primary request: create one restrained compact horizontal raid-frame skin that remains readable when forty copies are shown at once  
Subject: a thin antique-bronze and warm-copper outer bezel around two integrated horizontal regions: a shallow opaque dark espresso embossed-leather name strip across the top and one genuinely transparent health-bar opening below; add only extremely restrained vine engraving and at most one tiny attached autumn leaf accent  
Style/medium: polished hand-painted premium MMORPG interface art; broad clean shapes optimized for approximately 176 by 36 pixels on screen  
Composition/framing: very wide low-profile front-facing orthographic rectangle with minimal exterior protrusion, practical edges, and a thin border  
Lighting/mood: warm amber top-edge highlights and dark bronze recesses, restrained contrast  
Color palette: antique bronze, warm copper, muted gold highlight, dark espresso leather, and one tiny burnt-orange leaf  
Constraints: genuinely transparent outer background and health-bar opening; opaque dark-leather name strip; no portrait, medallion, role socket, character, text, numbers, icons, health fill, glow, or watermark; all pieces physically connected; strong clean alpha edges  
Avoid: oversized leaves, ornate curls, thick borders, floating parts, a second status bar, square backing panel, modern styling, faction logos, or tiny-scale clutter

## RaidFrame-v2

Use case: precise-object-edit  
Asset type: production transparent raid unit-frame overlay for the PrettyFrames World of Warcraft addon  
Input images: RaidFrame-v1 is the exact edit target; the in-game forty-frame grid is a diagnostic reference showing excessive repetition  
Primary request: simplify RaidFrame-v1 aggressively for repeated raid-grid use by replacing its bright double bronze rails with one thin subdued dark-antique-bronze perimeter, flattening the leather name band, and removing its vine embossing, leaf, center diamonds, pointed flourishes, curled corners, extra rails, and nearly all highlights  
Composition/framing: preserve the wide low-profile silhouette, leather name region, and single health-opening geometry; use a clean minimally protruding rounded rectangle  
Lighting/mood: low contrast, dark, matte, and restrained, with highlights approximately half as bright as RaidFrame-v1  
Color palette: dark aged bronze, muted copper, and espresso leather; no bright gold or orange foliage  
Constraints: genuinely transparent outer background and health opening; opaque name band; no text, icons, portraits, fills, glow, leaves, vines, diamonds, spikes, flourishes, watermark, or additional openings; clean connected edges; optimized for forty copies at 176 by 36 pixels  
Avoid: double horizontal rails, bright repeating gold lines, corner curls, decorative focal points, embossed scrollwork, high-frequency detail, or bulky borders

## RaidFrame-v3

Use case: precise-object-edit  
Asset type: production transparent raid unit-frame overlay for the PrettyFrames World of Warcraft addon  
Input images: RaidFrame-v2 is the exact edit target; PartyFrame-v4 is the color and material reference; the compact in-game raid grid is the diagnostic reference  
Primary request: recolor only RaidFrame-v2's thin outer perimeter and horizontal name/health separator with the brighter warm antique-bronze and copper treatment from PartyFrame-v4, while remaining restrained enough for forty repeated frames  
Invariants: preserve RaidFrame-v2's exact simple geometry, rounded end caps, proportions, border and separator thickness, flat dark espresso leather name band, transparent health opening, transparent outer background, clean alpha edges, and lack of ornament; do not change the leather brightness or texture  
Color palette: PartyFrame-v4 warm copper, antique bronze, and muted-gold edge highlights; unchanged espresso leather  
Constraints: change only the metal color and highlight; no leaves, vines, diamonds, curls, spikes, text, icons, fills, glow, extra rails, watermark, or new geometry; preserve genuine transparency exactly where present  
Avoid: bright yellow gold, thicker borders, busy ornament, altered leather, silhouette changes, or focal decoration

## RaidLeavesMaple-v1

Use case: stylized-concept  
Asset type: small transparent decorative corner-leaf accent for the PrettyFrames raid-frame grid  
Input images: PartyFrame-v4 and IntegratedFrame-v2 are the exact material, palette, lighting, and hand-painted style references  
Primary request: create one compact asymmetric cluster of exactly two overlapping autumn maple leaves with a very short subtle bronze stem, designed to attach to the outer corner of a tiny raid frame  
Subject: one burnt-orange maple leaf and one deeper-red maple leaf, layered diagonally and pointing outward in different directions  
Constraints: genuinely transparent background; exactly two leaves; no long branch, vines, frame, text, icon, glow, backdrop, watermark, or fragments; clean alpha edges; readable around 26 pixels

## RaidLeavesOak-v1

Use case: stylized-concept  
Asset type: second small transparent decorative corner-leaf accent for the PrettyFrames raid-frame grid  
Input images: PartyFrame-v4 and IntegratedFrame-v2 are the exact material, palette, lighting, and hand-painted style references  
Primary request: create a distinctly different compact asymmetric accent of exactly three small overlapping oak leaves in a narrow swept fan  
Subject: one muted-gold, one burnt-orange, and one russet-red oak leaf attached at one compact point by extremely short dark-bronze stems  
Constraints: genuinely transparent background; exactly three oak leaves; no long branch, vines, frame, text, icon, glow, backdrop, watermark, or fragments; clean alpha edges; readable around 26 pixels

## RaidLeavesGolden-v1

Use case: stylized-concept  
Asset type: third small transparent decorative leaf accent for the PrettyFrames raid-frame perimeter  
Input images: PartyFrame-v4 and IntegratedFrame-v2 are exact style/material references; RaidLeavesMaple-v1 and RaidLeavesOak-v1 establish the existing accent set without being duplicated  
Primary request: create one curled golden-yellow maple leaf with a warm-orange underside and tiny antique-bronze clasp, suitable for overlapping a tiny raid-frame edge  
Constraints: genuinely transparent background; exactly one maple leaf; no extra leaves, long branch, vines, frame, text, icon, glow, backdrop, watermark, or fragments; clean alpha edges; readable around 26 pixels

## RaidLeavesAspen-v1

Use case: stylized-concept  
Asset type: fourth small transparent decorative leaf accent for the PrettyFrames raid-frame perimeter  
Input images: PartyFrame-v4 and IntegratedFrame-v2 are exact style/material references; RaidLeavesMaple-v1 and RaidLeavesOak-v1 establish the existing accent set without being duplicated  
Primary request: create a narrow side-edge accent of exactly two slim overlapping aspen leaves—one crimson and one amber-orange—joined by an extremely short curling antique-bronze stem  
Constraints: genuinely transparent background; exactly two aspen leaves; no extra leaves, long branch, vines, frame, text, icon, glow, backdrop, watermark, or fragments; clean alpha edges; readable around 26 pixels

## AmmoArrowheadActive-v1

Use case: stylized-concept  
Asset type: World of Warcraft addon game UI resource icon  
Primary request: a single bright faceted arrowhead, designed as a counted Hunter ammunition resource marker  
Subject: one symmetrical ancient forged arrowhead pointing straight upward, broad triangular silhouette, slightly notched shoulders, sharp central ridge, crisp beveled facets  
Style/medium: polished fantasy game UI asset, matching a bright circular faceted jewel icon; neutral grayscale metal and crystal highlights so runtime tinting works cleanly  
Composition/framing: perfectly centered, front-facing, generous transparent padding, strong readable silhouette at 42 pixels  
Lighting/mood: luminous white center highlights with darker silver edge facets, high contrast  
Constraints: genuinely transparent background; grayscale only; one arrowhead only; no shaft, feathers, bow, circle, border, text, numbers, glow outside the silhouette, scene, logo, or watermark; square canvas

## AmmoArrowheadEmpty-v1

Use case: stylized-concept  
Asset type: empty-state variant of AmmoArrowheadActive-v1  
Input image: AmmoArrowheadActive-v1 is the exact shape reference  
Primary request: make a dark, clouded, dull empty-state version of the same arrowhead  
Style/medium: weathered smoky grayscale fantasy game UI asset, matching a dark clouded empty jewel  
Composition/framing: preserve the exact centered front-facing arrowhead silhouette, proportions, orientation, and transparent padding  
Lighting/mood: very subdued charcoal and dark gray, faint cloudy mineral texture, low reflectivity, enough edge definition to remain readable at 42 pixels  
Constraints: genuinely transparent background; change only the material and lighting; grayscale only; one arrowhead only; no shaft, feathers, bow, circle, border, text, numbers, colored tint, external glow, scene, logo, or watermark
