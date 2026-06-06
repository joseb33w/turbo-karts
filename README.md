# Turbo Karts 🏎️💨

A bright, cartoony, low-poly **3D kart racer** in the spirit of Mario Kart, built in
**Godot 4.6.3** and exported to the **web** (single-threaded `nothreads`, Compatibility /
WebGL2). It runs in mobile and desktop **Safari, Chrome, and Firefox**, supports **live
multiplayer** over Supabase Realtime, and now has **multiple arenas**, a **3D garage**,
and a **persistent coin economy** for buying faster vehicles.

## Play
Open the game and **tap to start**, then you land on the menu:

- **RACE** — race the selected arena with the selected kart.
- **GARAGE** — browse vehicles, see their stats, and **buy** faster ones with coins.
- **ARENAS** — pick which track to race on.

You auto-accelerate — you just steer, drift, and use items.

- **Desktop:** Arrows / WASD to steer · **Space**/**Shift** to drift · **E** to use an item · Down/**S** to brake
- **Mobile:** on-screen steer (`<` `>`), **DRIFT**, **ITEM**, **BRK** buttons (the first tap unlocks sound)

### How to race
- **Drift → boost:** hold drift through a turn to charge a **mini-turbo** (sparks white →
  orange → blue); release for a speed burst. Different karts charge faster / boost longer.
- **Item boxes** (`?` cubes) give a random power-up — **boost mushroom**, **banana**
  (dropped behind you), **shell** (fired at the racer ahead).
- **Coins** on the track give a small top-speed bonus *and* bank into your wallet.
- Each arena is **2–3 laps** with a 3-2-1-GO countdown, lap counter, live lap timer +
  **best lap** (saved per arena), and a finish screen showing your placement.
- Drive off the track and you **respawn** back on the circuit.

## Arenas
Four hand-built circuits, each with its own shape, sky, lighting, ground, and decor:

| Arena | Vibe | Laps |
|------|------|------|
| **Azure Bay** | Sunny coastal loop over the water | 3 |
| **Emerald Forest** | Misty, winding woodland circuit | 3 |
| **Neon City** | Night circuit lit by glowing kerbs | 3 |
| **Sunset Dunes** | Wide, fast sweeps through warm desert sand | 2 |

## Coins & garage
Coins collected on the track plus a **placement bonus** are banked into your wallet at
the finish. Spend them in the **garage** on faster vehicles, each with its own
speed / acceleration / handling / drift profile:

`Sprout Cart` (free) → `Turbo Roadster` → `Drift King` → `Bruiser` → `Rocket GT` → `Phantom Ace`.

**Persistence (Supabase, server-authoritative).** The wallet + garage live in Postgres,
**not** localStorage. Each device gets a token (player_id + secret, stored locally like a
session token); all reads/writes go through `SECURITY DEFINER` RPCs that validate the
secret and **price purchases server-side** (so coins can't be faked client-side). The
profile table is locked down — no direct anon access. See `supabase/migrations/`.

> The shared Supabase project enforces email confirmation and disables anonymous
> sign-in, which would strand casual players at a "check your inbox" wall, so the game
> uses the device-token model above instead of email/password accounts.

## Multiplayer
Everyone who opens the **same room** races together live. The room + arena are in the URL
(`?room=ABCDE&arena=forest`): open a second tab or send a friend the link and you'll see
each other's karts with name tags and a live leaderboard. Casual racing — karts pass
through each other. Transport is **Supabase Realtime broadcast** (no game server) via
`web/bridge.js`.

## Project layout
```
project.godot          Compatibility renderer, Net + Profile autoloads, web settings
main.gd / main.tscn    input map, tap-to-start, menu ⇄ race flow
net.gd                 Supabase Realtime client (multiplayer)
web/bridge.js          JS bridge: Realtime broadcast (gameNet) + profile RPCs (gameProfile)
supabase/migrations/   profiles table + server-authoritative economy RPCs
scripts/
  arenas.gd            arena catalog (track shape + theme)
  garage.gd            vehicle catalog (stats, price, style)
  profile.gd           wallet/garage state (autoload), talks to the RPC bridge
  ui_theme.gd          shared polished UI styling
  menu.gd              3D showroom + main menu + garage + arena select
  game.gd              race loop, countdown, laps/timer, items, coins, MP sync, banking
  track.gd             procedural circuit from an arena spec; on-road probe; ramps; decor
  kart.gd              local kart handling (per-vehicle stats), drift, items, respawn, cam
  kart_build.gd        low-poly kart models (per style)
  remote_kart.gd       interpolated peer kart + name tag
  items.gd             item box / coin / banana / shell meshes
  hud.gd               HUD + touch controls + countdown + finish card
  audio.gd             procedural engine/boost/drift/SFX (no audio assets)
```

## Build it yourself
Requires **Godot 4.6.3** with the **web (nothreads)** export templates.
```bash
godot --headless --path . --import
godot --headless --path . --export-release "Web" out/index.html
cp web/bridge.js out/bridge.js   # bridge.js must sit next to index.html
# serve out/ over HTTPS (no COOP/COEP headers needed — this is a nothreads build)
```
The Supabase project URL + **anon (publishable)** key are filled into `web/bridge.js`
(the anon key is a public client key, safe to ship). See `.env.example`.
