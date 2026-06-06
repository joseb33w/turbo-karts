// Supabase bridge for the Godot WASM build. Two interfaces on `window`, both
// talking to one shared Supabase client (anon key — safe in a web build):
//   • gameNet     — serverless multiplayer over Realtime *broadcast* (see net.gd)
//   • gameProfile — persistent wallet/garage via server-authoritative RPCs (profile.gd)
// GDScript reaches these via JavaScriptBridge.get_interface(...).
//
// The cloud agent fills these two placeholders with the session's Supabase project
// URL + anon (publishable) key at build time:
const SUPABASE_URL = "https://xhhmxabftbyxrirvvihn.supabase.co";
const SUPABASE_ANON_KEY = "sb_publishable_NZHoIxqqpSvVBP8MrLHCYA_gmg1AbN-";

// Server-authoritative profile RPCs (defined in schema.sql).
const RPC_LOGIN = "usr_nmexs7bytxq2_tk_login";
const RPC_BANK = "usr_nmexs7bytxq2_tk_bank";
const RPC_BUY = "usr_nmexs7bytxq2_tk_buy";
const RPC_SELECT = "usr_nmexs7bytxq2_tk_select";

let _sb = null;

function _client() {
  if (_sb) return _sb;
  if (!window.supabase || !window.supabase.createClient) {
    console.error("[bridge] Supabase SDK missing - is the CDN <script> in head_include?");
    return null;
  }
  _sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  return _sb;
}

function _store(k, v) { try { localStorage.setItem(k, v); } catch (e) {} }
function _load(k) { try { return localStorage.getItem(k); } catch (e) { return null; } }
function _rand(n) {
  const c = "abcdefghijklmnopqrstuvwxyz0123456789";
  let s = "";
  for (let i = 0; i < n; i++) s += c[Math.floor(Math.random() * c.length)];
  return s;
}
function _genName() {
  const A = ["Swift", "Brave", "Sly", "Bright", "Bold", "Wild", "Sharp", "Quick"];
  const B = ["Fox", "Owl", "Hawk", "Bear", "Wolf", "Lynx", "Stag", "Hare"];
  const r = (a) => a[Math.floor(Math.random() * a.length)];
  return r(A) + r(B);
}

// ---------------------------------------------------------------- multiplayer
let _channel = null;
let _onMessage = null;
const _userId = "p_" + _rand(8);

function _emitNet(obj) {
  if (!_onMessage) return;
  try { _onMessage(JSON.stringify(obj)); } catch (e) { console.error("[gameNet] onMessage", e); }
}

window.gameNet = {
  setOnMessage(cb) { _onMessage = cb; },
  getUserId() { return _userId; },
  getName() { return _load("tk_name") || _genName(); },

  connectRoom(room) {
    if (!room) {
      const u = new URLSearchParams(location.search);
      room = u.get("room");
      if (!room) {
        const c = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
        room = Array.from({ length: 5 }, () => c[Math.floor(Math.random() * c.length)]).join("");
        u.set("room", room);
        history.replaceState(null, "", "?" + u.toString());
      }
    }
    const sb = _client();
    if (!sb) { _emitNet({ t: "_error", reason: "supabase_missing" }); return; }
    if (_channel) { try { sb.removeChannel(_channel); } catch (e) {} }
    _channel = sb.channel("game:" + room, { config: { broadcast: { self: false } } });
    _channel.on("broadcast", { event: "msg" }, (e) => _emitNet(e.payload));
    _channel.subscribe((status) => {
      if (status === "SUBSCRIBED") _emitNet({ t: "_connected", room: room, you: _userId });
      else if (status === "CHANNEL_ERROR" || status === "TIMED_OUT") _emitNet({ t: "_disconnected" });
    });
  },

  send(payloadJson) {
    if (!_channel) return;
    let payload;
    try { payload = JSON.parse(payloadJson); } catch (e) { return; }
    payload.from = _userId;
    _channel.send({ type: "broadcast", event: "msg", payload: payload });
  },
};

// ---------------------------------------------------------------- profile
let _profCb = null;
let _pid = null, _secret = null, _pname = null;

function _emitProf(obj) {
  if (!_profCb) return;
  try { _profCb(JSON.stringify(obj)); } catch (e) { console.error("[gameProfile] cb", e); }
}

function _ensureCreds() {
  _pid = _load("tk_pid");
  _secret = _load("tk_secret");
  _pname = _load("tk_name");
  if (!_pid || _pid.length < 6) { _pid = "tkp_" + _rand(14); _store("tk_pid", _pid); }
  if (!_secret || _secret.length < 6) { _secret = "s_" + _rand(28); _store("tk_secret", _secret); }
  if (!_pname) { _pname = _genName(); _store("tk_name", _pname); }
}

async function _rpc(name, params) {
  const c = _client();
  if (!c) { _emitProf({ t: "profile", error: "sdk_missing" }); return; }
  try {
    const { data, error } = await c.rpc(name, params);
    if (error) { _emitProf({ t: "profile", error: error.message || "rpc_error" }); return; }
    if (data && data.error) { _emitProf({ t: "profile", error: data.error }); return; }
    _emitProf(Object.assign({ t: "profile" }, data || {}));
  } catch (e) {
    _emitProf({ t: "profile", error: String((e && e.message) || e) });
  }
}

window.gameProfile = {
  setCallback(cb) { _profCb = cb; },
  init() { _ensureCreds(); _rpc(RPC_LOGIN, { p_player_id: _pid, p_secret: _secret, p_name: _pname }); },
  bank(coins, arena, lapMs) {
    _ensureCreds();
    _rpc(RPC_BANK, { p_player_id: _pid, p_secret: _secret, p_coins: coins | 0, p_arena: String(arena || ""), p_lap_ms: lapMs | 0 });
  },
  buy(kartId) { _ensureCreds(); _rpc(RPC_BUY, { p_player_id: _pid, p_secret: _secret, p_kart_id: String(kartId) }); },
  select(kartId) { _ensureCreds(); _rpc(RPC_SELECT, { p_player_id: _pid, p_secret: _secret, p_kart_id: String(kartId) }); },
};
