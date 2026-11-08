"""根据既有音效清单生成 Suno v6 音效计划。"""

from __future__ import annotations

import csv
import json
import os

OLD_MANIFEST = r"c:\Users\aiail\Documents\jam\audio\sfx\manifest.csv"
OUT_DIR = r"c:\Users\aiail\Documents\jam\audio\sfx_suno\_batch"

PHRASES = {
    "player/pl_footstep_metal_01.wav": "one metal boot footstep on a spaceship floor, low thump and metallic heel click",
    "player/pl_footstep_metal_02.wav": "one lighter metal boot footstep on a spaceship floor, crisp heel click",
    "player/pl_footstep_metal_03.wav": "one metal boot footstep on a spaceship floor, heel scuff and short metal resonance",
    "player/pl_footstep_metal_heavy.wav": "one heavy metal boot footstep on a spaceship floor, deep thump and sharp heel click",
    "player/pl_hurt.wav": "player hurt, short sharp gasp and suit impact, cuts through gunfire",
    "player/pl_death.wav": "player death, suit decompression hiss and descending power-down tone",
    "player/pl_pickup_heal.wav": "short rising electronic pickup chime, soft shimmer, health restore",
    "player/pl_low_health.wav": "sparse low health warning pulse, two soft heartbeat thumps",
    "player/pl_dash.wav": "short dash whoosh, air and spacesuit fabric movement",
    "weapons/wp_shoot_01.wav": "sci-fi energy rifle shot, capacitor zap and electric crack",
    "weapons/wp_shoot_02.wav": "sci-fi energy rifle shot, sharper high crack and short low thump",
    "weapons/wp_shoot_03.wav": "sci-fi energy rifle shot, deeper capacitor discharge and metallic tail",
    "weapons/wp_hit_organic.wav": "bullet hitting an organic alien body, wet thud and short electronic confirm",
    "weapons/wp_hit_metal.wav": "bullet hitting a metal surface, crisp metallic ping and short tick",
    "weapons/wp_hit_glass.wav": "bullet hitting a glass container, short glass tick and tiny shards",
    "weapons/wp_reload.wav": "sci-fi energy rifle reload, magazine clack, mechanical lock and energy module insert",
    "weapons/wp_empty.wav": "empty weapon dry click and short refusal buzz",
    "weapons/wp_charge_loop.wav": "rising energy weapon charge whine, loopable capacitor hum",
    "weapons/wp_overheat_warning.wav": "weapon overheat warning, three short urgent beeps and low buzz",
    "weapons/wp_cooldown_complete.wav": "weapon cooldown complete, soft descending relief chime",
    "weapons/wp_switch.wav": "weapon switch, servo movement, latch click and short electronic confirm",
    "enemies/en_alert_01.wav": "alien humanoid creature alert cry, short distorted growl and electronic chirp",
    "enemies/en_alert_02.wav": "alien bug creature alert, chitin clicks and high chirp",
    "enemies/en_melee_warning.wav": "melee enemy attack warning, low growl, joint creak and rising tension",
    "enemies/en_broom_whoosh.wav": "broom weapon swing whoosh, air and brush friction",
    "enemies/en_broom_hit.wav": "broom weapon hit, dull thump and brush scrape",
    "enemies/en_hurt_01.wav": "alien creature hurt grunt, wet organic impact",
    "enemies/en_hurt_02.wav": "alien creature hurt, shorter higher grunt and electric tick",
    "enemies/en_hurt_glass.wav": "glass jar creature hurt, glass tick and squeak",
    "enemies/en_death.wav": "alien creature death, body collapse thud and electric power-down",
    "enemies/en_death_glass.wav": "glass jar creature death, glass shatter and liquid spill",
    "enemies/en_idle_humanoid_loop.wav": "humanoid enemy idle loop, dragging footsteps, cloth and gear rustle",
    "enemies/en_idle_bug_loop.wav": "bug enemy idle loop, chitin clicks, crawling and short chirps",
    "enemies/en_ranged_charge.wav": "alien ranged weapon charge, rising pressure whine and hiss",
    "enemies/en_ranged_spray.wav": "alien ranged weapon spray, wet sputtering burst",
    "enemies/en_ranged_land.wav": "alien projectile landing, wet splat and short hiss",
    "enemies/en_heal_start.wav": "medical enemy heal start, soft rising warm tone and shimmer",
    "enemies/en_heal_loop.wav": "medical enemy heal loop, soft pulsing warm pad and shimmer",
    "enemies/en_heal_end.wav": "medical enemy heal end, soft descending tone",
    "enemies/en_energy_charge.wav": "energy enemy charge, rising electric hum and crackle",
    "enemies/en_energy_shield_hit.wav": "energy enemy shield hit, glassy chime and electric crack",
    "enemies/en_energy_disconnect.wav": "energy enemy connection break, power-down zap and cable snap",
    "boss/bo_arm_idle_loop.wav": "mechanical arm idle loop, low servo motor hum and metal creak",
    "boss/bo_sweep_warning.wav": "mechanical arm sweep warning, motor spin-up and three urgent beeps",
    "boss/bo_sweep.wav": "mechanical arm sweep, heavy motor movement and air whoosh",
    "boss/bo_slam_charge.wav": "mechanical arm slam charge, low pressure build and rhythmic ticks",
    "boss/bo_slam_impact.wav": "mechanical arm slam impact, heavy metal crash and debris",
    "boss/bo_damage_shutdown.wav": "mechanical arm damage shutdown, power-down, jam and structural crack",
    "objects/ob_mechanism_start.wav": "generic mechanism startup, electric motor spin-up and relay click",
    "objects/ob_mechanism_stop.wav": "generic mechanism stop, motor power-down and metal clunk",
    "objects/ob_facility_hit_01.wav": "facility hit, metal impact and short electric zap",
    "objects/ob_facility_hit_02.wav": "facility hit, deeper metal impact and crackle",
    "objects/ob_facility_destroy.wav": "facility destroyed, metal tear, electric arc and collapse",
    "objects/ob_glass_break.wav": "glass container shatter, glass shards and liquid spill",
    "objects/ob_container_release.wav": "container release, pressure hiss, glass crack and creature wake",
    "objects/ob_fuel_explosion.wav": "fuel container explosion, blast, low boom and debris",
    "objects/ob_explosion_warning.wav": "explosion warning, gas hiss and rising danger beeps",
    "objects/ob_leak_spark_loop.wav": "leaking pipe and electric sparks loop, crackle and hiss",
    "objects/ob_vacuum_start.wav": "vacuum extractor startup, motor spin-up and suction",
    "objects/ob_vacuum_loop.wav": "vacuum extractor suction loop, strong air suction and motor hum",
    "objects/ob_vacuum_stop.wav": "vacuum extractor stop, motor power-down and valve clunk",
    "objects/ob_door_open.wav": "sci-fi airlock door opening, electric servo slide, pneumatic hiss and heavy latch clunk",
    "objects/ob_door_close.wav": "sci-fi airlock door closing, electric servo slide and heavy latch clunk",
    "objects/ob_lock_denied.wav": "locked door refusal, low buzz and metal clunk",
    "objects/ob_unlock.wav": "door unlock confirmation, relay click and short rising chime",
    "puzzle/pu_terminal_enter.wav": "sci-fi terminal screen power-on, relay click, CRT whine and static",
    "puzzle/pu_terminal_exit.wav": "sci-fi terminal screen power-off, descending whine and click",
    "puzzle/pu_click.wav": "short crisp sci-fi UI button click",
    "puzzle/pu_rotate_01.wav": "mechanical puzzle dial tick, short click and electronic beat",
    "puzzle/pu_rotate_02.wav": "mechanical puzzle dial tick, slightly higher click",
    "puzzle/pu_step_correct.wav": "puzzle step correct, two-note rising soft chime",
    "puzzle/pu_error.wav": "puzzle input error, short descending buzz",
    "puzzle/pu_puzzle_complete.wav": "puzzle complete, three-note rising confirmation chime and relay",
    "puzzle/pu_clue_get.wav": "clue acquired, short data download chirps and soft shimmer",
    "puzzle/pu_signal_tune_loop.wav": "radio signal tuning loop, static narrowing into a clear tone",
    "puzzle/pu_broadcast_start.wav": "radio broadcast start, chime and short static",
    "puzzle/pu_broadcast_end.wav": "radio broadcast end, click and static fade",
    "ambience/amb_ship_vent_loop.wav": "spaceship ventilation and air circulation background, low hum and airy noise",
    "ambience/amb_cockpit_living_loop.wav": "cockpit and living quarters ambience, instrument hum, ventilation, sparse navigation blips",
    "ambience/amb_storage_loop.wav": "storage bay ambience, servo devices, metal shelves rattle and low machinery",
    "ambience/amb_sanitation_loop.wav": "sanitation and waste bay ambience, pipe liquid flow, water drips and exhaust valve",
    "ambience/amb_comms_loop.wav": "communications room ambience, receiver static, data pulses and radio crackle",
    "ambience/amb_medical_loop.wav": "medical and hibernation bay ambience, device hum, slow monitor beeps and pod circulation",
    "ambience/amb_life_energy_loop.wav": "life energy bay ambience, low energy hum, container bubbles and circulation pump",
    "ambience/amb_fuel_loop.wav": "fuel bay ambience, pipe pressure hum and valve clicks",
    "ambience/amb_anomaly_hull_resonance_loop.wav": "ship hull low resonance, deep groaning metal",
    "ambience/amb_anomaly_lighting_fault_loop.wav": "failing lighting electric buzz and crackle",
    "ambience/amb_anomaly_damaged_alarm_loop.wav": "damaged equipment intermittent alarm beeps in a dark room",
    "state/st_death_rewind.wav": "death rewind transition, reversed electronic swoop and tape stop",
    "state/st_respawn.wav": "respawn confirmation, low impact and rising air",
    "state/st_cycle_start.wav": "new cycle start marker, deep sub hit and reversed shimmer",
    "state/st_cycle_distortion_loop.wav": "degraded broadcast and room tone loop, tape wobble and glitches",
    "state/st_story_anomaly.wav": "story anomaly reveal, low ominous hit and reversed tail",
    "state/st_ending_clear.wav": "ending clear, warm unresolved synth chord, starfield shimmer and tape stop",
    "state/st_ending_failure.wav": "ending failure, low power-down, flatline tone and static",
    "ui/ui_menu_select.wav": "short high sci-fi UI select tick",
    "ui/ui_menu_confirm.wav": "sci-fi UI confirm, two-note rising chime",
    "ui/ui_menu_back.wav": "sci-fi UI back, two-note descending chime",
    "ui/ui_pause.wav": "pause sound, tape stop and low thump",
    "ui/ui_resume.wav": "resume sound, rising servo and click",
    "ui/ui_objective_update.wav": "objective update, light two-note confirmation",
}


def clamp_text(text: str, limit: int = 195) -> str:
    if len(text) <= limit:
        return text
    cut = text[:limit]
    if " " in cut:
        cut = cut.rsplit(" ", 1)[0]
    return cut.rstrip(",.") + "."


def build_plan() -> list[dict]:
    with open(OLD_MANIFEST, encoding="utf-8-sig") as fh:
        rows = list(csv.DictReader(fh))

    plan = []
    for row in rows:
        file = row["file"]
        phrase = PHRASES.get(file)
        if not phrase:
            raise KeyError(f"missing phrase for {file}")
        is_loop = row["loop"] == "yes"
        title = f"{row['id']} {os.path.splitext(os.path.basename(file))[0]}"
        if is_loop:
            tags = clamp_text(
                f"seamless ambient loop, no music, no melody, no drums, sound design: {phrase}. "
                "continuous background texture, loopable"
            )
            prompt = "[Instrumental]"
            mode = "20"
        else:
            prompt = clamp_text(
                f"Single dry sound effect, no music, no melody: {phrase}. "
                "Isolated one-shot, close-mic game SFX."
            )
            tags = ""
            mode = "10"
        plan.append({
            "id": row["id"],
            "file": file,
            "category": row["category"],
            "loop": is_loop,
            "mode": mode,
            "title": title,
            "phrase": phrase,
            "prompt": prompt,
            "tags": tags,
        })
    return plan


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    plan = build_plan()
    path = os.path.join(OUT_DIR, "plan.json")
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(plan, fh, ensure_ascii=False, indent=2)
    print(f"wrote {len(plan)} entries -> {path}")
    print(f"loops: {sum(1 for p in plan if p['loop'])}")
    print(f"max prompt length: {max(len(p['prompt']) for p in plan)}")
    print(f"max tags length: {max(len(p['tags']) for p in plan)}")


if __name__ == "__main__":
    main()
