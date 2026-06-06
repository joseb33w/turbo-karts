# Goal
Build **Turbo Karts** - a bright, cartoony, low-poly **3D Mario-Kart-style racer in
Godot 4.6.3**, exported to the web (single-threaded `nothreads`, Compatibility/WebGL2
renderer) so it runs in mobile + desktop Safari/Chrome/Firefox. Auto-accelerate
arcade handling: steer, **drift to charge a mini-turbo**, brake. Items from item
boxes (boost mushroom, banana, shell), coins for a speed bonus. 3-lap race with a
3-2-1-GO countdown, lap counter, lap timer + best lap, and a finish/placement screen.
Fall off -> respawn. **Live multiplayer over Supabase Realtime broadcast** with a room
code in the URL, remote karts with name tags, and a live position/leaderboard.

# Files to touch
- `project.godot` - Compatibility renderer, stretch, touch-mouse, `Net` autoload, input map (registered at runtime in `main.gd`).
- `export_presets.cfg` - `Web` preset, `thread_support=false`, head_include + Supabase SDK CDN + `bridge.js`.
- `main.gd` / `main.tscn` - input actions, tap-to-start (unlocks Web Audio), boots the Game.
- `scripts/track.gd` - closed Catmull-Rom circuit; road/kerb/checker meshes; sky + decor; ramps; on-road/surface probe; item-box/coin/shortcut placement.
- `scripts/kart.gd` - local kart physics, drift + mini-turbo, items, ramp launches, respawn, chase camera (tilts into turns), drift-spark / boost-trail particles, engine/boost/drift audio.
- `scripts/kart_build.gd` - code-built low-poly kart model (per-player colour).
- `scripts/remote_kart.gd` - interpolated peer kart + billboard name tag.
- `scripts/items.gd` - item box / coin / banana / shell meshes.
- `scripts/hud.gd` - lap/position/timer/best, item slot, coins, leaderboard, countdown, finish screen, touch controls.
- `scripts/audio.gd` - procedural (synthesized) engine/boost/drift/coin/item/hit/countdown sound.
- `net.gd` / `web/bridge.js` - Supabase Realtime broadcast transport (creds filled in).

# Verification approach
- `godot --headless --import` clean; headless run for `_ready`/`_process` errors.
- Export `nothreads` release; run the vetted smoke verifier (engine boots, canvas, console clean, frames).
- Custom Playwright drive: tap-to-start -> countdown -> confirm forward motion, steering, drift sparks, mini-turbo boost, coin pickup, camera tilt (multi-frame screenshots).
- Headless logic test of the lap state machine -> finish screen + placement + best lap.
- Real 2-client Supabase Realtime broadcast test (one peer sends -> other receives) with the live credentials.
- Deploy `out/` to R2 for the preview link.

# Out of scope
- No database tables: multiplayer uses Realtime *broadcast* (no persistence needed); best lap is local (localStorage).
- No accounts / auth (casual public room).
- Server-authoritative anti-cheat (casual client-authoritative; karts pass through each other by design).
