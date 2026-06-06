# Goal
Round 3 of **Turbo Karts**. Three asks from the player:
1. **AI / CPU opponents** so single player is a real race (today you're always "1st of 1").
2. **Real mobile controls** — the old on-screen buttons used Godot `Button` nodes, which
   only ever receive the *single* emulated mouse pointer, so a phone player could never
   hold steer **and** drift at the same time. Replace with a true **multitouch** pad.
3. **Less robotic, better art + sound** — procedural textures (asphalt with lane lines,
   grass, sand, water, lit windows), shadows + MSAA, richer kart models with rolling
   wheels, glassier item/coin art, plus a fuller engine, looping music, and new SFX.

# Backend
No backend change. The existing server-authoritative Supabase economy (wallet/garage RPCs
in `supabase/migrations/`) is untouched; AI/visuals/audio are all client-side.

# Files to touch
- `scripts/ai_kart.gd` (new) — CPU racer: rail-follows the centerline with lane changes +
  rubber-banding, ranked by `prog`, spun by the player's shells/bananas.
- `scripts/textures.gd` (new) — runtime procedural textures (no binary assets).
- `scripts/touch_controls.gd` (new) — multitouch driving pad (raw `InputEventScreenTouch`
  by finger index + mouse fallback), correct under `canvas_items` stretch.
- `scripts/game.gd` — spawn 5 AI, fold them into position/leaderboard/entry count, let
  shells + bananas hit them, finish confetti + fanfare, start music.
- `scripts/kart.gd` — roll the wheels; keep handling.
- `scripts/kart_build.gd` — richer kart (side pods, splitter, windshield, driver, exhaust,
  hubcaps, metallic sheen, accent trim).
- `scripts/track.gd` — textured road (UV lane lines) + ground + water, sun shadows, drifting
  clouds, start/finish gantry, nicer trees/buildings.
- `scripts/items.gd` — glassy item box, metallic coin, better banana + shell.
- `scripts/hud.gd` — swap Button touch controls for the multitouch pad; hide it on finish.
- `scripts/audio.gd` — fuller engine, seamless looping music, lap + finish SFX, drift screech.
- `scripts/arenas.gd` — per-arena ground texture + tint + shadow flags.
- `project.godot` — 2x MSAA, keep gl_compatibility / nothreads.
- `README.md` — document opponents, mobile controls, the new art/sound.

# Verification approach
- `godot --headless --import` clean (typed against the 4.6 INFERENCE_ON_VARIANT rule).
- Export `nothreads` release; run the vetted smoke verifier (engine boots, canvas, clean
  console, frames); read the saved frames to confirm karts, textures, HUD, touch pad.
- Drive the multitouch pad in the headless browser (two simultaneous pointers) to confirm
  steer + drift register together.
- Deploy `out/` to R2 for the preview link.

# Out of scope
- Syncing AI across multiplayer peers — AI are single-player/local (MP stays casual,
  client-authoritative, as before).
- Imported art/audio assets — everything stays procedural to keep the .pck tiny.
