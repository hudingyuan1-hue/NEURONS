# World viewport framing audit — 2026-10-20

Read-only investigation requested by the parent agent. No campaign, UI, layout,
camera, or gameplay file was changed by this audit. The findings describe the
current files and the already-captured GPU frame, not a new fullscreen test.

## Evidence

- `neurons/project.godot:20–24`: design/window dimensions 1280×720;
  `window/stretch/mode="canvas_items"`.
- `neurons/scripts/bedroom_sample.gd:50–51`: zoom steps .8/1/1.15/1.3 and base .85.
- `bedroom_sample.gd:112–134`: fixed 1280×720 WorldCanvas, initial
  `stretch_shrink=2`, 640×360 SubViewport, Camera2D zoom .85.
- `neurons/scripts/campaign.gd:544–554`: metric rooms change stretch shrink to 1,
  thus native 1280×720 drawing, without calculating a corresponding framing zoom.
- `campaign.gd:556–572`: long/high-level rooms follow; the bedroom does not.
  Actor-safe boxes are fixed pixels in the whole viewport.
- `neurons/scripts/ui/ui_presentation.gd:47–70`: the actual footer is moved from
  y589 to y625. With header/status ending y140, the current unobstructed world
  band is approximately `Rect2(0,140,1280,485)`. The UI agent confirmed this band.
- `neurons/scripts/presentation/view_controls.gd:43–68`: bounds use all four
  corners of `world_size`, plus a generic margin, rather than the rendered
  contour/wall-top bounds. Camera clamping and drag input use the full viewport.
- Input conversion in `campaign.gd:1539`, pan conversion in
  `view_controls.gd:68`, and WorldCanvas dimensions are hardcoded to 1280×720.
- No production fullscreen/resized/DisplayServer/window-mode handling was found
  in the scripts. This does not prove fullscreen is broken; adaptive behavior
  still needs real Windows tests after the presentation changes.

The already-captured real world frame is
`furniture/live/02_painted_furniture_existing_surfaces_world.png` (1280×720).
Pillow comparison against its RGB(38,49,54) background gives a non-background
bounding box `[331,123,949,577]`: **618×454 pixels**, including ground shadow.
That is 48.3% of screen width and 63.1% of screen height. Its upper 17 pixels sit
behind the current header/status area. The paused UI screenshot is not used for
this measurement.

## Cause and practical implication

Changing render resolution did not establish a matching camera framing policy.
The default .85 zoom and small maximum 1.105 make the rooms look remote.
However, resolution/zoom alone is not the entire issue: the complete rendered
bedroom has a width/height ratio of about 1.36, while the current clear UI band
has a ratio of 2.64. Fitting the whole room vertically into that band leaves
large horizontal margins by necessity. A promise of “the complete room always
visible and also 75% of screen width” is geometrically incompatible with the
current UI layout. At that width the room would be about 705 pixels tall.

“World takes three quarters of the screen” should describe the available world
stage, stable readable actor scale, and meaningful framing. It should not mean
shrinking the entire long Street map into one frame or stretching architecture.

## Recommended implementation order

1. Have one shared `world_content_rect` for the actual world stage. Compact the
   permanent top/bottom UI if the stage must occupy at least 540 of 720 pixels.
   Temporary dialogue and full-screen menus should be overlays, not permanent
   reductions of world height. Do not add an unrequested permanent sidebar.
2. Separate native rendering resolution from the chosen camera zoom. Preserve
   relative player zoom steps, but choose a readable per-presentation baseline.
   Do not blindly double every room's .85 zoom to 1.7.
3. Calculate real drawing bounds from the actual floor contour, wall tops and
   important object extent, rather than its enclosing world-size rectangle.
   Small rooms may fit the available stage; large/long rooms keep a stable actor
   scale and scroll. If a closer view crops the bedroom, enable actor following
   there too so its edge interactions remain visible.
4. Center and clamp the camera relative to the shared stage rectangle. Replace
   hardcoded actor-safe boxes with inset portions of that rectangle. The stage
   center can differ from the full viewport center.
5. Convert mouse and pan input using the actual WorldCanvas global rectangle
   and actual SubViewport size, including any stage offset. Keep real meters,
   collision, IDs, doors, contacts, damage and timings unchanged.
6. Test 1280×720 windowed, 1920×1080 fullscreen and 1366×768 (plus a non-16:9
   resize if supported): scene framing; actual pointer target; edge follow;
   dialogue/menu overlay; reset view; save/restore relative zoom/manual view.

## Deferred furniture status

The last in-flight image-generation call completed before the priority changed.
Atlas C and its 9 exact-cropped transparent layers are backed up with source SHA
and prompt. There are now 21 furniture sprite layers across A/B/C. The actual
preview renderer still supports only the original 8 furniture slots; the C
stool/stacked box/storage and attachments are explicitly marked as integration
deferred. Both production furniture and material global switches remain false.
No further furniture generation or UI/campaign edit was started for this audit.
