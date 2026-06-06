-- Turbo Karts player economy: server-authoritative profile store.
-- The table is LOCKED DOWN (RLS on, no anon/authenticated grants). All access
-- goes through SECURITY DEFINER RPCs that validate a per-device secret token,
-- so coins / garage live in Postgres (never localStorage) and the economy
-- (prices, balances) is validated server-side. No PII; no auth required.

create table if not exists public."usr_nmexs7bytxq2_turbo_karts_profiles" (
  id uuid primary key default gen_random_uuid(),
  player_id text not null unique,
  secret text not null,
  name text not null default 'Racer',
  coins int not null default 0,
  owned_karts text not null default 'starter',
  selected_kart text not null default 'starter',
  best_laps jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public."usr_nmexs7bytxq2_turbo_karts_profiles" enable row level security;
revoke all on public."usr_nmexs7bytxq2_turbo_karts_profiles" from anon;
revoke all on public."usr_nmexs7bytxq2_turbo_karts_profiles" from authenticated;

-- ---------- login / create -------------------------------------------------
create or replace function public.usr_nmexs7bytxq2_tk_login(p_player_id text, p_secret text, p_name text default 'Racer')
returns json language plpgsql security definer set search_path = public as $$
declare r public."usr_nmexs7bytxq2_turbo_karts_profiles";
begin
  if p_player_id is null or length(p_player_id) < 6 or p_secret is null or length(p_secret) < 6 then
    return json_build_object('error','bad_request');
  end if;
  select * into r from public."usr_nmexs7bytxq2_turbo_karts_profiles" where player_id = p_player_id;
  if not found then
    insert into public."usr_nmexs7bytxq2_turbo_karts_profiles"(player_id, secret, name)
      values (p_player_id, p_secret, coalesce(nullif(p_name,''),'Racer'))
      returning * into r;
  else
    if r.secret <> p_secret then
      return json_build_object('error','bad_secret');
    end if;
    if p_name is not null and p_name <> '' and p_name <> r.name then
      update public."usr_nmexs7bytxq2_turbo_karts_profiles" set name = p_name, updated_at = now()
        where player_id = p_player_id returning * into r;
    end if;
  end if;
  return json_build_object('coins', r.coins, 'owned', r.owned_karts, 'selected', r.selected_kart, 'best_laps', r.best_laps, 'name', r.name);
end; $$;

-- ---------- bank coins + record best lap -----------------------------------
create or replace function public.usr_nmexs7bytxq2_tk_bank(p_player_id text, p_secret text, p_coins int, p_arena text, p_lap_ms int)
returns json language plpgsql security definer set search_path = public as $$
declare r public."usr_nmexs7bytxq2_turbo_karts_profiles"; add int; bl jsonb; cur int;
begin
  select * into r from public."usr_nmexs7bytxq2_turbo_karts_profiles" where player_id = p_player_id;
  if not found then return json_build_object('error','no_profile'); end if;
  if r.secret <> p_secret then return json_build_object('error','bad_secret'); end if;
  add := greatest(0, least(coalesce(p_coins,0), 2000));
  bl := r.best_laps;
  if p_arena is not null and p_arena <> '' and p_lap_ms is not null and p_lap_ms > 0 then
    if not (bl ? p_arena) then
      bl := bl || jsonb_build_object(p_arena, p_lap_ms);
    else
      cur := (bl->>p_arena)::int;
      if p_lap_ms < cur then bl := bl || jsonb_build_object(p_arena, p_lap_ms); end if;
    end if;
  end if;
  update public."usr_nmexs7bytxq2_turbo_karts_profiles"
    set coins = coins + add, best_laps = bl, updated_at = now()
    where player_id = p_player_id returning * into r;
  return json_build_object('coins', r.coins, 'owned', r.owned_karts, 'selected', r.selected_kart, 'best_laps', r.best_laps, 'name', r.name);
end; $$;

-- ---------- buy (server-priced) --------------------------------------------
create or replace function public.usr_nmexs7bytxq2_tk_buy(p_player_id text, p_secret text, p_kart_id text)
returns json language plpgsql security definer set search_path = public as $$
declare r public."usr_nmexs7bytxq2_turbo_karts_profiles"; price int; owned text[];
begin
  select * into r from public."usr_nmexs7bytxq2_turbo_karts_profiles" where player_id = p_player_id;
  if not found then return json_build_object('error','no_profile'); end if;
  if r.secret <> p_secret then return json_build_object('error','bad_secret'); end if;
  price := case p_kart_id
    when 'starter'   then 0
    when 'speedster' then 800
    when 'drifter'   then 1200
    when 'heavy'     then 1600
    when 'gt'        then 3200
    when 'ace'       then 6500
    else -1 end;
  if price < 0 then return json_build_object('error','unknown_kart'); end if;
  owned := string_to_array(r.owned_karts, ',');
  if p_kart_id = any(owned) then
    update public."usr_nmexs7bytxq2_turbo_karts_profiles" set selected_kart = p_kart_id, updated_at = now()
      where player_id = p_player_id returning * into r;
    return json_build_object('coins', r.coins, 'owned', r.owned_karts, 'selected', r.selected_kart, 'best_laps', r.best_laps, 'name', r.name);
  end if;
  if r.coins < price then return json_build_object('error','insufficient','coins',r.coins,'price',price); end if;
  update public."usr_nmexs7bytxq2_turbo_karts_profiles"
    set coins = coins - price, owned_karts = r.owned_karts || ',' || p_kart_id, selected_kart = p_kart_id, updated_at = now()
    where player_id = p_player_id returning * into r;
  return json_build_object('coins', r.coins, 'owned', r.owned_karts, 'selected', r.selected_kart, 'best_laps', r.best_laps, 'name', r.name);
end; $$;

-- ---------- select an owned kart -------------------------------------------
create or replace function public.usr_nmexs7bytxq2_tk_select(p_player_id text, p_secret text, p_kart_id text)
returns json language plpgsql security definer set search_path = public as $$
declare r public."usr_nmexs7bytxq2_turbo_karts_profiles"; owned text[];
begin
  select * into r from public."usr_nmexs7bytxq2_turbo_karts_profiles" where player_id = p_player_id;
  if not found then return json_build_object('error','no_profile'); end if;
  if r.secret <> p_secret then return json_build_object('error','bad_secret'); end if;
  owned := string_to_array(r.owned_karts, ',');
  if not (p_kart_id = any(owned)) then return json_build_object('error','not_owned'); end if;
  update public."usr_nmexs7bytxq2_turbo_karts_profiles" set selected_kart = p_kart_id, updated_at = now()
    where player_id = p_player_id returning * into r;
  return json_build_object('coins', r.coins, 'owned', r.owned_karts, 'selected', r.selected_kart, 'best_laps', r.best_laps, 'name', r.name);
end; $$;

grant execute on function public.usr_nmexs7bytxq2_tk_login(text,text,text)  to anon, authenticated;
grant execute on function public.usr_nmexs7bytxq2_tk_bank(text,text,int,text,int) to anon, authenticated;
grant execute on function public.usr_nmexs7bytxq2_tk_buy(text,text,text)    to anon, authenticated;
grant execute on function public.usr_nmexs7bytxq2_tk_select(text,text,text) to anon, authenticated;
