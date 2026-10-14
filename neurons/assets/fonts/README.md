# Bundled UI font

`NotoSansCJKsc-Regular.otf` is the unmodified official Noto Sans CJK SC Regular
2.004 (embedded copyright: © 2014-2021 Adobe). It is licensed under SIL Open Font
License 1.1; keep `OFL-NotoSansCJK.txt` with redistributed game builds. No Windows
system font or separately licensed Microsoft font was copied.

- Official repository: https://github.com/notofonts/noto-cjk
- Fixed commit: `f8d157532fbfaeda587e826d4cd5b21a49186f7c`
- Source: `Sans/OTF/SimplifiedChinese/NotoSansCJKsc-Regular.otf`
- License: `Sans/LICENSE` at the same commit
- Downloaded 2026-10-14. No paid service or credential was used.
- Bytes: 16,437,364 (actual OpenType bytes, not a Git LFS pointer)
- Git blob SHA-1: `dc15562470b4f842321894787a0d066879ccff8b` (matches upstream)
- SHA-256: `2c76254f6fc379fddfce0a7e84fb5385bb135d3e399294f6eeb6680d0365b74b`
- Runtime reference: `res://assets/fonts/NotoSansCJKsc-Regular.otf`

`coverage-source-corpus.json` records static Unicode cmap format 4/12 coverage
against the three complete extracted human drafts. All characters from
`游玩体验 需求` and `关卡 周目 环境` are present. `人物` has 13 uncovered characters:

```text
◡ 䶷 䶸 䶹 䶺 䶼 𨉣 𩇬 𩇯 𩇱 𩉻 𩉼 𩍮
```

Do not replace or silently remove these original expressions/garbled-dialogue
characters. A licensed fallback covering these exact codepoints is still needed
before those dialogue lines can be called visually complete. Arbitrary emoji
coverage is not promised. Godot rendering/shaping and actual font-size
readability remain separate runtime checks; static coverage is not visual QA.

Only one font weight was fetched for the initial sample. Do not download an
entire family or copy OS fallback fonts into this folder without checking their
redistribution license.
