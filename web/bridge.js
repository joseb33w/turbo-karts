// Serverless multiplayer bridge — Supabase Realtime *broadcast* transport.
// No game server: clients are peers on a public channel (friends-play,
// client-authoritative). GDScript talks to this via
// JavaScriptBridge.get_interface("gameNet"). See net.gd.
//
// The cloud agent MUST replace these two placeholders at build time with the
// session's Supabase project URL + anon (publishable) key:
const SUPABASE_URL = "https://xhhmxabftbyxrirvvihn.supabase.co";
const SUPABASE_ANON_KEY = "sb_publishable_NZHoIxqqpSvVBP8MrLHCYA_gmg1AbN-";

let _sb = null;
let _channel = null;
let _onMessage = null;

const _userId = "p_" + Math.random().toString(36).slice(2, 10);
const _name = (function () {
  const A = ["Swift", "Brave", "Sly", "Bright", "Bold", "Wild", "Sharp", "Quick"];
  const B = ["Fox", "Owl", "Hawk", "Bear", "Wolf", "Lynx", "Stag", "Hare"];
  const r = (a) => a[Math.floor(Math.random() * a.length)];
  return r(A) + r(B);
})();

function _emit(obj) {
  if (!_onMessage) return;
  try { _onMessage(JSON.stringify(obj)); }
  catch (e) { console.error("[gameNet] onMessage", e); }
}

window.gameNet = {
  setOnMessage(cb) { _onMessage = cb; },
  getUserId() { return _userId; },
  getName() { return _name; },

  // Join (or create) a room. Empty arg → use ?room= or generate one.
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
    if (!window.supabase || !window.supabase.createClient) {
      console.error("[gameNet] Supabase SDK missing - is the CDN <script> in head_include?");
      _emit({ t: "_error", reason: "supabase_missing" });
      return;
    }
    _sb = _sb || window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
    if (_channel) { try { _sb.removeChannel(_channel); } catch (e) {} }
    _channel = _sb.channel("game:" + room, { config: { broadcast: { self: false } } });
    _channel.on("broadcast", { event: "msg" }, (e) => _emit(e.payload));
    _channel.subscribe((status) => {
      if (status === "SUBSCRIBED") _emit({ t: "_connected", room: room, you: _userId });
      else if (status === "CHANNEL_ERROR" || status === "TIMED_OUT") _emit({ t: "_disconnected" });
    });
  },

  // Broadcast a JSON payload (string) to the other peers in the room.
  send(payloadJson) {
    if (!_channel) return;
    let payload;
    try { payload = JSON.parse(payloadJson); } catch (e) { return; }
    payload.from = _userId;
    _channel.send({ type: "broadcast", event: "msg", payload: payload });
  },
};
