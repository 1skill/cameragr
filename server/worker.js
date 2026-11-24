// Koco community — Cloudflare Worker (project/community-api.md).
// C2a: sign in with Apple, sessions that can be ended at once, me, leaving,
// themes, banning. Bindings: DB (D1 koco-community), PHOTOS (R2 koco-photos).
// Secrets (later): APPLE_TEAM_ID, APPLE_KEY_ID, APPLE_PRIVATE_KEY — for the
// authorization-code exchange and revoking Apple's grant on deletion.

const BUNDLE_ID = 'com.oneskill.cameragr';
const APPLE_ISSUER = 'https://appleid.apple.com';
const SESSION_DAYS = 30;
const MILESTONES = [[3, 'portra400'], [7, 'dusk200'], [14, 'ember400']];

export default {
  /// Hourly: Apple grants still to revoke are tried again, each removed once done.
  async scheduled(event, env) {
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

  const me = await authenticate(request, env);
  if (method === 'GET' && path === '/v1/me') return json(await meView(env, me));
  if (method === 'POST' && path === '/v1/auth/signout') {
    await env.DB.prepare('DELETE FROM sessions WHERE token_hash = ?').bind(me.tokenHash).run();
    return json(null, 204);
  }
  if (method === 'DELETE' && path === '/v1/me') return leave(env, me);

  const ban = path.match(/^\/v1\/admin\/users\/([^/]+)\/ban$/);
  if (method === 'POST' && ban) {
    if (!me.is_admin) fail(403, 'not-admin');
    return banUser(env, ban[1]);
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

async function streak(env, user) {
  const { results } = await env.DB.prepare('SELECT day FROM checkins WHERE user_id = ? ORDER BY day DESC LIMIT 400').bind(user.id).all();
  const days = new Set(results.map(r => r.day));
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
  const steps = [env.DB.prepare('DELETE FROM users WHERE id = ?').bind(me.id)];   // cascades
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

async function banUser(env, id) {
  await env.DB.batch([
    env.DB.prepare('UPDATE users SET banned = 1 WHERE id = ?').bind(id),
    env.DB.prepare("UPDATE posts SET state = 'hidden' WHERE author = ?").bind(id),
    env.DB.prepare('DELETE FROM sessions WHERE user_id = ?').bind(id),
  ]);
  return json(null, 204);
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

export { verifyAppleToken, streak, dayIn, dayBefore };   // for checks
