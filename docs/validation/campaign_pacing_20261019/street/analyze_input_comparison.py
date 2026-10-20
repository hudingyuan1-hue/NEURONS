"""Compare actual same-checkpoint ordinary-process runs and real UI inputs."""
import hashlib
import json
from pathlib import Path

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[3]


def read(name, file="result.json"):
    return json.loads((OUT / name / file).read_text(encoding="utf-8"))


baseline = read("exit_baseline_r1")
initial = read("exit_baseline_r1", "initial_entry_fixture.json")
base_final = read("exit_baseline_r1", "final_snapshot.json")
base_world = base_final["street_state"]["clock"] - initial["street_state"]["clock"]


def differences(a, b, path=""):
    result = []
    if isinstance(a, dict) and isinstance(b, dict):
        for k in a.keys() | b.keys():
            key = path + "/" + k
            if k not in a or k not in b:
                result.append({"path": key, "source": a.get(k), "restored": b.get(k)})
            else:
                result.extend(differences(a[k], b[k], key))
    elif isinstance(a, list) and isinstance(b, list) and len(a) == len(b):
        for i, (v, w) in enumerate(zip(a, b)):
            result.extend(differences(v, w, path + "/" + str(i)))
    elif a != b:
        result.append({"path": path, "source": a, "restored": b})
    return result


rows = []
for name in ("exit_baseline_r1", "exit_skin_r1", "exit_startle_r1", "exit_startle_r2"):
    result = read(name)
    start = read(name, "initial_entry_fixture.json")
    end = read(name, "final_snapshot.json")
    world = end["street_state"]["clock"] - start["street_state"]["clock"]
    attacks = [e for e in result["events"] if e.get("fact", {}).get("kind") == "combat_attack_started"]
    hits = [e for e in result["events"] if e.get("fact", {}).get("kind") == "combat_hit"]
    ids = ("hero_pos", "hero_facing", "route", "rng_state", "rules")
    restored_diffs = []
    for key in ("street_state", "combat_state", "session"):
        restored_diffs.extend(differences(initial[key], start[key], key))
    row = {
        "run": name,
        "reason": result["reason"],
        "elapsed_s": result["street_s"],
        "actual_world_s": world,
        "presentation_or_menu_frozen_s": max(0, result["street_s"] - world),
        "world_delay_vs_no_input_s": world - base_world,
        "total_elapsed_delay_vs_no_input_s": result["street_s"] - baseline["street_s"],
        "distance_m": sum(s["distance_m"] for s in result["segments"]),
        "entry_hp": start["rules"]["hp"], "exit_hp": end["rules"]["hp"],
        "neurons_paid": start["rules"]["neurons"] - end["rules"]["neurons"],
        "clusters_paid": start["rules"]["plexus"] - end["rules"]["plexus"],
        "actual_skill_submissions": result["skill_submissions"],
        "actual_skill_resolutions": result["skill_resolutions"],
        "actual_attack_starts": attacks,
        "actual_hero_hits": hits,
        "ui_inputs": result["recorded_inputs"],
        "same_initial_rules_position_route_rng": {key: initial[key] == start[key] for key in ids},
        "same_initial_all_45_actor_states": initial["street_state"]["actors"] == start["street_state"]["actors"],
        "restore_normalization_differences": restored_diffs,
        "ending": result["ending"],
        "stderr_bytes": (OUT / name / "stderr.log").stat().st_size,
    }
    rows.append(row)
    print(name, "elapsed", round(row["elapsed_s"], 3), "world", round(world, 3),
          "world delay", round(row["world_delay_vs_no_input_s"], 3),
          "paid", row["neurons_paid"], row["clusters_paid"],
          "attacks", len(attacks), "actual hero hits", len(hits))

report = {
    "fixture": "Explicit initial Street exit room. Original forty-five NPCs and original skills/resources. All later runs restore the unchanged actual initial_entry_fixture.json through production restore_snapshot.",
    "checkpoint_sha256": hashlib.sha256((OUT / "exit_baseline_r1/initial_entry_fixture.json").read_bytes()).hexdigest(),
    "comparisons": rows,
    "production_changes_by_measurement": [],
    "observed_player_feedback": [
        "Actual SKIN popup shows effect, one-neuron cost, remaining balance and directional displacement.",
        "Actual early cooldown repeat says 冷却尚未结束 and does not charge.",
        "Actual TEMP and STARTLE tree purchases reduce clusters by one and two; original growth dialogue plays automatically.",
        "Moving the pointer from selected SKIN node to direction controls clears the descriptive text pane. Keep selected description as a small UI follow-up.",
    ],
    "measurement_failure_preserved": "exit_startle_r1 first immediate Tab met the original three-frame post-close input lock; not a free skill or rule fix. r2 waits for the actual lock to expire, then performs two paid casts through input.",
    "restore_boundary": "The production restore initializes empty lateral-bed travel, rebuilds appearance fact-count caches, and supplies absent legacy institution/cortex version defaults. Initial rules, RNG, actor states, positions and routes are equal. No source checkpoint fields were edited.",
    "clock_boundary": "Use saved production Street.clock delta for active-time comparison. Observer active_s can miss initialization/capture callback frames (up to 0.17s here); it must not override the actual game clock. Observed elapsed and game-clock intervals differ by that small sampling boundary.",
    "conclusion": "Directional paid interventions change path and real NPC attacks; two paid backward STARTLE actions delay active escape by about three seconds. Host still evades and reaches E2, with no manufactured injury. These bounded scripts validate effect/feedback and cost, not overall player difficulty or all strategies.",
    "media": ["exit_skin_r1/continuous_silent.mp4", "exit_startle_r1/continuous_silent.mp4", "exit_startle_r2/continuous_silent.mp4"],
}
(OUT / "input_comparison.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
