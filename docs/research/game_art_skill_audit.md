# 2D art skill and visual-method audit

Date: 2026-10-14 (Asia/Shanghai). This records audited tooling, sources actually
read/viewed, and implementation advice. It is not evidence that the game or
production art has passed runtime acceptance.

## Installed skill

- Explicitly applied `$game-art-2d` in **Direction + Audit** modes.
- Source: [woliveiras/geremmyas game-art-2d](https://github.com/woliveiras/geremmyas/tree/dee77ae174c2ace7faeac95103ac27f79c0f86ab/content/skills/game-art-2d).
- Fixed commit: `dee77ae174c2ace7faeac95103ac27f79c0f86ab`.
- License: [MIT, Copyright 2026 William Oliveira](https://github.com/woliveiras/geremmyas/blob/dee77ae174c2ace7faeac95103ac27f79c0f86ab/LICENSE).
  Full notice is retained at `.agents/skills/game-art-2d/LICENSE`.
- Install: official `skill-installer/scripts/install-skill-from-github.py`, with
  `--repo woliveiras/geremmyas --ref dee77ae174c2ace7faeac95103ac27f79c0f86ab
  --path content/skills/game-art-2d --dest .agents/skills --method download`.
  No Git clone, checkout, commit, or push was performed.
- All 18 upstream files verified byte-for-byte against Git blob SHA-1 using
  Python, without calling Git. Per-file hashes and sizes are in
  `.agents/skills/game-art-2d/UPSTREAM.json`.
- Local modification: inserted one override link in `SKILL.md`; added
  `NEURONS-OVERRIDES.md`. Scripts and references are unmodified.
- It can be discovered as a repository skill on the next turn. This turn read
  and executed the installed files directly, so use was not merely claimed.

Complete upstream inventory (no extra downloaded tools, model weights, or
dependencies hidden in this directory):

```text
SKILL.md
agents/openai.yaml
references/art-direction.md
references/characters-and-enemies.md
references/animation-and-spritesheets.md
references/maps-and-levels.md
references/items-props-vfx-and-ui.md
references/runtime-packaging-and-qa.md
references/style-pack-contract.md
references/godot/asset-pipeline.md
references/phaser/asset-pipeline.md
references/pixel-art/style-guide.md
references/pop-art/style-guide.md
scripts/asset_qa.py
scripts/make_contact_sheet.py
scripts/pack_spritesheet.py
scripts/pixel_art_process.py
scripts/slice_spritesheet.py
```

Full SKILL, YAML, all five scripts, and the art-direction, characters,
animation, maps, props/UI, runtime-QA, and Godot references were read. The Phaser
pipeline and alternate pixel/pop style packs were inventoried and preserved,
but were not adopted as project direction. No claim is made to have executed
the unrelated engine/style paths.

## Dependency and script review

Every script declares Python >=3.10 and Pillow >=10; there are no other package
dependencies. Available bundled runtime verified: Python 3.12.14, Pillow 12.3.0.
Use the per-machine workspace dependency loader to find the executable; do not
hard-code this machine's executable in runtime game code.

All five scripts are local image readers/processors. They contain no network
calls, shell/subprocess invocation, dynamic evaluation, credential access, or
recursive deletion. The four writers create parent folders and overwrite
explicit output names, so new versioned output paths remain necessary.

| Script | Review and use decision |
| --- | --- |
| `asset_qa.py` | Reads dimensions, format, alpha extrema/bbox, colors, and optional grid contracts; read-only. **Actually executed** on the user reference PNG. |
| `slice_spritesheet.py` | Deterministic row-major slicing with exact divisibility checks. Applicable after approved ordered strip exists; not executed without one. |
| `pack_spritesheet.py` | Uses one shared scale, but independently alpha-trims and bottom-centers each frame. A moving arm or hair changes bbox center; this can move anatomical feet. Do not equate its anchor label with verified foot alignment. |
| `pixel_art_process.py` | Resamples, quantizes palette, and thresholds alpha (default 96). Could destroy soft painterly edges/thin connections. Not selected for the original painterly source or animation batches. |
| `make_contact_sheet.py` | Draws a labeled checkerboard review background. Not selected under the user's no-checkerboard-art rule; use separate plain light/dark previews. |

The official installer and its `github_utils.py` helper were also read before
execution. Download-only mode prevents fallback Git operations. Its archive
extractor checks paths; it validates selected skill location and rejects unsafe
symlinks. MIT permission was verified before installation.

## Actual execution record

Invocation: bundled Python +
`.agents/skills/game-art-2d/scripts/asset_qa.py` + user attachment
`codex-clipboard-ce162324-a021-43da-8689-406d6d08b1ad.png --json`.

Result: exit 0, PNG RGBA, 222 x 272, alpha 0..255, 222 fully transparent pixels
(ratio 0.003676), visible bbox `[0, 0, 222, 271]`, 2,941 visible colors,
`issues: []`. The transparent pixels are only a small edge of the file; the
paper background remains opaque. This is a **design reference**, not a usable
transparent runtime sprite. The script succeeding does not approve the art.

Safe reusable command after the source has been copied into the project:

```text
<bundled-python> .agents/skills/game-art-2d/scripts/asset_qa.py art/raw/<source>.png --json
<bundled-python> .agents/skills/game-art-2d/scripts/asset_qa.py assets/<final>.png --require-alpha --expect-width <contract-width> --expect-height <contract-height> --json
```

This execution is intentionally limited to auditing the supplied reference.
Generated source processing, actual imported resource, and running engine
capture must be recorded by the integration task once they exist.

## User rules overriding upstream defaults

Upstream mentions chroma removal in SKILL and several reference prompts. The
installed current `$imagegen` and the user require built-in transparency
instead. No green/blue key or baked checkerboard is used. Preserve a complete
opaque source PNG, then a separately generated transparent edit; never replace
the only source. The user's painterly/pixel hybrid replaces the upstream
default pixel pack. No external paid API or batch expansion is authorized.
The approved mother image anchors later derivatives; generation is deferred
until the project art contract is written and the parent task is ready.

## Official screenshots actually viewed

The Steam storefront/API provided publisher-owned screenshots. Five screenshot
images were opened in the browser and visually inspected. No gameplay video,
audio, or frame-by-frame animation was watched. Screenshots are reference-only;
no copyrighted game artwork was copied into the project. The following are
observations and proposed applications, not claims about original game code.

| Source and inspected image | Observation | Application to NEURONS |
| --- | --- | --- |
| [Death's Door official Steam](https://store.steampowered.com/app/894020/Deaths_Door/), screenshot `ss_dd9b5a2e40d3d512d1c978a5dfda5999c458a517` | Pale clear central path separates small dark character from warm clustered foliage; foreground fence frames depth; simple repeated forms carry space. | Preserve quiet floor values and a continuous clear action lane. Use floor/back-wall/props/actors/foreground layers; never infer walkability from image color. Treat simplified planar shading as a 2D painting choice. |
| [STASIS: BONE TOTEM official Steam](https://store.steampowered.com/app/1426010/STASIS_BONE_TOTEM/), screenshot `ss_e0617295ffc18f9ff46dc407606778f5abf735ba` | Warm/cool pools locate machinery and routes; debris concentrates at edges, central route reads; silhouette and light identify narrative objects. | Use local clues and light relationships. Do not copy dense gore/debris into the opening bedroom. Necessary furniture and narrative order remain source-document controlled. |
| [Mouthwashing official Steam](https://store.steampowered.com/app/2475490/Mouthwashing/), screenshot `ss_ec922c5769acb9986aa009e41b71ecdcd51e484f` | Familiar containers dominate foreground while a person occupies a warm pool behind; mundane objects and uncomfortable framing create tension without constant global glitch. | Keep ordinary opening warmth; later event-authored foreground occlusion/state changes carry unease. Keep intervention target and action visible. Do not adopt first-person camera or copy packaging/dialogue. |
| [Disco Elysium official Steam](https://store.steampowered.com/app/632470/Disco_Elysium__The_Final_Cut/), screenshot `ss_b3694e99ffdb686d1bbbbe16a540d3d2ccd509c4` | Low-saturation ochre/grey ground with broken brush edges; architectural diagonals enclose a readable actor area; foreground roof is a separate dark mass. | Broad painterly masses with restrained detail, controlled hard/soft edges; reserve strongest contrast for actor/interaction. Foreground obstruction is independent from collision. |
| Same Disco source, screenshot `ss_9125a718ee9ba85386ae5d4eb820f3266073fc97` | Illustrated icons are strongly grouped by limited color accents while numeric labels remain sharply separate. | UI text/numbers remain Godot controls. Borrow information hierarchy only, not card composition, character illustrations, or skill imagery. |

The inspected screenshot URLs can be recovered through the official endpoint
`https://store.steampowered.com/api/appdetails?appids=<app-id>` and the IDs above;
store CDN query tokens are not project runtime dependencies.

## Developer production breakdown actually read

[THE BROTHERHOOD development post, 2021-09-01](https://www.thebrotherhoodgames.com/studio/?read=6767)
describes planning connected scene art around already-decided interactions and
multiple characters. Applied lesson: validate bedroom layout, approach points,
interaction clearance, and original room relationships before painting the
scene; build removable objects separately. The post's 3D modeling pipeline and
control scheme are not adopted. This was text/screenshot research, not a claim
to have watched the linked podcast or videos.

## Godot examples reviewed and implementation boundary

[Godot sprite animation tutorial](https://docs.godotengine.org/en/stable/tutorials/2d/2d_sprite_animation.html)
documents SpriteFrames/AnimatedSprite2D and AnimationPlayer. Use one visual
timeline per action with explicit anticipation/contact/recovery; gameplay owns
the interruptible contact commit. Sprite frame playback alone must not award an
item or damage. The document notes `play()` applies on the next animation
processing step; `advance(0)` can remove a visual start-frame mismatch when
necessary. Verify against the installed engine version before using its API.

[Godot screen-reading shaders](https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html)
explains `hint_screen_texture`, `SCREEN_UV`, mip-level blur, and back-buffer
ordering. Proposed mild tilt-shift uses a spatial mask, only on world imagery;
UI and critical actors/targets are excluded by layer/mask. Disable during
readability tests. Overlapping screen effects do not automatically see previous
screen effects, so use a deliberate ordering or single composite pass.

Official [screen-space shader demo](https://github.com/godotengine/godot-demo-projects/tree/b761b4cd5718a7118f2c95eb55f181d0a5f004f1/2d/screen_space_shaders)
was inspected at commit `b761b4cd5718a7118f2c95eb55f181d0a5f004f1`: README and full
`blur.gdshader`, `pixelize.gdshader`, `BCS.gdshader`. README specifies Compatibility.
The blur samples screen mipmaps; pixelize snaps UV cells; BCS remaps brightness,
contrast, and saturation. These files were read, not copied or run. Do not apply
pixelize/BCS blindly to text or enforce strong saturation across all scenes.
No 3D depth texture is needed for the proposed 2D masked blur.

## User PDF reading and selected methods

The extracted text of **game_visual_reference_library_optimized.pdf** was fully
read, pages 1-5 (including repeated-game index). The extracted text of
**Shader视觉效果与风格总清单_高覆盖率核验版.pdf** was fully read, pages 1-6,
including its 149-effect index and independent-effect-family notes. Full-page
PNG renders were inspected for visual library page 2 and Shader list page 5.
They are tables of methods/links, not mandatory implementation requirements.
Other pages were text-read, not visually inspected; linked demonstrations in
those PDFs were not all opened or executed.

| Source | Selected for the sample | Deferred / not selected |
| --- | --- | --- |
| Visual library p1-2, low-resolution, Low Poly, painterly groups | Limited shared palette; broad painted light/shadow planes; simplified readable silhouettes; layered 2D composition | No runtime HD-2D 3D world, PBR, photogrammetry, voxel or mesh/rig pipeline |
| Visual library p3-4, color/CRT/interface groups | Reserve contrast for actors/interaction; warm ordinary opening; CRT language only within neural menu; Godot text remains crisp | No full-scene PS1 jitter, VHS dirt, constant aberration, blanket black/white horror filter, or new interface narrative |
| Shader list p2, Squash & Stretch | Small anchored visual deformation may support approved monster poses after approval; never deform collision/logic distances | No constant jelly movement or geometry-based material pipeline |
| Shader list p3, Hit Flash and visibility | Local low-intensity hit tint/outline; actor visibility kept readable behind foreground | Do not infer invulnerability, damage, new X-ray skill, or through-wall targeting from an effect |
| Shader list p4-5, blur and CRT | Optional slight focus mask when zoomed out; restrained CRT scanline decorative layer; keep text/targets clear | No default motion blur, heavy grain, chromatic aberration, full-screen flashes or shake |
| Shader list p5, ripple/shine/transitions | Small submit pulse and invalid-action state; existing authorized transitions may crossfade | No transition hiding an interruptible action; no fake success when a rule fails |
| Shader list p6 experimental families | No immediate need | No raymarch 3D scenes, Mandelbulb, cosmic effects, or generic VFX expansion |

Concrete adopted outputs so far: a vendored audited skill, its project override
contract, reference image QA, and this bounded source/method record. Subsequent
art contract and gameplay integration must cite which proposals were actually
implemented; this report does not mark suggestions as engine-verified features.

## Generated mother-image QA follow-up

After the main task generated `art/source/player_master_v001.png`, the audited
`asset_qa.py` was executed on this project-relative input with `--json`. The
saved result is `docs/research/player_master_qa.json`: RGB PNG, 1133 x 1388,
fully opaque, 64,757 visible colors, no technical issues, script exit 0. This
confirms the source was preserved as an opaque image; it does not approve the
character design or make it a transparent sprite. No expression/action variants
were produced by this audit task.

## Licensed UI font follow-up

The [official Noto CJK repository](https://github.com/notofonts/noto-cjk) and
[SIL OFL 1.1 license](https://github.com/notofonts/noto-cjk/blob/f8d157532fbfaeda587e826d4cd5b21a49186f7c/Sans/LICENSE)
were checked before downloading one regular weight into
`neurons/assets/fonts/NotoSansCJKsc-Regular.otf`. Original license is preserved;
source version, checksums, and limitations are in that folder's README. No
font was copied from Windows. The actual file matches the upstream blob hash.

Static cmap coverage was tested across all three extracted human originals.
Two documents have no missing characters; `人物` has 13 missing symbols/extended
CJK codepoints, listed in `neurons/assets/fonts/coverage-source-corpus.json`.
The coverage file was written successfully; the first attempt to print it hit
the terminal's GBK encoding limit, then it was re-read as UTF-8 to inspect the
complete result. This was a console encoding issue, not a glyph-check success
for the missing codepoints. Runtime glyph appearance remains unverified here.
