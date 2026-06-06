# Goal
Round 2 of **Turbo Karts**. Build on the shipped Godot 4.6.3 web racer:
1. **Mobile default-browser playability** — verified to boot + play in a phone-sized
   viewport (portrait + landscape), big touch targets, safe-area margins, brake button.
2. **Better looks + better 3D UI** — a polished, themed menu/HUD/finish system with
   rounded glass panels, a 3D rotating-kart showroom backdrop, animated countdown,
   and per-arena skies/lighting.
3. **Multiple race arenas** the player can choose from (distinct track shapes, skies,
   ground, decor, fog/water, lap counts).
4. **Points economy + garage** — collected coins bank into a persistent wallet used to
   **buy faster vehicles**. Persistence is real (Supabase Postgres), not localStorage.

# Backend (Supabase — verified)
The shared project enforces email confirmation and disables anonymous sign-in, so a
client-side email/password flow would strand casual players at a "check your inbox"
wall (the forbidden round-trip). Instead the wallet/garage is a **server-authoritative
profile** keyed by a per-device token (player_id + secret in localStorage, like a
session token — the DATA lives in Postgres):
- Table `public."usr_nmexs7bytxq2_turbo_karts_profiles"` — RLS on, **no anon grants**.
- `SECURITY DEFINER` RPCs (granted to anon, secret-validated): `..._tk_login`,
  `..._tk_bank` (add coins + record best lap), `..._tk_buy` (server-priced), `..._tk_select`.
- Verified end-to-end with the anon key: create/persist, server-side pricing, insufficient
  funds rejected, wrong-secret rejected, direct table SELECT blocked.

# Files to touch
- `project.godot` — add `Profile` autoload.
- `scripts/arenas.gd` (new) — 4 arena specs (control points + theme).
- `scripts/garage.gd` (new) — kart catalog (stats multipliers, price, color, style).
- `scripts/profile.gd` (new, autoload) — wallet/garage state; talks to the bridge RPCs.
- `scripts/ui_theme.gd` (new) — shared polished UI styling helpers.
- `scripts/menu.gd` (new) — tap-to-start → main menu, garage, arena select, 3D showroom.
- `main.gd` — boot into the menu; race/menu transitions.
- `scripts/game.gd` — parameterized by arena + kart; bank coins on finish; exit-to-menu.
- `scripts/track.gd` — build from an arena spec (shape, sky, ground, decor, water, fog).
- `scripts/kart.gd` — apply per-kart stat multipliers.
- `scripts/kart_build.gd` — per-style kart models.
- `scripts/hud.gd` — polished HUD + finish screen + brake button + coins.
- `web/bridge.js` — add `window.gameProfile` (RPC client) alongside `gameNet`.
- `README.md`, `.env.example` (+ `.env`) — document the economy + table prefix.

# Verification approach
- `godot --headless --import` clean; export `nothreads` release; vetted smoke verifier.
- Playwright drive in mobile portrait + landscape viewports: tap-to-start → menu →
  arena select → garage (buy/select) → race → finish; multi-frame screenshots assert
  motion, steering, HUD, menu polish.
- Real Supabase RPC tests with the anon key (done): login/bank/buy/select + negatives.
- 2-client Supabase Realtime broadcast test (multiplayer sync).
- Deploy `out/` to R2 for the preview link.

# Out of scope
- Email/password accounts (infeasible: project forces email confirmation). Cross-device
  uses a transfer code instead.
- Server-authoritative race physics (multiplayer stays casual client-authoritative).
