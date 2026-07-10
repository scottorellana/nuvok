#!/usr/bin/env python3
"""Generate all 17 missing emergency guide images via Codex gpt-image-2."""
import subprocess, sys, os, time

VENV = os.path.expanduser("~/.hermes/hermes-agent/venv/bin/python3")
SCRIPT = os.path.expanduser("~/Nuvok-pad/scripts/generate_guide_image.py")
OUT_DIR = os.path.expanduser("~/Nuvok-pad/assets/emergency_guides/images")

# Each guide: (filename, prompt)
# Prompts designed to be photorealistic, educational, and safe:
# - Avoid showing hands directly on bodies for medical techniques
# - Use wide scenes, object close-ups, and contextual compositions
# - Portrait (1024x1536) for guides that work better vertical
# - Landscape (1536x1024) for scenes and flat-lays

GUIDES = [
("abrigo_refugio", "1536x1024",
"Photorealistic emergency survival scene in a cold mountain forest at dusk. A person wearing outdoor clothing is building an improvised debris shelter from branches, pine needles, and dry leaves. The shelter is half-built, showing the structural A-frame of leaning branches against a fallen log, with a thick layer of insulating debris being added on top. A silver mylar emergency space blanket is spread on the ground inside. A small camp fire burns nearby casting warm golden light. Cold blue twilight atmosphere. The image clearly demonstrates wilderness emergency shelter construction. Cinematic documentary style, high detail. No text."),

("agua_survival", "1536x1024",
"Photorealistic close-up of emergency water purification in a wilderness survival setting. A clear plastic water bottle filled with murky river water sits on flat rocks beside a flowing stream. Next to it, a second bottle shows the same water after filtering, visibly clearer. A small stainless steel camp cup sits on a portable camping stove with water boiling vigorously, steam rising. Clean cotton cloth and activated charcoal pieces arranged on a flat stone demonstrate filtration materials. Natural daylight through forest canopy. Sharp focus, shallow depth of field. Educational documentary photography. No text."),

("alimentacion_supervivencia", "1536x1024",
"Photorealistic overhead flat-lay of emergency survival food items on a dark wooden surface: canned beans, canned tuna, energy bars, dried fruit, nuts in a small cloth pouch, a folding knife, water purification tablets, a metal canteen, and a small fishing line with hooks wrapped around a stick. Wild edible plants like dandelion leaves and berries arranged on a large leaf in the background, slightly out of focus. Organized educational composition like a survival gear catalog. Warm natural lighting. Sharp focus on foreground. No text."),

("botiquin", "1536x1024",
"Photorealistic overhead flat-lay of a comprehensive emergency first aid kit on a dark olive green surface. Items clearly identifiable: rolled gauze, adhesive bandages, medical tape, scissors, tweezers, antiseptic wipes in foil packets, a triangular bandage folded, disposable gloves, antiseptic solution bottle, folded emergency space blanket, SAM splint in orange, a tourniquet with black and red strap, and a CPR face shield in a blue pouch. Items arranged in organized grid. Even studio lighting, sharp focus across entire frame. No text."),

("convulsiones", "1024x1536",
"Photorealistic scene of emergency seizure response. An adult lies on their left side on a living room floor, eyes closed, appearing to recover. A cushion is placed under their head. Nearby furniture and objects have been pushed away to create a clear safe space. A person kneels nearby with a concerned but calm expression, watching and timing with a wristwatch. The scene demonstrates the correct first aid: turning the person on their side, protecting the head, clearing the area, and timing the seizure. Soft indoor lighting. No text."),

("hipotermia_golpe_calor", "1536x1024",
"Photorealistic split-scene emergency temperature disorders. LEFT SIDE: a person in winter mountain conditions, visibly cold, shivering, pale skin, wearing insufficient clothing, snow and blue-grey tones, breath visible. RIGHT SIDE: a person in desert heat, red flushed skin, sweating profusely, sitting in shade with a water bottle, harsh orange sunlight, heat shimmer. The contrast clearly shows hypothermia versus heat stroke symptoms. Educational medical photography style. No text."),

("infarto_acv", "1536x1024",
"Photorealistic educational scene showing the FAST stroke recognition method. A concerned person looks at a family member sitting at a kitchen table. The family member has visible facial drooping on one side, one arm drifting downward when raised, and a confused expression. A wall clock is visible in the background suggesting time is critical. Warm indoor kitchen lighting. The image communicates urgency and the FAST acronym concept: Face drooping, Arm weakness, Speech difficulty, Time to call emergency. Documentary style. No text."),

("intoxicaciones", "1536x1024",
"Photorealistic scene of suspected poisoning emergency. A kitchen counter with household cleaning products: a bleach bottle, pesticide spray, and medication bottles scattered. A person sits nearby looking distressed, holding their stomach, pale and sweating. A phone is being held ready to call poison control. The image communicates the danger of household chemical poisoning and the need to act fast. Natural kitchen lighting, slightly tense atmosphere. Educational safety photography. No text."),

("inundacion", "1536x1024",
"Photorealistic aerial view of an urban flood disaster scene. Streets submerged in brown muddy water, cars half underwater, people evacuating on foot carrying backpacks and belongings through chest-deep water. A two-story building with people on the roof signaling for help. Dark storm clouds, heavy rain. The image clearly shows the scale and danger of a flash flood emergency. Photojournalistic disaster photography style. No text."),

("mordeduras_picaduras", "1536x1024",
"Photorealistic close-up scene of snake bite first aid in a wilderness setting. A hiking boot and lower leg visible with two small puncture marks on the ankle. A person's hands are wrapping a pressure bandage firmly around the bite area, starting from the toes upward, as taught in snake bite first aid. The person is sitting calmly on a rock in a forest clearing. A field guidebook and water bottle are nearby. Natural forest daylight. Educational medical photography style. No text."),

("navegacion", "1536x1024",
"Photorealistic scene of wilderness land navigation. A compass and a topographic paper map are placed on a flat rock in a mountain landscape. A person's hand holds the compass flat over the map, aligning the needle. Distant mountain peaks and a valley are visible in the background. Golden hour sunlight casts long shadows. The image demonstrates traditional map and compass navigation without GPS. Adventure photography style, sharp detail on compass and map. No text."),

("parto_emergencia", "1536x1024",
"Photorealistic scene of emergency childbirth preparation. A clean towel is spread on a bed. Clean scissors, clean string, gloves, and clean blankets are arranged nearby on a surface. A pregnant woman lies on her side, breathing through a contraction, supported by a calm companion who is timing contractions with a phone. The scene is set in a simple bedroom with warm lighting. The image communicates preparedness, calm, and the basic supplies needed for emergency delivery. Sensitive documentary photography style. No text."),

("primeros_auxilios_extremos", "1536x1024",
"Photorealistic scene of tactical first aid equipment laid out on a dark surface: a tourniquet (CAT-style with black strap and windlass), Israeli bandage, hemostatic gauze in foil pouch, chest seal dressing, trauma shears, nitrile gloves, and a nasopharyngeal airway. Items arranged in order of the MARCH/XABCDE trauma assessment protocol. Dramatic lighting from above. The image communicates the seriousness and organization of combat-level trauma care. Educational military medical photography style. No text."),

("senas_rescate", "1536x1024",
"Photorealistic scene of emergency rescue signals on a mountain ridge. Three signal fires arranged in a triangle pattern on a rocky peak, producing white smoke visible against a blue sky. On the ground, a large orange VS-17 signal panel is spread out. A mirror is angled to catch sunlight, creating a bright reflection. A person stands nearby waving a bright orange jacket. The scene clearly demonstrates multiple visual rescue signaling methods. Mountain landscape background, dramatic sky. Adventure survival photography. No text."),

("shock", "1024x1536",
"Photorealistic scene of a person in medical shock lying on their back on the ground with legs elevated on a backpack. The person is pale, with cold sweat visible on their face, eyes half-open and confused. A rescuer kneels beside them, holding their hand and covering them with an emergency blanket. The scene is outdoors, natural light, slightly overcast. The image demonstrates the correct shock position: lying flat with legs elevated, keeping warm. Educational first aid photography. No text."),

("trauma_cabeza_columna", "1536x1024",
"Photorealistic scene of spinal injury management after a motorcycle accident on a rural road. A person lies motionless on the ground. A rescuer kneels behind their head, holding the head and neck stable in a neutral position with both hands, preventing any movement. A second person is calling emergency services on a phone. The motorcycle lies on its side nearby. The image clearly demonstrates the critical importance of keeping the head and neck still after a potential spinal injury. Photojournalistic style, natural outdoor lighting. No text."),

("triaje_multivictima", "1536x1024",
"Photorealistic scene of mass casualty triage at an accident site. Several injured people are on the ground in an outdoor area. Colored triage tags are visible: a red tag on a person being treated urgently, a yellow tag on a person sitting with an injured arm, a green tag on a person walking with minor cuts, and a black tag on a deceased person covered with a blanket. A first responder with a vest moves between patients with a clipboard. The image clearly demonstrates the START triage system and priority categories. Disaster response photography style. No text."),
]

def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    total = len(GUIDES)
    done = 0
    failed = []
    for i, (name, size, prompt) in enumerate(GUIDES, 1):
        out_path = os.path.join(OUT_DIR, f"{name}.png")
        if os.path.exists(out_path) and os.path.getsize(out_path) > 100000:
            print(f"[{i}/{total}] SKIP {name} (already exists)")
            done += 1
            continue
        print(f"[{i}/{total}] Generating {name} ({size})...", flush=True)
        t0 = time.time()
        try:
            result = subprocess.run(
                [VENV, SCRIPT, prompt, out_path, size, "high"],
                capture_output=True, text=True, timeout=300
            )
            elapsed = time.time() - t0
            if result.returncode == 0:
                size_bytes = os.path.getsize(out_path) if os.path.exists(out_path) else 0
                print(f"  OK {name} ({size_bytes:,} bytes, {elapsed:.0f}s)")
                done += 1
            else:
                print(f"  FAIL {name}: {result.stderr.strip()[:200]}")
                failed.append(name)
        except subprocess.TimeoutExpired:
            print(f"  TIMEOUT {name} (>300s)")
            failed.append(name)
        except Exception as e:
            print(f"  ERROR {name}: {e}")
            failed.append(name)
    print(f"\nDone: {done}/{total} succeeded, {len(failed)} failed")
    if failed:
        print(f"Failed: {', '.join(failed)}")

if __name__ == "__main__":
    main()
