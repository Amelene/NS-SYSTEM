/* ============================================================
   NS FINANCE — Supabase cloud storage layer.

   The portal keeps working exactly as before: it holds everything in one
   object (DB) and calls save() after each change. This layer loads that
   object from Supabase before the portal starts, and after every save()
   pushes only what changed:

     each list (invoices, payrolls, employees, …) -> table fin_records, one row per record
     settings, counters, gf                        -> table fin_settings
     attached scans / images (data URLs)           -> Storage bucket fin-files

   Document counters are merged on the server so numbers only go up, and
   are refreshed from the server every 20 seconds.
   ============================================================ */
(function(){
  const KEY = "nsfinance_v1";
  const MIGRATED_FLAG = "nsfinance_cloud_migrated_v1";
  const BUCKET = "fin-files";
  const FILE_MARK = "sbfile:";
  const MIN_FILE_LEN = 4096;          // data URLs at least this long are stored as files
  const COUNTER_POLL_MS = 20000;

  let db = null, userId = null;
  let bootJson = null;
  let pendingMigrationFlag = false;
  const synced = {};                  // list name -> Map(id -> signature) last confirmed in Supabase
  const settingSig = {};              // setting key -> signature last confirmed
  const pathByData = new Map();       // data URL -> storage path
  const dataByPath = new Map();       // storage path -> data URL

  /* ---------- helpers ---------- */
  function lsGet(k){ try{ return localStorage.getItem(k); }catch(e){ return null; } }
  function lsSet(k, v){ try{ localStorage.setItem(k, v); }catch(e){} }
  function lsRemove(k){ try{ localStorage.removeItem(k); }catch(e){} }
  function chunks(arr, n){ const out = []; for(let i = 0; i < arr.length; i += n) out.push(arr.slice(i, i + n)); return out; }
  function hash(str){ let h = 5381; for(let i = 0; i < str.length; i++) h = ((h << 5) + h + str.charCodeAt(i)) | 0; return (h >>> 0).toString(36); }
  function recordId(item, json){ return item && item.id != null && item.id !== "" ? String(item.id) : "h-" + hash(json); }
  async function runLimited(tasks, limit){
    let i = 0;
    await Promise.all(Array.from({length: Math.min(limit, tasks.length)}, async () => {
      while(i < tasks.length){ const t = tasks[i++]; await t(); }
    }));
  }
  function dataUrlToBlob(dataUrl){
    const s = String(dataUrl || ""), comma = s.indexOf(",");
    const meta = s.slice(5, comma).split(";");
    const type = meta[0] || "application/octet-stream";
    const body = s.slice(comma + 1);
    if(!meta.includes("base64")) return new Blob([decodeURIComponent(body)], {type});
    const bin = atob(body), bytes = new Uint8Array(bin.length);
    for(let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
    return new Blob([bytes], {type});
  }
  function blobToDataUrl(blob){
    return new Promise((resolve, reject) => { const r = new FileReader(); r.onload = () => resolve(r.result); r.onerror = () => reject(r.error); r.readAsDataURL(blob); });
  }
  const EXT = {"application/pdf":"pdf","image/jpeg":"jpg","image/png":"png","image/webp":"webp","image/gif":"gif","image/svg+xml":"svg"};

  /* ---------- files: data URLs <-> Storage ---------- */
  function isInlineFile(v){ return typeof v === "string" && v.length >= MIN_FILE_LEN && v.startsWith("data:") && v.indexOf(",") > 0; }

  async function uploadData(dataUrl){
    const known = pathByData.get(dataUrl);
    if(known) return known;
    const blob = dataUrlToBlob(dataUrl);
    const digest = await crypto.subtle.digest("SHA-256", await blob.arrayBuffer());
    const hex = Array.from(new Uint8Array(digest)).map(b => b.toString(16).padStart(2, "0")).join("").slice(0, 40);
    const path = "files/" + hex + "." + (EXT[blob.type] || "bin");
    const {error} = await db.storage.from(BUCKET).upload(path, blob, {upsert: false, contentType: blob.type});
    if(error && !/exist|duplicate/i.test(error.message || "")) throw error;
    pathByData.set(dataUrl, path); dataByPath.set(path, dataUrl);
    return path;
  }
  // Copy of a value with every inline file replaced by a "sbfile:<path>" marker (uploading as needed).
  async function externalize(v){
    if(typeof v === "string") return isInlineFile(v) ? FILE_MARK + await uploadData(v) : v;
    if(Array.isArray(v)){ const out = []; for(const x of v) out.push(await externalize(x)); return out; }
    if(v && typeof v === "object"){ const out = {}; for(const k in v) out[k] = await externalize(v[k]); return out; }
    return v;
  }
  // Markers back to data URLs. A file that could not be downloaded keeps its marker, so saving never drops the reference.
  function internalize(v){
    if(typeof v === "string"){
      if(v.startsWith(FILE_MARK)){ const d = dataByPath.get(v.slice(FILE_MARK.length)); return d || v; }
      return v;
    }
    if(Array.isArray(v)) return v.map(internalize);
    if(v && typeof v === "object"){ const out = {}; for(const k in v) out[k] = internalize(v[k]); return out; }
    return v;
  }
  function collectPaths(v, set){
    if(typeof v === "string"){ if(v.startsWith(FILE_MARK)) set.add(v.slice(FILE_MARK.length)); return; }
    if(Array.isArray(v)){ v.forEach(x => collectPaths(x, set)); return; }
    if(v && typeof v === "object"){ for(const k in v) collectPaths(v[k], set); }
  }
  async function downloadPath(path){
    const {data, error} = await db.storage.from(BUCKET).download(path);
    if(error || !data) return;
    const url = await blobToDataUrl(data);
    dataByPath.set(path, url); pathByData.set(url, path);
  }

  /* ---------- save status in the portal header ---------- */
  let statusState = "saved";
  function setStatus(state, detail){
    statusState = state;
    const el = document.getElementById("cloudStatus");
    if(!el) return;
    const map = {saved:["Saved to database","#5FD08A"], saving:["Saving…","#F2C14E"], error:["Not saved — retrying","#FF7A66"]};
    const [text, color] = map[state];
    el.innerHTML = '<span class="dot"></span><span></span>';
    el.firstChild.style.background = color;
    el.lastChild.textContent = text;
    el.title = detail || "";
  }

  /* ---------- pushing changes ---------- */
  let timer = null, running = false, dirty = false, failed = false, retryTimer = null;

  function schedule(){
    if(!db) return;
    dirty = true;
    setStatus("saving");
    clearTimeout(timer);
    timer = setTimeout(drain, 700);
  }
  async function drain(){
    if(running) return;            // the running pass re-checks `dirty` when it finishes
    running = true;
    let lastErr = null;
    while(dirty){
      dirty = false;
      try{ await pushAll(); failed = false; }
      catch(e){ console.error("NS FINANCE cloud save failed", e); failed = true; lastErr = e; break; }
    }
    running = false;
    if(failed){
      setStatus("error", lastErr && lastErr.message);
      clearTimeout(retryTimer);
      retryTimer = setTimeout(schedule, 5000);
    } else {
      setStatus("saved");
      if(pendingMigrationFlag){ lsSet(MIGRATED_FLAG, new Date().toISOString()); pendingMigrationFlag = false; }
    }
  }

  async function pushAll(){
    const DB = window.DB;
    if(!DB || typeof DB !== "object") return;
    for(const key of Object.keys(DB)){
      const val = DB[key];
      if(Array.isArray(val)) await pushList(key, val);
      else if(key === "counters") await pushCounters(val);
      else await pushSetting(key, val);
    }
  }

  async function pushList(name, arr){
    const prev = synced[name] || new Map();
    const next = new Map();
    const changed = [];
    arr.forEach((item, i) => {
      const json = JSON.stringify(item);
      const id = recordId(item, json);
      if(next.has(id)) return;                     // duplicate id: keep the first
      const sig = i + "|" + json;
      next.set(id, sig);
      if(prev.get(id) !== sig) changed.push({id, pos: i, item});
    });
    const gone = [...prev.keys()].filter(id => !next.has(id));
    if(!changed.length && !gone.length){ synced[name] = next; return; }
    const now = new Date().toISOString();
    const rows = [];
    for(const c of changed) rows.push({collection: name, id: c.id, pos: c.pos, data: await externalize(c.item), updated_at: now, updated_by: userId});
    for(const part of chunks(rows, 100)){
      const {error} = await db.from("fin_records").upsert(part);
      if(error) throw error;
    }
    for(const part of chunks(gone, 100)){
      const {error} = await db.from("fin_records").delete().eq("collection", name).in("id", part);
      if(error) throw error;
    }
    synced[name] = next;
  }

  async function pushSetting(key, value){
    const sig = JSON.stringify(value === undefined ? null : value);
    if(settingSig[key] === sig) return;
    const {error} = await db.from("fin_settings").upsert({key, value: await externalize(value === undefined ? null : value), updated_at: new Date().toISOString(), updated_by: userId});
    if(error) throw error;
    settingSig[key] = sig;
  }

  function applyCounters(merged){
    const DB = window.DB;
    if(!DB || !merged || typeof merged !== "object") return;
    if(!DB.counters || typeof DB.counters !== "object") DB.counters = {};
    for(const k in merged){
      const n = Number(merged[k]);
      if(!isNaN(n) && !(Number(DB.counters[k]) >= n)) DB.counters[k] = n;
    }
  }
  async function pushCounters(counters){
    const sig = JSON.stringify(counters || {});
    if(settingSig.counters === sig) return;
    const {data, error} = await db.rpc("fin_merge_counters", {incoming: counters || {}});
    if(error) throw error;
    applyCounters(data);
    settingSig.counters = JSON.stringify(window.DB && window.DB.counters || {});
  }
  // Pick up numbers issued by other staff so the next document continues their series.
  async function pollCounters(){
    try{
      if(running || !window.DB) return;
      const {data, error} = await db.from("fin_settings").select("value").eq("key", "counters").maybeSingle();
      if(error || !data) return;
      const before = JSON.stringify(window.DB.counters || {});
      applyCounters(data.value);
      const after = JSON.stringify(window.DB.counters || {});
      if(before !== after && settingSig.counters === before) settingSig.counters = after;
    }catch(e){}
  }

  /* ---------- loading ---------- */
  async function fetchAllRecords(){
    const all = [], page = 1000;
    for(let from = 0; ; from += page){
      const {data, error} = await db.from("fin_records").select("collection,id,pos,data").order("collection").order("pos").range(from, from + page - 1);
      if(error) throw error;
      all.push(...data);
      if(data.length < page) break;
    }
    return all;
  }

  async function boot(client, user, progress){
    db = client; userId = user.id;
    progress = progress || function(){};

    progress("Checking access…");
    const {data: allowed, error: accErr} = await db.rpc("fin_is_staff");
    if(accErr) throw accErr;
    if(!allowed){ const e = new Error("NOT_STAFF"); e.code = "NOT_STAFF"; throw e; }

    progress("Loading records…");
    const records = await fetchAllRecords();
    const {data: settingRows, error: setErr} = await db.from("fin_settings").select("key,value");
    if(setErr) throw setErr;
    const cloudEmpty = !records.length && !settingRows.length;

    // What Supabase holds, grouped back into the portal's shape.
    const cloud = {};
    const lists = {};
    records.sort((a, b) => a.collection === b.collection ? a.pos - b.pos : 0);
    records.forEach(r => { (lists[r.collection] = lists[r.collection] || []).push(r); });
    for(const name in lists) cloud[name] = lists[name].map(r => r.data);
    settingRows.forEach(r => { cloud[r.key] = r.value; });

    progress("Loading attached files…");
    const paths = new Set(); collectPaths(cloud, paths);
    await runLimited([...paths].map(p => () => downloadPath(p)), 6);
    const cloudData = internalize(cloud);

    // Snapshot of what is already in Supabase, so only real changes are pushed later.
    for(const name in lists){
      const snap = new Map();
      cloudData[name].forEach((item, i) => { const json = JSON.stringify(item); snap.set(recordId(item, json), i + "|" + json); });
      synced[name] = snap;
    }
    settingRows.forEach(r => { settingSig[r.key] = JSON.stringify(cloudData[r.key] === undefined ? null : cloudData[r.key]); });

    // One-time: bring in what this browser saved before the switch to Supabase.
    let assembled = cloudEmpty ? null : cloudData;
    const localRaw = lsGet(KEY);
    if(localRaw && !lsGet(MIGRATED_FLAG)){
      let local = null;
      try{ local = JSON.parse(localRaw); }catch(e){}
      if(local && typeof local === "object"){
        progress("Uploading data saved in this browser…");
        if(!assembled){ assembled = local; }
        else {
          for(const key in local){
            const lv = local[key];
            if(Array.isArray(lv)){
              const cur = Array.isArray(assembled[key]) ? assembled[key] : (assembled[key] = []);
              const have = new Set(cur.map(x => recordId(x, JSON.stringify(x))));
              lv.forEach(x => { const id = recordId(x, JSON.stringify(x)); if(!have.has(id)){ have.add(id); cur.push(x); } });
            } else if(key === "counters" && lv && typeof lv === "object"){
              const c = assembled.counters && typeof assembled.counters === "object" ? assembled.counters : (assembled.counters = {});
              for(const k in lv){ if(!(Number(c[k]) >= Number(lv[k]))) c[k] = lv[k]; }
            } else if(!(key in assembled)){
              assembled[key] = lv;
            }
          }
        }
        pendingMigrationFlag = true;   // set once the first save to Supabase succeeds
      }
    } else if(!localRaw){
      lsSet(MIGRATED_FLAG, new Date().toISOString());
    }

    bootJson = assembled ? JSON.stringify(assembled) : null;
    setStatus(pendingMigrationFlag ? "saving" : "saved");
    setInterval(pollCounters, COUNTER_POLL_MS);
  }

  /* ---------- what the portal talks to (in place of localStorage) ---------- */
  window.finStore = {
    getItem(k){
      if(k === KEY) return window.DB ? JSON.stringify(window.DB) : bootJson;
      return lsGet(k);
    },
    setItem(k, v){ if(k === KEY) schedule(); else lsSet(k, v); },
    removeItem(k){ if(k === KEY) schedule(); else lsRemove(k); },
  };

  window.addEventListener("beforeunload", e => {
    if(running || dirty || failed){ e.preventDefault(); e.returnValue = ""; }
  });

  window.FinCloud = { boot, saveNow: schedule, isBusy: () => running || dirty || statusState !== "saved" };
})();
