// Koco community — Cloudflare Worker (project/community-api.md).
// C2a: sign in with Apple, sessions that can be ended at once, me, leaving,
// themes, banning. Bindings: DB (D1 koco-community), PHOTOS (R2 koco-photos).
// C2b: uploads into private R2, posting (approved before public: user 11/24),
// pages of a theme's posts, pictures through signed links, likes, reports,
// blocks, deleting a post.
// Secrets: PHOTO_KEY (signs picture links); later APPLE_TEAM_ID, APPLE_KEY_ID,
// APPLE_PRIVATE_KEY — for the authorization-code exchange and revoking
// Apple's grant on deletion.

const BUNDLE_ID = 'com.oneskill.cameragr';
const APPLE_ISSUER = 'https://appleid.apple.com';
const SESSION_DAYS = 30;
const MILESTONES = [[3, 'portra400'], [7, 'dusk200'], [14, 'ember400']];
const PHOTO_MAX = 1_500_000, THUMB_MAX = 200_000;   // bytes (1600 px / 400 px JPEGs)
const LINK_SECONDS = 3600;                          // a picture link lasts an hour
const QUICK_DELETE_MS = 3600_000;                   // deleted within an hour: no day (user 11/24)
// Words refused in captions (a first list; C6 grows it). Lower case.
const BLOCKED_WORDS = ['fuck', 'shit', 'nigger', 'faggot', 'cunt', '傻逼', '操你', '草泥马', '婊子', '死全家'];

export default {
  /// Hourly: Apple grants still to revoke are tried again, each removed once done.
  async scheduled(event, env) {
    await cleanUploads(env);
    await usageCheck(env);
    if (!hasAppleKey(env)) return;
    const { results } = await env.DB.prepare('SELECT refresh_token FROM pending_revocations LIMIT 50').all();
    for (const r of results) {
      if (await revokeApple(env, r.refresh_token).catch(() => false)) {
        await env.DB.prepare('DELETE FROM pending_revocations WHERE refresh_token = ?').bind(r.refresh_token).run();
      }
    }
  },
  async fetch(request, env) {
    try {
      return await route(request, env);
    } catch (e) {
      if (e instanceof HttpError) return json({ error: e.code }, e.status);
      console.error(e && e.stack || e);
      return json({ error: 'server' }, 500);
    }
  },
};

class HttpError extends Error {
  constructor(status, code) { super(code); this.status = status; this.code = code; }
}
const fail = (status, code) => { throw new HttpError(status, code); };

function json(body, status = 200) {
  return new Response(body === null ? null : JSON.stringify(body), {
    status, headers: { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' },
  });
}

async function route(request, env) {
  const url = new URL(request.url);
  const path = url.pathname, method = request.method;
  if (method === 'GET' && path === '/v1/health') return json({ ok: true });
  if (method === 'POST' && path === '/v1/auth/apple') return signInWithApple(request, env);
  if (method === 'GET' && path === '/v1/themes') return themes(url, env);
  const photo = path.match(/^\/v1\/photos\/([^/]+)\/(full|thumb)$/);
  if (method === 'GET' && photo) return servePhoto(url, env, photo[1], photo[2]);

  const me = await authenticate(request, env);
  if (method === 'GET' && path === '/v1/me') return json(await meView(env, me));
  if (method === 'POST' && path === '/v1/auth/signout') {
    await env.DB.prepare('DELETE FROM sessions WHERE token_hash = ?').bind(me.tokenHash).run();
    return json(null, 204);
  }
  if (method === 'DELETE' && path === '/v1/me') return leave(env, me);

  let m;
  if (method === 'POST' && path === '/v1/uploads') return newUpload(env, me);
  if (method === 'PUT' && (m = path.match(/^\/v1\/uploads\/([^/]+)\/(photo|thumb)$/))) return putUpload(request, env, me, m[1], m[2]);
  if (method === 'POST' && path === '/v1/posts') return createPost(request, env, me, url);
  if (method === 'GET' && (m = path.match(/^\/v1\/themes\/([^/]+)\/posts$/))) return themePosts(url, env, me, decodeURIComponent(m[1]));
  if ((m = path.match(/^\/v1\/posts\/([^/]+)$/))) {
    if (method === 'GET') return json(await postView(env, url, me, await visiblePost(env, me, m[1])));
    if (method === 'DELETE') return deletePost(env, me, m[1]);
  }
  if ((m = path.match(/^\/v1\/posts\/([^/]+)\/like$/)) && (method === 'PUT' || method === 'DELETE')) return like(env, me, m[1], method === 'PUT');
  if (method === 'POST' && (m = path.match(/^\/v1\/posts\/([^/]+)\/report$/))) return report(request, env, me, m[1]);
  if ((m = path.match(/^\/v1\/blocks\/([^/]+)$/)) && (method === 'PUT' || method === 'DELETE')) return block(env, me, m[1], method === 'PUT');
  // Moderation (C2c): admins only, checked here on the server; every step logged.
  if (path.startsWith('/v1/admin/')) {
    if (!me.is_admin) fail(403, 'not-admin');
    if (method === 'GET' && path === '/v1/admin/queue') return adminQueue(env, url, me);
    if (method === 'GET' && path === '/v1/admin/reports') return adminReports(env, url, me);
    if (method === 'GET' && path === '/v1/admin/log') return adminLog(env);
    if (method === 'GET' && path === '/v1/admin/hidden') {
      const { results } = await env.DB.prepare("SELECT * FROM posts WHERE state = 'hidden' ORDER BY created_at DESC LIMIT 60").all();
      return json(await Promise.all(results.map(p => postView(env, url, me, p))));
    }
    if (method === 'GET' && path === '/v1/admin/alerts') return json((await env.DB.prepare('SELECT * FROM alerts ORDER BY created_at DESC LIMIT 50').all()).results);
    if (method === 'POST' && (m = path.match(/^\/v1\/admin\/posts\/([^/]+)\/(approve|hide|restore)$/))) return moderate(env, m[1], m[2], me, await reasonOf(request));
    if (method === 'POST' && (m = path.match(/^\/v1\/admin\/users\/([^/]+)\/(ban|unban)$/))) return banUser(env, m[1], m[2] === 'ban', me, await reasonOf(request));
    if (method === 'POST' && (m = path.match(/^\/v1\/admin\/reports\/(\d+)\/handled$/))) {
      await env.DB.batch([env.DB.prepare('UPDATE reports SET handled = 1 WHERE id = ?').bind(Number(m[1])),
                          logStep(env, me, 'report-handled', 'report', m[1], null)]);
      return json(null, 204);
    }
  }
  fail(404, 'not-found');
}

// ---------------------------------------------------------------- utilities

const enc = new TextEncoder();
const nowISO = () => new Date().toISOString();

async function sha256hex(text) {
  const d = await crypto.subtle.digest('SHA-256', enc.encode(text));
  return [...new Uint8Array(d)].map(b => b.toString(16).padStart(2, '0')).join('');
}

function b64urlDecode(s) {
  s = s.replace(/-/g, '+').replace(/_/g, '/');
  while (s.length % 4) s += '=';
  return Uint8Array.from(atob(s), c => c.charCodeAt(0));
}

function randomToken() {
  const b = crypto.getRandomValues(new Uint8Array(32));
  return btoa(String.fromCharCode(...b)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

/// A day as YYYY-MM-DD in a time zone.
function dayIn(tz, date = new Date()) {
  try {
    return new Intl.DateTimeFormat('en-CA', { timeZone: tz, year: 'numeric', month: '2-digit', day: '2-digit' }).format(date);
  } catch { return date.toISOString().slice(0, 10); }
}
function dayBefore(day) {
  const d = new Date(day + 'T12:00:00Z'); d.setUTCDate(d.getUTCDate() - 1);
  return d.toISOString().slice(0, 10);
}

// ---------------------------------------------------- Sign in with Apple

let appleKeys = null, appleKeysAt = 0;
async function appleKey(kid) {
  // Apple rotates its keys: cached an hour, fetched again for an unknown kid.
  if (!appleKeys || Date.now() - appleKeysAt > 3600_000 || !appleKeys.find(k => k.kid === kid)) {
    const r = await fetch('https://appleid.apple.com/auth/keys');
    if (!r.ok) fail(503, 'apple-unavailable');
    appleKeys = (await r.json()).keys; appleKeysAt = Date.now();
  }
  const jwk = appleKeys.find(k => k.kid === kid);
  if (!jwk) fail(401, 'apple-key');
  return crypto.subtle.importKey('jwk', jwk, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['verify']);
}

/// Verifies an Apple identity token: signature, issuer, audience, time and
/// the nonce (the app sends its raw nonce; the token carries its SHA-256).
async function verifyAppleToken(token, rawNonce) {
  const parts = (token || '').split('.');
  if (parts.length !== 3) fail(401, 'token');
  let header, claims;
  try {
    header = JSON.parse(new TextDecoder().decode(b64urlDecode(parts[0])));
    claims = JSON.parse(new TextDecoder().decode(b64urlDecode(parts[1])));
  } catch { fail(401, 'token'); }
  if (header.alg !== 'RS256') fail(401, 'token');
  const key = await appleKey(header.kid);
  const ok = await crypto.subtle.verify('RSASSA-PKCS1-v1_5', key, b64urlDecode(parts[2]), enc.encode(parts[0] + '.' + parts[1]));
  if (!ok) fail(401, 'signature');
  const now = Math.floor(Date.now() / 1000);
  if (claims.iss !== APPLE_ISSUER) fail(401, 'issuer');
  if (claims.aud !== BUNDLE_ID) fail(401, 'audience');
  if (!(claims.exp > now - 60)) fail(401, 'expired');
  if (!(claims.iat < now + 300)) fail(401, 'issued');
  if (!rawNonce || claims.nonce !== await sha256hex(rawNonce)) fail(401, 'nonce');
  if (!claims.sub) fail(401, 'subject');
  return claims;
}

async function signInWithApple(request, env) {
  const body = await request.json().catch(() => ({}));
  const claims = await verifyAppleToken(body.identityToken, body.nonce);
  // A nonce is good once (replay): kept a day, then let go.
  try {
    await env.DB.prepare('INSERT INTO used_nonces (nonce, used_at) VALUES (?, ?)').bind(await sha256hex(body.nonce), nowISO()).run();
  } catch { fail(401, 'nonce-used'); }
  await env.DB.prepare("DELETE FROM used_nonces WHERE used_at < ?").bind(new Date(Date.now() - 86400_000).toISOString()).run();

  let user = await env.DB.prepare('SELECT * FROM users WHERE apple_sub = ?').bind(claims.sub).first();
  let isNew = false;
  if (!user) {
    isNew = true;
    const id = crypto.randomUUID();
    const name = (typeof body.name === 'string' && body.name.trim().slice(0, 30)) || 'Koco ' + id.slice(0, 4);
    const tz = request.headers.get('x-koco-tz') || 'UTC';
    await env.DB.prepare('INSERT INTO users (id, apple_sub, name, tz, created_at) VALUES (?, ?, ?, ?, ?)')
      .bind(id, claims.sub, name, safeTZ(tz), nowISO()).run();
    user = await env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(id).first();
  }
  if (user.banned) fail(403, 'banned');
  // The authorization code, exchanged for a refresh token kept to revoke the
  // grant when they leave (App Review 5.1.1(v)). Needs the Sign in with Apple key.
  // Once the key is set, no session without it (retry with a fresh code);
  // before that (development), sign-in goes on and leaving says no grant was kept.
  if (!user.apple_refresh && hasAppleKey(env)) {
    const refresh = body.authorizationCode ? await exchangeCode(env, body.authorizationCode).catch(() => null) : null;
    if (!refresh) fail(503, 'apple-code');
    await env.DB.prepare('UPDATE users SET apple_refresh = ? WHERE id = ?').bind(refresh, user.id).run();
    user.apple_refresh = refresh;
  }

  const token = randomToken();
  const expires = new Date(Date.now() + SESSION_DAYS * 86400_000).toISOString();
  await env.DB.prepare('INSERT INTO sessions (token_hash, user_id, expires_at, created_at) VALUES (?, ?, ?, ?)')
    .bind(await sha256hex(token), user.id, expires, nowISO()).run();
  return json({ token, isNew, user: await meView(env, user) });
}

function safeTZ(tz) {
  try { new Intl.DateTimeFormat('en', { timeZone: tz }); return tz; } catch { return 'UTC'; }
}

/// The signed-in person, from the bearer token; banned or ended sessions are refused at once.
async function authenticate(request, env) {
  const auth = request.headers.get('authorization') || '';
  const token = auth.startsWith('Bearer ') ? auth.slice(7) : '';
  if (!token) fail(401, 'signed-out');
  const hash = await sha256hex(token);
  const row = await env.DB.prepare(
    'SELECT u.*, s.expires_at FROM sessions s JOIN users u ON u.id = s.user_id WHERE s.token_hash = ?'
  ).bind(hash).first();
  if (!row || row.expires_at < nowISO()) fail(401, 'signed-out');
  if (row.banned) fail(403, 'banned');
  row.tokenHash = hash;
  return row;
}

// ------------------------------------------------------------------- me

async function streak(env, user, extraDay) {
  const { results } = await env.DB.prepare('SELECT day FROM checkins WHERE user_id = ? ORDER BY day DESC LIMIT 400').bind(user.id).all();
  const days = new Set(results.map(r => r.day));
  if (extraDay) days.add(extraDay);   // a day about to be written, counted with the rest
  let day = dayIn(user.tz);
  if (!days.has(day)) { day = dayBefore(day); if (!days.has(day)) return 0; }
  let n = 0;
  while (days.has(day)) { n++; day = dayBefore(day); }
  return n;
}

async function meView(env, user) {
  const rewards = (await env.DB.prepare('SELECT milestone, film_id, claimed_at FROM rewards WHERE user_id = ? ORDER BY milestone').bind(user.id).all()).results;
  const blocked = (await env.DB.prepare('SELECT blocked FROM blocks WHERE blocker = ?').bind(user.id).all()).results.map(r => r.blocked);
  return {
    profile: { id: user.id, name: user.name, tz: user.tz },
    streak: await streak(env, user),
    rewards: rewards.map(r => ({ milestone: r.milestone, filmId: r.film_id, claimedAt: r.claimed_at })),
    blocked,
    isAdmin: !!user.is_admin,
  };
}

/// Leaving: every row and every picture of theirs, and their sessions.
async function leave(env, me) {
  let cursor;
  do {
    const list = await env.PHOTOS.list({ prefix: me.id + '/', cursor });
    if (list.objects.length) await env.PHOTOS.delete(list.objects.map(o => o.key));
    cursor = list.truncated ? list.cursor : undefined;
  } while (cursor);
  // Apple's grant revoked; if Apple can't be reached (or the key isn't set
  // yet), kept to revoke later — never lost, never claimed done.
  let apple = 'no-grant-kept';   // signed in before the key was set: nothing to revoke here
  const steps = [];
  // Rewards claimed stay claimed for this Apple account, even after leaving
  // (user 11/24: no claiming again by rebuilding). Only a hash is kept.
  const claimed = (await env.DB.prepare('SELECT milestone FROM rewards WHERE user_id = ?').bind(me.id).all()).results;
  if (claimed.length) {
    const subHash = await sha256hex('koco-departed:' + me.apple_sub);
    for (const r of claimed) steps.push(env.DB.prepare('INSERT OR IGNORE INTO departed_rewards (sub_hash, milestone) VALUES (?, ?)').bind(subHash, r.milestone));
  }
  steps.push(env.DB.prepare('DELETE FROM users WHERE id = ?').bind(me.id));   // cascades
  if (me.apple_refresh) {
    const ok = hasAppleKey(env) && await revokeApple(env, me.apple_refresh).catch(() => false);
    apple = ok ? 'revoked' : 'pending';
    if (!ok) steps.push(env.DB.prepare('INSERT OR IGNORE INTO pending_revocations (refresh_token, created_at) VALUES (?, ?)').bind(me.apple_refresh, nowISO()));
  }
  await env.DB.batch(steps);
  return json({ deleted: true, appleGrant: apple }, 200);
}

// ------------------------------------------------- Apple: code and revoke

const hasAppleKey = env => !!(env.APPLE_TEAM_ID && env.APPLE_KEY_ID && env.APPLE_PRIVATE_KEY);

/// The client secret Apple asks for: an ES256 JWT signed with the Sign in with Apple key.
async function appleClientSecret(env) {
  const pem = env.APPLE_PRIVATE_KEY.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '');
  const key = await crypto.subtle.importKey('pkcs8', b64urlDecode(pem.replace(/\+/g, '-').replace(/\//g, '_')),
    { name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign']);
  const b64 = o => btoa(JSON.stringify(o)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  const now = Math.floor(Date.now() / 1000);
  const head = b64({ alg: 'ES256', kid: env.APPLE_KEY_ID });
  const body = b64({ iss: env.APPLE_TEAM_ID, iat: now, exp: now + 3000, aud: APPLE_ISSUER, sub: BUNDLE_ID });
  const sig = new Uint8Array(await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, key, enc.encode(head + '.' + body)));
  return head + '.' + body + '.' + btoa(String.fromCharCode(...sig)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

async function exchangeCode(env, code) {
  const form = new URLSearchParams({ client_id: BUNDLE_ID, client_secret: await appleClientSecret(env), code, grant_type: 'authorization_code' });
  const r = await fetch(APPLE_ISSUER + '/auth/token', { method: 'POST', body: form });
  if (!r.ok) return null;
  return (await r.json()).refresh_token || null;
}

async function revokeApple(env, refresh) {
  const form = new URLSearchParams({ client_id: BUNDLE_ID, client_secret: await appleClientSecret(env), token: refresh, token_type_hint: 'refresh_token' });
  const r = await fetch(APPLE_ISSUER + '/auth/revoke', { method: 'POST', body: form });
  return r.ok;
}

/// Banning hides all their posts and ends their sessions at once; unbanning
/// lets them sign in again (their posts stay hidden until restored one by one).
async function banUser(env, id, on, me, reason) {
  const u = await env.DB.prepare('SELECT id, is_admin FROM users WHERE id = ?').bind(id).first();
  if (!u) fail(404, 'not-found');
  if (on && (u.is_admin || id === me.id)) fail(409, 'admin');
  const steps = on ? [
    env.DB.prepare('UPDATE users SET banned = 1 WHERE id = ?').bind(id),
    env.DB.prepare("UPDATE posts SET state = 'hidden' WHERE author = ?").bind(id),
    env.DB.prepare('DELETE FROM sessions WHERE user_id = ?').bind(id),
  ] : [env.DB.prepare('UPDATE users SET banned = 0 WHERE id = ?').bind(id)];
  steps.push(logStep(env, me, on ? 'ban' : 'unban', 'user', id, reason));
  await env.DB.batch(steps);
  return json(null, 204);
}

// ------------------------------------------------------------- moderation

async function reasonOf(request) {
  const b = await request.json().catch(() => ({}));
  return typeof b.reason === 'string' ? b.reason.slice(0, 200) : null;
}

/// Every admin step, kept: who, what, on what, why, when.
/// The log row as a statement, to go in the same batch as the change it records.
function logStep(env, me, action, kind, target, reason) {
  return env.DB.prepare('INSERT INTO admin_log (admin, action, target_kind, target, reason, created_at) VALUES (?, ?, ?, ?, ?, ?)')
    .bind(me.id, action, kind, String(target), reason, nowISO());
}

/// Posts waiting for approval, oldest first (they wait least that way).
async function adminQueue(env, url, me) {
  const { results } = await env.DB.prepare("SELECT * FROM posts WHERE state = 'pending' ORDER BY created_at ASC LIMIT 60").all();
  return json(await Promise.all(results.map(p => postView(env, url, me, p))));
}

/// Open reports, newest first, each with its post (whatever its state).
async function adminReports(env, url, me) {
  const open = url.searchParams.get('state') !== 'all';
  const { results } = await env.DB.prepare(
    `SELECT r.*, u.name AS reporter_name FROM reports r JOIN users u ON u.id = r.reporter
     ${open ? 'WHERE r.handled = 0' : ''} ORDER BY r.created_at DESC LIMIT 100`).all();
  const out = [];
  for (const r of results) {
    const p = await env.DB.prepare('SELECT * FROM posts WHERE id = ?').bind(r.post_id).first();
    if (!p) continue;
    out.push({
      report: { id: r.id, reason: r.reason, note: r.note || undefined, reporter: { id: r.reporter, name: r.reporter_name },
                createdAt: r.created_at, handled: !!r.handled },
      post: await postView(env, url, me, p),
    });
  }
  return json(out);
}

async function adminLog(env) {
  const { results } = await env.DB.prepare(
    `SELECT l.*, u.name AS admin_name FROM admin_log l LEFT JOIN users u ON u.id = l.admin ORDER BY l.id DESC LIMIT 100`).all();
  return json(results.map(l => ({ id: l.id, admin: l.admin_name || l.admin, action: l.action, targetKind: l.target_kind,
                                   target: l.target, reason: l.reason || undefined, createdAt: l.created_at })));
}

/// A step only so many times in a window, per person (D1 counter rows).
async function rateLimit(env, me, what, max, seconds) {
  const window = Math.floor(Date.now() / 1000 / seconds);
  const key = `${what}:${me.id}:${window}`;
  const row = await env.DB.prepare(
    'INSERT INTO rate (key, n, expires_at) VALUES (?, 1, ?) ON CONFLICT(key) DO UPDATE SET n = n + 1 RETURNING n'
  ).bind(key, new Date((window + 1) * seconds * 1000).toISOString()).first();
  if (row.n > max) fail(429, 'slow-down');
}

/// Hourly: how much is used, against the free plan's room; an alert row
/// (once a day each) when something nears its limit, shown in admin mode.
async function usageCheck(env) {
  await env.DB.prepare('DELETE FROM rate WHERE expires_at < ?').bind(nowISO()).run();
  const day = nowISO().slice(0, 10);
  const posts = await env.DB.prepare('SELECT count(*) AS n FROM posts WHERE created_at >= ?').bind(day).first();
  const waiting = await env.DB.prepare("SELECT count(*) AS n, min(created_at) AS oldest FROM posts WHERE state = 'pending'").first();
  const open = await env.DB.prepare('SELECT count(*) AS n FROM reports WHERE handled = 0').first();
  const stored = await env.DB.prepare('SELECT count(*) AS n FROM posts').first();
  const checks = [
    // `text` holds the number; the app words it in the reader's language.
    ['posts-today', posts.n >= 500, String(posts.n)],
    ['queue', waiting.n >= 50 || (waiting.oldest && Date.now() - Date.parse(waiting.oldest) > 12 * 3600_000), String(waiting.n)],
    ['reports', open.n >= 10, String(open.n)],
    // A business-volume warning, not a byte meter: R2's free 10 GB is about
    // 5,000 posts at ~2 MB with room to spare (Cloudflare's own usage
    // notifications are the real meter, set in its dashboard).
    ['storage', stored.n >= 4000, String(stored.n)],
  ];
  for (const [kind, hit, text] of checks) {
    if (hit) await env.DB.prepare('INSERT OR IGNORE INTO alerts (kind, day, text, created_at) VALUES (?, ?, ?, ?)').bind(kind, day, text, nowISO()).run();
  }
}

// --------------------------------------------------------------- themes

async function themes(url, env) {
  const at = url.searchParams.get('at') || nowISO();
  const weekAgo = new Date(new Date(at).getTime() - 7 * 86400_000).toISOString();
  const { results } = await env.DB.prepare(
    'SELECT * FROM themes WHERE starts_at <= ? AND ends_at > ? ORDER BY starts_at DESC'
  ).bind(at, weekAgo).all();
  return json(results.map(t => ({
    id: t.id, kind: t.kind, startsAt: t.starts_at, endsAt: t.ends_at,
    title: JSON.parse(t.title), prompt: JSON.parse(t.prompt),
    suggestedFilm: t.suggested_film, limitedFilm: t.limited_film,
  })));
}

// ---------------------------------------------------------------- uploads

/// An upload: its two pictures go to private R2 under the person's own id.
async function newUpload(env, me) {
  const recent = await env.DB.prepare('SELECT count(*) AS n FROM uploads WHERE user_id = ? AND created_at > ?')
    .bind(me.id, new Date(Date.now() - 3600_000).toISOString()).first();
  if (recent.n >= 30) fail(429, 'slow-down');
  const id = crypto.randomUUID();
  await env.DB.prepare('INSERT INTO uploads (id, user_id, created_at) VALUES (?, ?, ?)').bind(id, me.id, nowISO()).run();
  return json({ uploadId: id });
}

async function putUpload(request, env, me, id, part) {
  const up = await env.DB.prepare('SELECT * FROM uploads WHERE id = ? AND user_id = ?').bind(id, me.id).first();
  if (!up) fail(404, 'upload');
  const max = part === 'photo' ? PHOTO_MAX : THUMB_MAX;
  const declared = Number(request.headers.get('content-length') || 0);
  if (declared > max) fail(413, 'too-big');
  const bytes = new Uint8Array(await request.arrayBuffer());
  if (bytes.length > max || bytes.length < 100) fail(413, 'too-big');
  // A real JPEG of the right size, read segment by segment (GPT review C2b).
  const size = jpegSize(bytes);
  if (!size) fail(415, 'not-jpeg');
  const long = part === 'photo' ? 1600 : 400;
  if (Math.max(size.w, size.h) > long || Math.min(size.w, size.h) < 16) fail(415, 'size');
  const key = `${me.id}/${id}/${part}.jpg`;
  await env.PHOTOS.put(key, bytes, { httpMetadata: { contentType: 'image/jpeg' } });
  await env.DB.prepare(`UPDATE uploads SET ${part === 'photo' ? 'photo_key' : 'thumb_key'} = ? WHERE id = ?`).bind(key, id).run();
  return json(null, 204);
}

/// A baseline or progressive JPEG's size, walking its segments from SOI to
/// the scan and checking it ends with EOI; null if it is not one.
function jpegSize(b) {
  if (b.length < 4 || b[0] !== 0xFF || b[1] !== 0xD8) return null;
  if (b[b.length - 2] !== 0xFF || b[b.length - 1] !== 0xD9) return null;
  let i = 2, size = null, dqt = false, dht = false;
  while (i + 4 <= b.length) {
    if (b[i] !== 0xFF) return null;
    const marker = b[i + 1];
    if (marker === 0xFF) { i++; continue; }                 // fill byte
    if (marker === 0xD8 || (marker >= 0xD0 && marker <= 0xD7)) return null;   // no SOI/RST here
    const len = (b[i + 2] << 8) | b[i + 3];
    if (len < 2 || i + 2 + len > b.length) return null;
    if (marker === 0xC0 || marker === 0xC1 || marker === 0xC2) {
      if (len < 8 || b[i + 4] !== 8) return null;            // 8-bit samples
      const h = (b[i + 5] << 8) | b[i + 6], w = (b[i + 7] << 8) | b[i + 8];
      const comps = b[i + 9];
      if (!w || !h || !(comps === 1 || comps === 3)) return null;
      size = { w, h };
    } else if (marker >= 0xC3 && marker <= 0xCF && marker !== 0xC4 && marker !== 0xC8 && marker !== 0xCC) {
      return null;                                           // lossless / arithmetic: not ours
    }
    if (marker === 0xDB) dqt = true;
    if (marker === 0xC4) dht = true;
    if (marker === 0xDA) {
      // A picture's coding tables, and enough coded data for its size (a
      // flat 16×16 grey still takes some): no decoder runs here without a
      // paid Cloudflare service, so the structure is what is checked.
      if (!size || !dqt || !dht) return null;
      const coded = b.length - (i + 2 + len) - 2;
      if (coded < Math.max(64, (size.w * size.h) / 2000)) return null;
      return size;
    }
    i += 2 + len;
  }
  return null;
}

/// Uploads never posted, after a day: rows and pictures go.
async function cleanUploads(env) {
  const old = (await env.DB.prepare('SELECT * FROM uploads WHERE created_at < ? LIMIT 100')
    .bind(new Date(Date.now() - 86400_000).toISOString()).all()).results;
  for (const u of old) {
    const keys = [u.photo_key, u.thumb_key].filter(Boolean);
    if (keys.length) await env.PHOTOS.delete(keys);
    await env.DB.prepare('DELETE FROM uploads WHERE id = ?').bind(u.id).run();
  }
}

// ------------------------------------------------------------------ posts

function badWords(text) {
  const t = (text || '').toLowerCase().replace(/\s+/g, '');
  return BLOCKED_WORDS.some(w => t.includes(w));
}

/// A post, once: the app's `clientId` makes a retry return the same post.
/// It waits for approval (shown to its author only) before it is public.
async function createPost(request, env, me, url) {
  const b = await request.json().catch(() => ({}));
  if (typeof b.clientId !== 'string' || !/^[A-Za-z0-9-]{8,64}$/.test(b.clientId)) fail(400, 'client-id');
  const again = await env.DB.prepare('SELECT * FROM posts WHERE author = ? AND client_id = ?').bind(me.id, b.clientId).first();
  if (again) return json(await postView(env, url, me, again));

  const theme = await env.DB.prepare('SELECT * FROM themes WHERE id = ?').bind(b.themeId || '').first();
  const now = nowISO();
  if (!theme || !(theme.starts_at <= now && now < theme.ends_at)) fail(409, 'theme-closed');
  const caption = typeof b.caption === 'string' ? b.caption.trim() : '';
  if ([...caption].length > 80 || badWords(caption)) fail(422, 'words');
  if (typeof b.filmId !== 'string' || !/^[a-z0-9]{2,32}$/.test(b.filmId)) fail(400, 'film');
  const up = await env.DB.prepare('SELECT * FROM uploads WHERE id = ? AND user_id = ?').bind(b.uploadId || '', me.id).first();
  if (!up || !up.photo_key || !up.thumb_key) fail(409, 'upload');
  const today = await env.DB.prepare("SELECT count(*) AS n FROM posts WHERE author = ? AND created_at > ?")
    .bind(me.id, new Date(Date.now() - 86400_000).toISOString()).first();
  if (today.n >= 20) fail(429, 'slow-down');

  const id = crypto.randomUUID();
  const takenAt = typeof b.takenAt === 'string' && !isNaN(Date.parse(b.takenAt)) ? new Date(b.takenAt).toISOString() : null;
  await env.DB.batch([
    env.DB.prepare(`INSERT INTO posts (id, author, theme_id, photo_key, thumb_key, film_id, caption, taken_at, created_at, state, client_id)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', ?)`)
      .bind(id, me.id, theme.id, up.photo_key, up.thumb_key, b.filmId, caption || null, takenAt, now, b.clientId),
    env.DB.prepare('DELETE FROM uploads WHERE id = ?').bind(up.id),
  ]);
  return json(await postView(env, url, me, await env.DB.prepare('SELECT * FROM posts WHERE id = ?').bind(id).first()), 201);
}

/// A post as one person may see it: public ones, and their own while waiting.
async function visiblePost(env, me, id) {
  const p = await env.DB.prepare('SELECT * FROM posts WHERE id = ?').bind(id).first();
  if (!p) fail(404, 'not-found');
  if (p.state === 'public' || p.author === me.id || me.is_admin) return p;
  fail(404, 'not-found');
}

async function postView(env, url, me, p) {
  const author = await env.DB.prepare('SELECT id, name FROM users WHERE id = ?').bind(p.author).first();
  const liked = await env.DB.prepare('SELECT 1 FROM likes WHERE post_id = ? AND user_id = ?').bind(p.id, me.id).first();
  return {
    id: p.id, author: { id: author.id, name: author.name }, themeId: p.theme_id,
    photoURL: await photoLink(env, url, p.id, 'full', me.is_admin), thumbURL: await photoLink(env, url, p.id, 'thumb', me.is_admin),
    filmId: p.film_id, caption: p.caption || undefined, takenAt: p.taken_at || undefined, createdAt: p.created_at,
    likeCount: p.like_count, likedByMe: !!liked, state: p.state,
  };
}

/// A theme's posts, newest first, a page at a time: public ones, without
/// those of people I blocked; my own waiting ones on the first page.
async function themePosts(url, env, me, themeId) {
  const limit = Math.min(Math.max(Number(url.searchParams.get('limit')) || 30, 1), 60);
  const cursor = url.searchParams.get('cursor');   // "<createdAt>|<id>" of the last one shown
  let [cAt, cId] = cursor ? cursor.split('|') : ['9999', ''];
  if (!cAt || cId === undefined) fail(400, 'cursor');
  const { results } = await env.DB.prepare(
    `SELECT p.* FROM posts p
     WHERE p.theme_id = ? AND (p.state = 'public' OR (p.state = 'pending' AND p.author = ?))
       AND p.author NOT IN (SELECT blocked FROM blocks WHERE blocker = ?)
       AND (p.created_at < ? OR (p.created_at = ? AND p.id < ?))
     ORDER BY p.created_at DESC, p.id DESC LIMIT ?`
  ).bind(themeId, me.id, me.id, cAt, cAt, cId || '￿', limit + 1).all();
  const page = results.slice(0, limit);
  const last = page[page.length - 1];
  return json({
    posts: await Promise.all(page.map(p => postView(env, url, me, p))),
    next: results.length > limit ? `${last.created_at}|${last.id}` : undefined,
  });
}

/// Deleting one's own post. A day already counted stays, unless the post
/// went within an hour of being posted (user 11/24) and nothing else of
/// theirs is public that day.
async function deletePost(env, me, id) {
  const p = await env.DB.prepare('SELECT * FROM posts WHERE id = ?').bind(id).first();
  if (!p || (p.author !== me.id && !me.is_admin)) fail(404, 'not-found');
  const steps = [env.DB.prepare('DELETE FROM posts WHERE id = ?').bind(id)];
  // The day was counted at approval; a post deleted within an hour of it
  // takes that day back, unless another of theirs was approved that day.
  // By approval time, whatever its state now: hiding it first changes nothing
  // (retro 7). Decided inside the same transaction as the delete, so two
  // quick deletes at once can't each keep the day for the other.
  if (p.approved_at && p.approved_day && Date.now() - Date.parse(p.approved_at) < QUICK_DELETE_MS) {
    steps.push(env.DB.prepare(
      'DELETE FROM checkins WHERE user_id = ? AND day = ? AND NOT EXISTS (SELECT 1 FROM posts WHERE author = ? AND approved_day = ?)'
    ).bind(p.author, p.approved_day, p.author, p.approved_day));
    steps.push(env.DB.prepare(
      'DELETE FROM eligibility WHERE user_id = ? AND reached_at >= ? AND NOT EXISTS (SELECT 1 FROM checkins WHERE user_id = ? AND day = ?)'
    ).bind(p.author, p.approved_at, p.author, p.approved_day));
  }
  await env.DB.batch(steps);
  await env.PHOTOS.delete([p.photo_key, p.thumb_key]);
  return json(null, 204);
}

/// Approving makes a waiting post public and counts the day it is approved
/// (in its author's own day: user 11/24); milestones reached are kept for good.
async function moderate(env, id, action, me, reason) {
  const p = await env.DB.prepare('SELECT * FROM posts WHERE id = ?').bind(id).first();
  if (!p) fail(404, 'not-found');
  const log = logStep(env, me, action, 'post', id, reason);
  if (action !== 'hide') {
    // A banned person's posts stay hidden until they are unbanned.
    const author = await env.DB.prepare('SELECT banned FROM users WHERE id = ?').bind(p.author).first();
    if (author && author.banned) fail(409, 'author-banned');
  }
  if (action === 'hide') {
    await env.DB.batch([env.DB.prepare("UPDATE posts SET state = 'hidden' WHERE id = ?").bind(id), log]);
    return json(null, 204);
  }
  // Its first time public is an approval, however it comes (approved, or
  // turned down and then restored): the day counts once, then never again.
  if (!p.approved_at && p.state !== 'public') {
    const at = nowISO();
    const author = await env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(p.author).first();
    const day = dayIn(author.tz, new Date(at));
    // Public, the day, and any milestone it reaches: one batch (a
    // transaction), so none is written without the others (retro 7). Two at
    // once: only the request whose update approved the post (its own `at`,
    // made unique) writes the day and milestones.
    const stamp = at + '#' + crypto.randomUUID().slice(0, 8);
    const n = await streak(env, author, day);
    const mine = 'SELECT 1 FROM posts WHERE id = ? AND approved_stamp = ?';
    await env.DB.batch([
      log,
      env.DB.prepare("UPDATE posts SET state = 'public', approved_at = ?, approved_day = ?, approved_stamp = ? WHERE id = ? AND approved_at IS NULL")
        .bind(at, day, stamp, id),
      env.DB.prepare(`INSERT OR IGNORE INTO checkins (user_id, day) SELECT ?, ? WHERE EXISTS (${mine})`).bind(author.id, day, id, stamp),
      ...MILESTONES.filter(([days]) => n >= days).map(([days]) =>
        env.DB.prepare(`INSERT OR IGNORE INTO eligibility (user_id, milestone, reached_at) SELECT ?, ?, ? WHERE EXISTS (${mine})`)
          .bind(author.id, days, at, id, stamp)),
    ]);
    return json(null, 204);
  }
  // Restoring a post approved before (or approving one again) only shows it.
  await env.DB.batch([env.DB.prepare("UPDATE posts SET state = 'public' WHERE id = ?").bind(id), log]);
  return json(null, 204);
}

async function like(env, me, id, on) {
  await rateLimit(env, me, 'like', 300, 3600);
  const p = await visiblePost(env, me, id);
  if (p.state !== 'public') fail(409, 'not-public');
  await env.DB.prepare(on ? 'INSERT OR IGNORE INTO likes (post_id, user_id, created_at) VALUES (?, ?, ?)' : 'DELETE FROM likes WHERE post_id = ? AND user_id = ?')
    .bind(...(on ? [id, me.id, nowISO()] : [id, me.id])).run();
  const row = await env.DB.prepare('SELECT like_count FROM posts WHERE id = ?').bind(id).first();
  return json({ likeCount: row.like_count, liked: on });
}

const REASONS = ['nudity', 'violence', 'hate', 'spam', 'not-koco', 'other'];
/// A report; three different people hide the post until someone looks.
async function report(request, env, me, id) {
  const b = await request.json().catch(() => ({}));
  if (!REASONS.includes(b.reason)) fail(400, 'reason');
  await rateLimit(env, me, 'report', 30, 86400);
  const note = typeof b.note === 'string' ? b.note.slice(0, 200) : null;
  await visiblePost(env, me, id);
  await env.DB.prepare('INSERT OR IGNORE INTO reports (post_id, reporter, reason, note, created_at) VALUES (?, ?, ?, ?, ?)')
    .bind(id, me.id, b.reason, note, nowISO()).run();
  // Each new report is an alert for the admins (email once a sending domain is set up).
  await env.DB.prepare('INSERT OR IGNORE INTO alerts (kind, day, text, created_at) VALUES (?, ?, ?, ?)')
    .bind('report:' + id + ':' + me.id, nowISO().slice(0, 10), b.reason, nowISO()).run();
  const n = await env.DB.prepare('SELECT count(*) AS n FROM reports WHERE post_id = ? AND handled = 0').bind(id).first();
  if (n.n >= 3) await env.DB.prepare("UPDATE posts SET state = 'hidden' WHERE id = ? AND state = 'public'").bind(id).run();
  return json(null, 204);
}

async function block(env, me, userId, on) {
  await rateLimit(env, me, 'block', 60, 86400);
  if (userId === me.id) fail(400, 'self');
  if (on) {
    const u = await env.DB.prepare('SELECT 1 FROM users WHERE id = ?').bind(userId).first();
    if (!u) fail(404, 'not-found');
    await env.DB.prepare('INSERT OR IGNORE INTO blocks (blocker, blocked, created_at) VALUES (?, ?, ?)').bind(me.id, userId, nowISO()).run();
  } else {
    await env.DB.prepare('DELETE FROM blocks WHERE blocker = ? AND blocked = ?').bind(me.id, userId).run();
  }
  return json(null, 204);
}

// ---------------------------------------------------------------- pictures

async function hmac(env, text) {
  if (!env.PHOTO_KEY) fail(503, 'photo-key');
  const key = await crypto.subtle.importKey('raw', enc.encode(env.PHOTO_KEY), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const sig = new Uint8Array(await crypto.subtle.sign('HMAC', key, enc.encode(text)));
  return btoa(String.fromCharCode(...sig)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

/// A link to a post's picture that works for an hour, only for whoever was
/// shown the post (the bucket itself is private).
/// An admin's link (marked, and signed with the mark) also opens hidden
/// posts' pictures, to judge whether to restore them; nobody else's does.
async function photoLink(env, url, postId, kind, admin = false) {
  // An admin's link lasts ten minutes; everyone else's an hour.
  const step = admin ? 60 : 600;   // rounded, so a link stays the same a while (cacheable)
  const exp = Math.floor(Date.now() / 1000 / step) * step + (admin ? 600 : LINK_SECONDS);
  const adm = admin ? 1 : 0;
  return `${url.origin}/v1/photos/${postId}/${kind}?exp=${exp}&adm=${adm}&sig=${await hmac(env, `${postId}/${kind}/${exp}/${adm}`)}`;
}

/// A picture, while its link is good and its post still public or waiting
/// (hidden, deleted and banned ones are gone at once).
async function servePhoto(url, env, postId, kind) {
  const exp = Number(url.searchParams.get('exp'));
  const sig = url.searchParams.get('sig') || '';
  const adm = url.searchParams.get('adm') === '1' ? 1 : 0;
  if (!(exp > Date.now() / 1000) || sig !== await hmac(env, `${postId}/${kind}/${exp}/${adm}`)) fail(403, 'link');
  const p = await env.DB.prepare('SELECT photo_key, thumb_key, state FROM posts WHERE id = ?').bind(postId).first();
  if (!p || (p.state === 'hidden' && !adm)) fail(404, 'not-found');
  const obj = await env.PHOTOS.get(kind === 'full' ? p.photo_key : p.thumb_key);
  if (!obj) fail(404, 'not-found');
  // Checked with the server each time it's shown: hidden means gone at once.
  return new Response(obj.body, { headers: { 'content-type': 'image/jpeg', 'cache-control': 'private, no-cache' } });
}

export { verifyAppleToken, streak, dayIn, dayBefore, badWords };   // for checks
