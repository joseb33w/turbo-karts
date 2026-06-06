# Turbo Karts 🏎️💨

A bright, cartoony, low-poly **3D kart racer** in the spirit of Mario Kart, built
in **Godot 4.6.3** and exported to the **web** (single-threaded `nothreads`,
Compatibility / WebGL2). It runs in mobile and desktop **Safari, Chrome, and
Firefox**, and supports **live multiplayer** in a shared room over Supabase
Realtime broadcast.

## Play
Open the exported game and **tap to start**. You auto-accelerate - you just steer,
drift, and use items.

- **Desktop:** Arrows / WASD to steer - **Space** or **Shift** to drift - **E** to use an item - Down / S to brake
- **Mobile:** on-screen steer buttons - **DRIFT** - **ITEM** (tap-to-start unlocks sound)

### How to race
- **Drift to boost:** hold drift through a turn to charge a **mini-turbo** (sparks go
  white -> orange -> blue); release to fire a speed burst. Bigger charge = longer boost.
- **Item boxes** (the floating `?` cubes) give a random power-up:
  - **Boost mushroom** - instant speed burst.
  - **Banana** - dropped behind you; anyone who hits it spins out.
  - **Shell** - fired forward; spins out the racer ahead.
- **Coins** scattered on the track give a small top-speed bonus each.
- **3 laps** with a 3-2-1-GO countdown, lap counter, live lap timer + **best lap**, and
  a finish screen showing your placement.
- Drive off the track into the water and you **respawn** back on the circuit.

## Multiplayer
Everyone who opens the **same room** races together live. The room code is in the
URL (`?room=ABCDE`): open a second tab or send a friend the link and you'll see each
other's karts with name tags and a live position/leaderboard. Casual racing - karts
pass through each other. Transport is **Supabase Realtime broadcast** (no game
server, no database) via `web/bridge.js`.

## Project layout
```
project.godot          Compatibility renderer, Net autoload, web settings
main.gd / main.tscn    input map, tap-to-start, boots the Game
net.gd                 Supabase Realtime client (talks to web/bridge.js)
web/bridge.js          JS bridge: Supabase Realtime broadcast transport
scripts/
  game.gd              race loop, countdown, laps/timer, items, coins, MP sync, HUD wiring
  track.gd             procedural circuit (curve + meshes), on-road probe, ramps, pickups
  kart.gd              local kart: handling, drift/mini-turbo, items, respawn, chase cam, VFX/audio
  kart_build.gd        low-poly kart model
  remote_kart.gd       interpolated peer kart + name tag
  items.gd             item box / coin / banana / shell meshes
  hud.gd               HUD + touch controls + countdown + finish screen
  audio.gd             procedural engine/boost/drift/SFX (no audio assets)
```

## Build it yourself
Requires **Godot 4.6.3** with the **web (nothreads)** export templates.
```bash
godot --headless --path . --import
godot --headless --path . --export-release "Web" out/index.html
cp web/bridge.js out/bridge.js   # bridge.js must sit next to index.html
# serve out/ over HTTPS (no COOP/COEP headers needed - this is a nothreads build)
```
The Supabase project URL + **anon (publishable)** key are filled into
`web/bridge.js`. The anon key is a public client key (safe to ship in a web build);
see `.env.example`.
