"""Read-only analysis of the actual ordinary-process Street observations."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().parent


def read(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


main = read(OUT / "natural_l5_r1/result.json")
samples = read(OUT / "natural_l5_r1/samples.json")
spaces = read(ROOT / "neurons/data/street_spaces.json")["rooms"]
cast = read(ROOT / "neurons/data/street_chapter.json")["actors"]


def cross_section(room, point, radius=.21, step=.02):
    """Physical width parallel to z through this actual sampled point.

    No simulation is run. This is a separately labelled static estimate from
    unchanged solid footprints. It excludes NPCs, beds and other dynamic bodies.
    """
    spec = spaces[room]
    width, depth = spec["size_m"]
    rectangles = [p["rect"] for p in spec["props"] if p.get("solid", True)]
    x, z = point

    def free(y):
        if not radius <= x < width - radius or not radius <= y < depth - radius:
            return False
        for a, b, w, d in rectangles:
            if a - radius <= x < a + w + radius and b - radius <= y < b + d + radius:
                return False
        return True

    if not free(z):
        return None
    distances = []
    for direction in (-1, 1):
        distance = 0
        while distance + step <= depth and free(z + direction * (distance + step)):
            distance += step
        distances.append(distance)
    return sum(distances) + 2 * radius


rows = []
for room_data in main["all_seven_rooms"]:
    room = room_data["room"]
    source = main
    sample_set = samples
    fixture = "Unmodified autonomous L5 crossing into Street"
    if room_data["branch"]:
        source = read(OUT / f"{room}_r2/result.json")
        sample_set = read(OUT / f"{room}_r2/samples.json")
        fixture = "Declared direct branch entrance; original actors and ordinary autonomous exit only"
    visits = [s for s in source["segments"] if s["room"] == room]
    if not visits:
        rows.append({"room": room, "actually_measured": False})
        continue
    segment = visits[0]
    skill_seconds = {}
    for index, sample in enumerate(sample_set):
        if sample["room"] != room or sample["paused"] or sample["ending"]:
            continue
        start = max(float(segment["entered_s"]), float(sample["street_s"]))
        following = sample_set[index + 1]["street_s"] if index + 1 < len(sample_set) else segment["left_s"]
        end = min(float(segment["left_s"]), float(following))
        for skill in sample.get("available_skills", []):
            skill_seconds[skill] = skill_seconds.get(skill, 0) + max(0, end - start)
    widths = [cross_section(room, s["pos_m"]) for s in sample_set if s["room"] == room]
    widths = [w for w in widths if w is not None]
    actors = [a for a in cast if a["room"] == room]
    row = {k: segment[k] for k in (
        "room", "elapsed_s", "distance_m", "walking_m", "forced_or_pose_displacement_m",
        "active_s", "paused_s", "moving_s", "body_busy_s", "gripped_s", "door_intent_s",
        "route_blocked_s", "entry_hp", "exit_hp", "entry_neurons", "exit_neurons",
        "entry_clusters", "damage_to_hero_hp", "damage_to_hero_sp", "actual_hero_hits",
        "actual_actor_hits", "visible_actors", "hostile_windup_or_active_s",
    )}
    row.update({
        "fixture": fixture,
        "actual_main_route": not room_data["branch"],
        "configured_actor_count": len(actors),
        "configured_initial_enemy_attackers": [a["id"] for a in actors if a["relation"] == "enemy" and a["attack"]],
        "available_skill_s_time_weighted_from_samples": skill_seconds,
        "minimum_static_z_cross_section_m_at_sampled_positions": min(widths) if widths else None,
        "static_z_cross_section_precision_m": .04,
        "cross_section_excludes_dynamic_bodies": True,
    })
    rows.append(row)

sources = [
    "AGENTS.md", "docs/HANDOFF.md",
    "DOCX/AI整理后文档/NEURONS_第一阶段_空间物品人员_合并修订版.docx",
    "neurons/data/street_chapter.json", "neurons/data/street_spaces.json", "neurons/data/skills.json",
    "neurons/scripts/campaign.gd", "neurons/scripts/core/street_chapter.gd",
    "neurons/scripts/core/combat_chapter.gd", "neurons/scripts/core/street_map.gd",
    "neurons/tests/street_pacing_measure_20261019.gd",
]
manifest = {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in sources}
summary = {
    "main_route": {"pre_street_s": main["pre_street_s"], "street_s": main["street_s"],
                   "distance_m": sum(s["distance_m"] for s in main["segments"]),
                   "entry_hp": main["segments"][0]["entry_hp"], "exit_hp": main["hp"],
                   "entry_neurons": main["segments"][0]["entry_neurons"], "exit_neurons": main["neurons"],
                   "clusters": main["clusters"], "max_unexplained_still_s": main["max_unexplained_still_s"],
                   "ending": main["ending"], "interventions_applied": 0},
    "seven_room_measurements": rows,
    "source_contract": "S1:P476-503: five main sections plus two optional single-mouth branches; no keys, search, rest, mandatory clear, all-identity meeting, or compulsory friendly deaths.",
    "player_goal": "Prevent host escape. The host's successful no-input run is a baseline escape pressure; NPC damage and delays can be passive benefits to the player.",
    "measurement_corrections": [
        "r1 raw 0.25s actor/skill duration weights undercount fixed30 samples, whose spacing is 0.2667s; this summary weights actual sample timestamps and clips room boundaries.",
        "Branch r1 wrongly counted formal-dialogue freeze as available intervention time. Driver r2 records presentation_paused and the retained r1 evidence is not used for that counter.",
        "No production rule or geometry was changed for either measurement correction.",
    ],
    "limitations": [
        "Direct L5 fixture has seven clusters and only initial SKIN, unlike full-campaign earned skills; the current full-campaign no-spending result has thirteen clusters and fifty-six neurons at its ending.",
        "Branch 0.575m values measure immediate autonomous return from a declared entry, not exploration of the whole room or a normally chosen player detour.",
        "Skill windows and actor phases are quarter-second observations, not guaranteed exact reaction deadlines. Pause menus allow planning beyond world-time windows.",
        "All source configured identities remain; not all were met or attacked. No change to NPC presence, RNG, speed, routes, resources, HP or ending fields after entry.",
        "Screenshots and full JSON time series retained; no continuous video or human pacing/art/audio acceptance claimed.",
    ],
    "source_sha256": manifest,
}
(OUT / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
for row in rows:
    print(row["room"], f'{row["elapsed_s"]:.2f}s', f'{row["distance_m"]:.2f}m',
          "HP damage", row["damage_to_hero_hp"], "SKIN available", row["available_skill_s_time_weighted_from_samples"],
          "static width", round(row["minimum_static_z_cross_section_m_at_sampled_positions"] or 0, 2))
