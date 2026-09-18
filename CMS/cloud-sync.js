/* ============================================================
   NAVI Crewing System — Supabase cloud storage layer.

   The app reads and writes through `navStore` (same getItem/setItem/removeItem
   calls it used on localStorage). Before the app starts, NaviCloud.boot() loads
   every record and file from Supabase into memory; after that, every change the
   app saves is pushed to Supabase in the background.

   Where things go:
     crew / documents / vessels / log  -> table  navi_records  (one row per record)
     crew control number counter       -> table  navi_settings
     photos, document files, certs, logo -> Storage bucket  navi-files
   ============================================================ */
(function(){
  const COLLECTIONS = {
    navi_crew_v1: "crew",
    navi_docs_v1: "documents",
    navi_log_v1: "log",
    navi_vessels_v1: "vessels",
  };
  const SETTING_KEYS = ["navi_ccn_counter_v1", "navi_crp_doc_v1"];
  const COUNTER_KEY = "navi_ccn_counter_v1";
  const FILE_PREFIXES = {
    "navi_crewphoto:": "crew-photos/",
    "navi_docfile:": "documents/",
    "navi_vesselcert:": "vessel-certs/",
  };
  const LOGO_KEY = "navi_logo_v1", LOGO_PATH = "logo/company-logo";
  const BUCKET = "navi-files";
  const MIGRATED_FLAG = "navi_cloud_migrated_v1";
  const INIT_PREFIX = "initialized:";

  const mem = {};          // key -> string|null : the app's working copy
  const synced = {};       // collection key -> Map(id -> signature) last confirmed in Supabase
  const initialized = {};  // collection key -> true once Supabase holds that collection
  let db = null, userId = null;

  /* ---------- small helpers ---------- */
  function lsGet(k){ try{ return localStorage.getItem(k); }catch(e){ return null; } }
  function lsSet(k, v){ try{ localStorage.setItem(k, v); }catch(e){} }
  function parseArr(s){ try{ const v = JSON.parse(s); return Array.isArray(v) ? v : null; }catch(e){ return null; } }
  function chunks(arr, n){ const out = []; for(let i = 0; i < arr.length; i += n) out.push(arr.slice(i, i + n)); return out; }
  function hash(str){ let h = 5381; for(let i = 0; i < str.length; i++) h = ((h << 5) + h + str.charCodeAt(i)) | 0; return (h >>> 0).toString(36); }
  function recordId(item, json){ return item && item.id != null && item.id !== "" ? String(item.id) : "h-" + hash(json); }
  function isFileKey(k){ return k === LOGO_KEY || Object.keys(FILE_PREFIXES).some(p => k.startsWith(p)); }
  function filePath(k){
    if(k === LOGO_KEY) return LOGO_PATH;
    for(const p in FILE_PREFIXES) if(k.startsWith(p)) return FILE_PREFIXES[p] + encodeURIComponent(k.slice(p.length));
    return null;
  }
  function isSyncedKey(k){ return k in COLLECTIONS || SETTING_KEYS.includes(k) || isFileKey(k); }
  function dataUrlToBlob(dataUrl){
    const s = String(dataUrl || "");
    const comma = s.indexOf(",");
    if(!s.startsWith("data:") || comma < 0) return new Blob([s], {type: "text/plain"});
    const meta = s.slice(5, comma).split(";");
    const type = meta[0] || "application/octet-stream";
    const body = s.slice(comma + 1);
    if(!meta.includes("base64")) return new Blob([decodeURIComponent(body)], {type});
    const bin = atob(body); const bytes = new Uint8Array(bin.length);
    for(let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
    return new Blob([bytes], {type});
  }
  function blobToDataUrl(blob){
    return new Promise((resolve, reject) => {
      const r = new FileReader();
      r.onload = () => resolve(r.result);
      r.onerror = () => reject(r.error);
      r.readAsDataURL(blob);
    });
  }
  async function runLimited(tasks, limit){
    let i = 0;
    const workers = Array.from({length: Math.min(limit, tasks.length)}, async () => {
      while(i < tasks.length){ const t = tasks[i++]; await t(); }
    });
    await Promise.all(workers);
  }

  /* ---------- save status shown in the header ---------- */
  let statusState = "saved";
  function setStatus(state, detail){
    statusState = state;
    const el = document.getElementById("cloudStatus");
    if(!el) return;
    const map = {
      saved:  ["Saved to database", "#5FD08A"],
      saving: ["Saving…", "#F2C14E"],
      error:  ["Not saved — retrying", "#FF7A66"],
    };
    const [text, color] = map[state];
    el.innerHTML = '<span class="dot"></span><span></span>';
    el.firstChild.style.background = color;
    el.lastChild.textContent = text;
    el.title = detail || "";
  }

  /* ---------- pushing changes to Supabase ---------- */
  const pending = new Set(), failed = new Set();
  let running = false, retryTimer = null;

  function queue(k){
    if(!db || !isSyncedKey(k)) return;
    pending.add(k);
    setStatus("saving");
    if(!running) drain();
  }
  async function drain(){
    running = true;
    let lastErr = null;
    while(pending.size){
      const k = pending.values().next().value;
      pending.delete(k);
      try{ await push(k); failed.delete(k); }
      catch(e){ console.error("Cloud save failed for", k, e); failed.add(k); lastErr = e; }
    }
    running = false;
    if(failed.size){
      setStatus("error", lastErr && lastErr.message);
      clearTimeout(retryTimer);
      retryTimer = setTimeout(() => { const ks = [...failed]; failed.clear(); ks.forEach(queue); }, 5000);
    } else setStatus("saved");
  }

  async function push(k){
    if(k in COLLECTIONS) return pushCollection(k);
    if(SETTING_KEYS.includes(k)) return pushSetting(k, mem[k]);
    if(isFileKey(k)) return pushFile(k, mem[k]);
  }

  async function pushCollection(k){
    const coll = COLLECTIONS[k];
    const arr = parseArr(mem[k]) || [];
    const prev = synced[k] || new Map();
    const next = new Map();
    const rows = [];
    const now = new Date().toISOString();
    arr.forEach((item, i) => {
      const json = JSON.stringify(item);
      const id = recordId(item, json);
      if(next.has(id)) return; // duplicate id: keep the first one
      const sig = i + "|" + json;
      next.set(id, sig);
      if(prev.get(id) !== sig) rows.push({collection: coll, id, pos: i, data: item, updated_at: now, updated_by: userId});
    });
    const gone = [...prev.keys()].filter(id => !next.has(id));
    for(const part of chunks(rows, 200)){
      const {error} = await db.from("navi_records").upsert(part);
      if(error) throw error;
    }
    for(const part of chunks(gone, 100)){
      const {error} = await db.from("navi_records").delete().eq("collection", coll).in("id", part);
      if(error) throw error;
    }
    synced[k] = next;
    if(!initialized[k]){
      await pushSetting(INIT_PREFIX + coll, "1");
      initialized[k] = true;
    }
  }

  async function pushSetting(key, value){
    if(value == null){
      const {error} = await db.from("navi_settings").delete().eq("key", key);
      if(error) throw error;
      return;
    }
    const {error} = await db.from("navi_settings").upsert({key, value: String(value), updated_at: new Date().toISOString(), updated_by: userId});
    if(error) throw error;
  }

  async function pushFile(k, value, opts){
    const path = filePath(k);
    const store = db.storage.from(BUCKET);
    if(value == null){
      const {error} = await store.remove([path]);
      if(error) throw error;
      return;
    }
    const blob = dataUrlToBlob(value);
    const {error} = await store.upload(path, blob, {upsert: !(opts && opts.noOverwrite), contentType: blob.type});
    if(error){
      if(opts && opts.noOverwrite && /exist|duplicate/i.test(error.message || "")) return;
      throw error;
    }
  }

  /* ---------- loading from Supabase ---------- */
  async function fetchAllRecords(){
    const all = [];
    const page = 1000;
    for(let from = 0; ; from += page){
      const {data, error} = await db.from("navi_records").select("collection,id,pos,data").order("collection").order("pos").range(from, from + page - 1);
      if(error) throw error;
      all.push(...data);
      if(data.length < page) break;
    }
    return all;
  }
  async function fetchSettings(){
    const {data, error} = await db.from("navi_settings").select("key,value");
    if(error) throw error;
    const out = {};
    data.forEach(r => { out[r.key] = r.value; });
    return out;
  }
  async function downloadFile(k){
    const {data, error} = await db.storage.from(BUCKET).download(filePath(k));
    if(error || !data) return; // missing file: the app shows "no file" for it
    mem[k] = await blobToDataUrl(data);
  }

  /* One-time copy of whatever this browser saved locally before the cloud switch.
     Records already in Supabase win; only records Supabase doesn't have are added. */
  async function migrateLocal(grouped, settings){
    for(const k in COLLECTIONS){
      const coll = COLLECTIONS[k];
      const local = parseArr(lsGet(k));
      if(!local || !local.length) continue;
      const rows = grouped[coll];
      const have = new Set(rows.map(r => r.id));
      const now = new Date().toISOString();
      const add = [];
      local.forEach(item => {
        const id = recordId(item, JSON.stringify(item));
        if(have.has(id)) return;
        have.add(id);
        add.push({collection: coll, id, pos: rows.length + add.length, data: item, updated_at: now, updated_by: userId});
      });
      for(const part of chunks(add, 200)){
        const {error} = await db.from("navi_records").upsert(part);
        if(error) throw error;
      }
      rows.push(...add);
      await pushSetting(INIT_PREFIX + coll, "1");
      settings[INIT_PREFIX + coll] = "1";
    }

    const localCounter = parseInt(lsGet(COUNTER_KEY) || "0", 10) || 0;
    const cloudCounter = parseInt(settings[COUNTER_KEY] || "0", 10) || 0;
    if(localCounter > cloudCounter){
      await pushSetting(COUNTER_KEY, localCounter);
      settings[COUNTER_KEY] = String(localCounter);
    }

    const fileKeys = [];
    try{ for(let i = 0; i < localStorage.length; i++){ const k = localStorage.key(i); if(k && isFileKey(k)) fileKeys.push(k); } }catch(e){}
    await runLimited(fileKeys.map(k => () => pushFile(k, lsGet(k), {noOverwrite: true})), 4);

    lsSet(MIGRATED_FLAG, new Date().toISOString());
  }

  async function boot(client, user, onProgress){
    db = client; userId = user.id;
    const progress = onProgress || function(){};

    progress("Loading records…");
    const records = await fetchAllRecords();
    const settings = await fetchSettings();
    const grouped = {};
    Object.values(COLLECTIONS).forEach(c => { grouped[c] = []; });
    records.forEach(r => { if(grouped[r.collection]) grouped[r.collection].push(r); });

    if(!lsGet(MIGRATED_FLAG)){
      progress("Uploading data saved in this browser…");
      await migrateLocal(grouped, settings);
    }

    for(const k in COLLECTIONS){
      const coll = COLLECTIONS[k];
      const rows = grouped[coll].sort((a, b) => a.pos - b.pos);
      initialized[k] = !!settings[INIT_PREFIX + coll] || rows.length > 0;
      const snap = new Map();
      rows.forEach((r, i) => { snap.set(r.id, i + "|" + JSON.stringify(r.data)); });
      synced[k] = snap;
      // Leave uninitialized collections unset so the app seeds them (and saves the seed to Supabase).
      if(initialized[k]) mem[k] = JSON.stringify(rows.map(r => r.data));
    }

    // Counter: never go below the highest control number already issued.
    let counter = parseInt(settings[COUNTER_KEY] || "0", 10) || 0;
    (parseArr(mem.navi_crew_v1) || []).forEach(c => {
      const m = /^CCN-(\d+)$/.exec((c && c.crewControlNo) || "");
      if(m) counter = Math.max(counter, parseInt(m[1], 10));
    });
    mem[COUNTER_KEY] = String(counter);
    SETTING_KEYS.forEach(k => { if(k !== COUNTER_KEY && settings[k] != null) mem[k] = settings[k]; });

    progress("Loading photos and files…");
    const fileKeys = [LOGO_KEY];
    (parseArr(mem.navi_crew_v1) || []).forEach(c => { if(c && c.hasPhoto) fileKeys.push("navi_crewphoto:" + c.id); });
    (parseArr(mem.navi_docs_v1) || []).forEach(d => { if(d && d.hasFile) fileKeys.push("navi_docfile:" + d.id); });
    (parseArr(mem.navi_vessels_v1) || []).forEach(v => { if(v && v.hasCertFile) fileKeys.push("navi_vesselcert:" + v.id); });
    await runLimited(fileKeys.map(k => () => downloadFile(k)), 6);

    setStatus("saved");
  }

  /* ---------- what the app talks to ---------- */
  window.navStore = {
    getItem(k){ return k in mem ? mem[k] : null; },
    setItem(k, v){ mem[k] = String(v); queue(k); },
    removeItem(k){ mem[k] = null; queue(k); },
  };

  window.addEventListener("beforeunload", e => {
    if(running || pending.size || failed.size){ e.preventDefault(); e.returnValue = ""; }
  });

  window.NaviCloud = { boot, isBusy: () => running || pending.size > 0 || statusState !== "saved" };
})();
