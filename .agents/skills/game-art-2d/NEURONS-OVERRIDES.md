# NEURONS local overrides

These rules implement the user's explicit 2026-10-14 request. They override
conflicting defaults in this skill and its references.

- Pure 2D fixed oblique scene. No runtime 3D, meshes, skinning, or old-project
  modifications. Low Poly means simplified shapes and light planes only.
- The project's pixel/painterly art contract controls scale, palette, sampling,
  and direction counts. Do not force the upstream default 16-color pixel style.
- Use the authorized built-in `image_gen` tool through `$imagegen`. Skill
  installation does not connect a service or prove quota. No silent CLI/API or
  separately billed provider switch.
- Preserve the complete opaque source PNG. Request a separate transparent edit
  for cutouts and preserve its real alpha. Never use green/blue chroma, paint a
  checkerboard into an image, or overwrite the unique source. No automatic
  deletion of pale bodies, thin links, or soft brushwork.
- Preview alpha on separate plain light and dark backgrounds, then in Godot.
  `make_contact_sheet.py` uses a checkerboard by default and is not selected for
  production here. Do not ship review backgrounds in runtime textures.
- `pixel_art_process.py` thresholds alpha and quantizes colors. Do not apply it
  to painterly production assets without a deliberate contract and edge review.
- `pack_spritesheet.py` shares scale but centers each alpha bounding box. This
  does not guarantee stable anatomical foot/hand anchors. Preserve the measured
  anchor across every cell; compensate for pose-dependent visible bounds.
- Scripts can overwrite their explicitly named outputs. Use versioned new
  output paths, repository-relative paths in metadata, and keep source, working,
  and runtime assets separate. Do not invoke scripts on the old project with an
  output path inside it.
- Start with one canonical small-monster draft. Obtain direction approval before
  deriving its animation family. The prototype is not the complete game; no bulk
  character/scene/animation expansion until the playable sample is approved.
- One initial draft and at most two targeted corrections per asset. Record the
  cause before retrying. Only final selected assets enter runtime references.
- Separate collision, navigation, interaction, visibility, ownership, timing,
  and true/known/forged narrative state from decorative imagery.

The 18 upstream files were downloaded with the official skill-installer in
download-only mode at commit `dee77ae174c2ace7faeac95103ac27f79c0f86ab` and verified
against Git blob hashes before the local SKILL.md override was inserted. The
scripts and references remain unmodified. `LICENSE` retains the upstream MIT
notice. Codex can discover this repository skill on the next turn; this turn
explicitly read and applied it and ran its audited `asset_qa.py`.
