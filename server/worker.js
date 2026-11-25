// Koco community — Cloudflare Worker (project/community-api.md).
// C2a: sign in with Apple, sessions that can be ended at once, me, leaving,
// themes, banning. Bindings: DB (D1 koco-community), PHOTOS (R2 koco-photos).
// C2b: uploads into private R2, posting (approved before public: user 11/24),
// pages of a theme's posts, pictures through signed links, likes, reports,
// blocks, deleting a post.
// Secrets: PHOTO_KEY (signs picture links); later APPLE_TEAM_ID, APPLE_KEY_ID,
// APPLE_PRIVATE_KEY — for the authorization-code exchange and revoking
// Apple's grant on deletion.

import { AsyncLocalStorage } from 'node:async_hooks';

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
    await drainOutbox(env).catch(e => console.error('outbox', e));
    // Left accounts: their prefix cleared twice more, an hour apart.
    const { results: purges } = await env.DB.prepare('SELECT user_id, passes FROM pending_purges LIMIT 50').all();
    for (const p of purges) {
      // Moved on only when a pass worked; a failed one is tried again next hour.
      const ok = await purgePhotos(env, p.user_id).then(() => true, e => { console.error('purge', e); return false; });
      if (!ok) continue;
      await env.DB.prepare(p.passes >= 1 ? 'DELETE FROM pending_purges WHERE user_id = ?' : 'UPDATE pending_purges SET passes = passes + 1 WHERE user_id = ?').bind(p.user_id).run();
    }
    await usageCheck(env);
    // Notice read marks older than the notices themselves (30 days) go, hourly
    // (the privacy policy says so).
    await env.DB.prepare('DELETE FROM notice_marks WHERE at < ?')
      .bind(new Date(clockNow() - NOTICE_DAYS * 86400000).toISOString()).run().catch(e => console.error('marks', e));
    // A letter report's copy of the letters goes 90 days after it was handled (user 11/25).
    await env.DB.prepare('DELETE FROM dm_reports WHERE handled = 1 AND handled_at < ?')
      .bind(new Date(clockNow() - 90 * 86400000).toISOString()).run().catch(e => console.error('dm reports', e));
    if (!hasAppleKey(env)) return;
    const { results } = await env.DB.prepare('SELECT refresh_token FROM pending_revocations LIMIT 50').all();
    for (const r of results) {
      if (await revokeApple(env, r.refresh_token).catch(() => false)) {
        await env.DB.prepare('DELETE FROM pending_revocations WHERE refresh_token = ?').bind(r.refresh_token).run();
      }
    }
  },
  async fetch(request, env, ctx) {
    const started = Date.now(), rid = crypto.randomUUID().slice(0, 8);
    let res;
    try {
      const testing = !!env.TEST_LOGIN && request.headers.get('x-test-login') === env.TEST_LOGIN;
      const now = testing && request.headers.get('x-test-now') ? Date.parse(request.headers.get('x-test-now')) : null;
      // Per request: its clock, and its context (to send mail past the response).
      // Test Worker only (C12): what this request costs, in an X-Test-Cost header.
      const cost = testing && request.headers.get('x-test-cost') ? { reads: 0, writes: 0, queries: 0, r2A: 0, r2B: 0, r2Bytes: 0 } : null;
      const useEnv = cost ? metered(env, cost) : env;
      res = await clock.run({ now, ctx, rid }, () => route(request, useEnv));
      if (cost) { res = new Response(res.body, res); res.headers.set('x-test-cost', JSON.stringify(cost)); }
    } catch (e) {
      if (e instanceof HttpError) res = json({ error: e.code }, e.status);
      else { console.error(JSON.stringify({ rid, error: String(e && e.message || e).slice(0, 300) })); res = json({ error: 'server' }, 500); }
    }
    // One line a request (C11): its id, the route's shape (ids and the query,
    // which holds signed links, left out), status, time. Never tokens or content.
    const url = new URL(request.url);
    const shape = url.pathname.replace(/\/[0-9a-f-]{16,}|\/\d+(?=\/|$)/gi, '/:id');
    console.log(JSON.stringify({ rid, m: request.method, route: shape, status: res.status, ms: Date.now() - started,
                                 code: res.status >= 400 ? (await res.clone().json().catch(() => ({}))).error : undefined }));
    return res;
  },
};

/// The bindings with their use counted (test Worker only): D1 rows read and
/// written, R2 class A (put, list) and B (get, head) operations and bytes.
function metered(env, cost) {
  const count = r => { const m = (r && r.meta) || {}; cost.queries++; cost.reads += m.rows_read || 0; cost.writes += m.rows_written || 0; return r; };
  const raw = new WeakMap();   // wrapped statement → the real one (batch wants the real one)
  const wrapStmt = st => {
    const w = new Proxy(st, { get(t, k) {
      if (k === 'bind') return (...a) => wrapStmt(t.bind(...a));
      if (k === 'run' || k === 'all') return async (...a) => count(await t[k](...a));
      if (k === 'first') return async (...a) => {
        // first() hides its meta: run it as all() to count, give the first row.
        const r = count(await t.all()); const row = r.results[0] ?? null;
        return a.length ? (row ? row[a[0]] : null) : row;
      };
      const v = t[k]; return typeof v === 'function' ? v.bind(t) : v;
    } });
    raw.set(w, st);
    return w;
  };
  const db = { prepare: q => wrapStmt(env.DB.prepare(q)),
               batch: async list => { const rs = await env.DB.batch(list.map(x => raw.get(x) ?? x)); rs.forEach(count); return rs; } };
  const r2 = new Proxy(env.PHOTOS, { get(t, k) {
    if (k === 'put' || k === 'list') return async (...a) => { cost.r2A++; if (k === 'put' && a[1]?.byteLength) cost.r2Bytes += a[1].byteLength; return t[k](...a); };
    if (k === 'get' || k === 'head') return async (...a) => { cost.r2B++; const o = await t[k](...a); if (o?.size) cost.r2Bytes += o.size; return o; };
    const v = t[k]; return typeof v === 'function' ? v.bind(t) : v;
  } });
  return { ...env, DB: db, PHOTOS: r2 };
}

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
  // Test hooks: only with the TEST_LOGIN secret set (never on the real
  // Worker) and the request carrying it.
  const testing = !!env.TEST_LOGIN && request.headers.get('x-test-login') === env.TEST_LOGIN;
  if (testing && method === 'POST' && path === '/v1/test/session') return testSession(request, env);
  if (testing && method === 'POST' && path === '/v1/test/outbox') {
    // Make the fake sender fail the next n sends, then send what's due now.
    const b = await request.json().catch(() => ({}));
    if (Number.isInteger(b.failNext)) await env.DB.prepare('INSERT OR REPLACE INTO test_flags (key, n) VALUES (?, ?)').bind('fail', b.failNext).run();
    await drainOutbox(env);
    return json((await env.DB.prepare('SELECT * FROM outbox ORDER BY id DESC LIMIT 20').all()).results);
  }
  if (method === 'GET' && path === '/v1/health') return json({ ok: true, maintenance: env.MAINTENANCE === '1' || undefined });
  // Maintenance (a restore under way): only admins' routes answer.
  // Signing in still works, so an admin whose session ran out can come back (retro 9).
  if (env.MAINTENANCE === '1' && !path.startsWith('/v1/admin/') && path !== '/v1/me' && path !== '/v1/auth/apple') fail(503, 'maintenance');
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
  let r;
  if (method === 'POST' && (r = path.match(/^\/v1\/rewards\/(\d+)\/claim$/))) return claimReward(request, env, me, Number(r[1]));
  if (method === 'POST' && (r = path.match(/^\/v1\/rewards\/(\d+)\/redeem$/))) return redeemVoucher(request, env, me, Number(r[1]));

  let m;
  if (method === 'POST' && path === '/v1/uploads') return newUpload(env, me);
  if (method === 'PUT' && (m = path.match(/^\/v1\/uploads\/([^/]+)\/(photo|thumb)$/))) return putUpload(request, env, me, m[1], m[2]);
  if (method === 'POST' && path === '/v1/posts') return createPost(request, env, me, url);
  // Every theme's pictures at once, newest first, or one film's (C18: the
  // album follows the left page: everyone's latest, or a film's room).
  if (method === 'GET' && path === '/v1/posts') return themePosts(url, env, me, null, url.searchParams.get('film'));
  // Following (S1): one way, no counts shown to anyone (user 11/25).
  if (method === 'GET' && path === '/v1/feed/following') return themePosts(url, env, me, null, null, true);
  // An author's page (S2): their card, and their public pictures.
  if (method === 'GET' && (m = path.match(/^\/v1\/users\/([^/]+)$/))) return authorCard(env, me, decodeURIComponent(m[1]));
  if (method === 'GET' && (m = path.match(/^\/v1\/users\/([^/]+)\/posts$/))) {
    await visibleAuthor(env, me, decodeURIComponent(m[1]));
    return themePosts(url, env, me, null, null, false, decodeURIComponent(m[1]));
  }
  if ((m = path.match(/^\/v1\/follows\/([^/]+)$/)) && (method === 'PUT' || method === 'DELETE')) return follow(env, me, m[1], method === 'PUT');
  if (method === 'GET' && path === '/v1/me/following') return followList(env, me, 'following');
  if (method === 'GET' && path === '/v1/me/followers') return followList(env, me, 'followers');
  if (method === 'GET' && (m = path.match(/^\/v1\/themes\/([^/]+)\/posts$/))) return themePosts(url, env, me, decodeURIComponent(m[1]));
  if ((m = path.match(/^\/v1\/posts\/([^/]+)$/))) {
    if (method === 'GET') return json(await postView(env, url, me, await visiblePost(env, me, m[1])));
    if (method === 'DELETE') return deletePost(env, me, m[1]);
  }
  if ((m = path.match(/^\/v1\/posts\/([^/]+)\/like$/)) && (method === 'PUT' || method === 'DELETE')) return like(env, me, m[1], method === 'PUT');
  if (method === 'POST' && (m = path.match(/^\/v1\/posts\/([^/]+)\/report$/))) return report(request, env, me, m[1]);
  if ((m = path.match(/^\/v1\/posts\/([^/]+)\/comments$/))) {
    if (method === 'GET') return listComments(env, url, me, m[1]);
    if (method === 'POST') return addComment(request, env, me, m[1]);
  }
  if (method === 'DELETE' && (m = path.match(/^\/v1\/comments\/([^/]+)$/))) return deleteComment(env, me, m[1]);
  if (method === 'POST' && (m = path.match(/^\/v1\/comments\/([^/]+)\/report$/))) return reportComment(request, env, me, m[1]);
  if (method === 'GET' && path === '/v1/me/news') return news(env, url, me);
  if (method === 'GET' && path === '/v1/me/mine') return mine(env, url, me);
  if (method === 'GET' && path === '/v1/me/posts') return myPosts(env, url, me);
  if (method === 'POST' && path === '/v1/me/rules') {
    const b = await request.json().catch(() => ({}));
    if (b.version !== RULES_VERSION) fail(409, 'rules-version');
    await env.DB.prepare('UPDATE users SET rules_version = ?, rules_at = ? WHERE id = ?').bind(RULES_VERSION, nowISO(), me.id).run();
    return json(null, 204);
  }
  if (method === 'PATCH' && path === '/v1/me') return requestName(request, env, me);
  if (method === 'PATCH' && path === '/v1/me/bio') return requestBio(request, env, me);
  if (method === 'GET' && path === '/v1/dms') return dmThreads(env, url, me);
  if ((m = path.match(/^\/v1\/dms\/([^/]+)$/))) {
    if (method === 'GET') return dmThread(env, url, me, m[1]);
    if (method === 'POST') return sendDM(request, env, me, m[1]);
  }
  if (method === 'POST' && (m = path.match(/^\/v1\/dms\/([^/]+)\/report$/))) return reportDM(request, env, me, m[1]);
  if (method === 'POST' && (m = path.match(/^\/v1\/dms\/([^/]+)\/read$/))) return readDM(request, env, me, m[1]);
  if (method === 'GET' && path === '/v1/me/notices') return notices(env, url, me);
  if (method === 'POST' && path === '/v1/me/notices/seen') return noticesSeen(request, env, me);
  if (method === 'POST' && path === '/v1/me/news/seen') {
    await env.DB.prepare('INSERT INTO seen (user_id, at) VALUES (?, ?) ON CONFLICT(user_id) DO UPDATE SET at = excluded.at').bind(me.id, nowISO()).run();
    return json(null, 204);
  }
  if ((m = path.match(/^\/v1\/blocks\/([^/]+)$/)) && (method === 'PUT' || method === 'DELETE')) return block(env, me, m[1], method === 'PUT');
  // Moderation (C2c): admins only, checked here on the server; every step logged.
  if (path.startsWith('/v1/admin/')) {
    if (!me.is_admin) fail(403, 'not-admin');
    if (method === 'GET' && path === '/v1/admin/queue') return adminQueue(env, url, me);
    if (method === 'GET' && path === '/v1/admin/names') return adminNames(env);
    if (method === 'GET' && path === '/v1/admin/bios') return adminBios(env);
    if (method === 'GET' && path === '/v1/admin/dm-reports') return adminDMReports(env);
    if (method === 'POST' && (m = path.match(/^\/v1\/admin\/dm-reports\/(\d+)\/handled$/))) {
      const done = await env.DB.prepare('UPDATE dm_reports SET handled = 1, handled_at = ? WHERE id = ? AND handled = 0').bind(nowISO(), Number(m[1])).run();
      if (done.meta.changes) await logStep(env, me, 'dm-report-handled', 'dm-report', m[1], null).run();
      return json(null, 204);
    }
    if (method === 'POST' && (m = path.match(/^\/v1\/admin\/bios\/([^/]+)\/(approve|reject)$/))) return decideBio(request, env, me, m[1], m[2]);
    if (method === 'POST' && (m = path.match(/^\/v1\/admin\/names\/([^/]+)\/(approve|reject)$/))) return decideName(request, env, me, m[1], m[2]);
    if (method === 'POST' && path === '/v1/admin/names/settle') return settleAllNames(env);
    if (method === 'GET' && path === '/v1/admin/reports') return adminReports(env, url, me);
    if (method === 'GET' && path === '/v1/admin/log') return adminLog(env);
    if (method === 'GET' && path === '/v1/admin/hidden') {
      const { results } = await env.DB.prepare(
        "SELECT p.*, u.name AS author_name, 0 AS liked FROM posts p JOIN users u ON u.id = p.author WHERE p.state = 'hidden' ORDER BY p.created_at DESC LIMIT 60").all();
      return json(await Promise.all(results.map(p => postView(env, url, me, p))));
    }
    if (method === 'GET' && path === '/v1/admin/alerts') return json((await env.DB.prepare('SELECT * FROM alerts ORDER BY created_at DESC LIMIT 50').all()).results);
    if (method === 'GET' && path === '/v1/admin/status') return adminStatus(env);
    if (method === 'GET' && path === '/v1/admin/outbox') {
      const { results } = await env.DB.prepare("SELECT id, kind, subject, count, state, attempts, last_error, created_at, sent_at FROM outbox WHERE state = 'failed' ORDER BY id DESC LIMIT 30").all();
      return json(results.map(r => ({ id: r.id, kind: r.kind, subject: r.subject, count: r.count, state: r.state,
                                      attempts: r.attempts, lastError: r.last_error || undefined, createdAt: r.created_at })));
    }
    if (method === 'POST' && (m = path.match(/^\/v1\/admin\/outbox\/(\d+)\/retry$/))) {
      // Sent again by hand: from the start, now (a failed one is never lost).
      await env.DB.batch([
        env.DB.prepare("UPDATE outbox SET state = 'pending', attempts = 0, next_at = ? WHERE id = ? AND state = 'failed'").bind(nowISO(), Number(m[1])),
        logStep(env, me, 'retry', 'outbox', m[1], null),
      ]);
      clock.getStore()?.ctx?.waitUntil?.(drainOutbox(env).catch(() => {}));
      return json(null, 204);
    }
    if (method === 'POST' && path === '/v1/admin/replay-deletions') return replayDeletions(env, me);
    if (method === 'POST' && (m = path.match(/^\/v1\/admin\/posts\/([^/]+)\/(approve|hide|restore)$/))) return moderate(env, m[1], m[2], me, await reasonOf(request));
    if (method === 'GET' && path === '/v1/admin/comments') return adminComments(env, url);
    if (method === 'POST' && (m = path.match(/^\/v1\/admin\/comments\/([^/]+)\/(approve|hide|restore)$/))) {
      const c = await env.DB.prepare('SELECT * FROM comments WHERE id = ?').bind(m[1]).first();
      if (!c) fail(404, 'not-found');
      const to = m[2] === 'hide' ? 'hidden' : 'public';
      await env.DB.batch([
        env.DB.prepare(`UPDATE comments SET state = ?, approved_at = COALESCE(approved_at, CASE WHEN ? = 'public' THEN ? END) WHERE id = ?`).bind(to, to, nowISO(), m[1]),
        env.DB.prepare('UPDATE comment_reports SET handled = 1 WHERE comment_id = ?').bind(m[1]),
        logStep(env, me, m[2], 'comment', m[1], await reasonOf(request)),
      ]);
      return json(null, 204);
    }
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
// The clock. Only a test Worker (one with the TEST_LOGIN secret) lets a
// request set it, with X-Test-Now; the real one always runs on real time.
// Per request (retro 8): concurrent requests never see each other's clock.
const clock = new AsyncLocalStorage();
const clockNow = () => clock.getStore()?.now ?? Date.now();
const nowISO = () => new Date(clockNow()).toISOString();

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
function dayIn(tz, date = new Date(clockNow())) {
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
  if (!appleKeys || clockNow() - appleKeysAt > 3600_000 || !appleKeys.find(k => k.kid === kid)) {
    const r = await fetch('https://appleid.apple.com/auth/keys');
    if (!r.ok) fail(503, 'apple-unavailable');
    appleKeys = (await r.json()).keys; appleKeysAt = clockNow();
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
  const now = Math.floor(clockNow() / 1000);
  if (claims.iss !== APPLE_ISSUER) fail(401, 'issuer');
  if (claims.aud !== BUNDLE_ID) fail(401, 'audience');
  if (!(claims.exp > now - 60)) fail(401, 'expired');
  if (!(claims.iat < now + 300)) fail(401, 'issued');
  if (!rawNonce || claims.nonce !== await sha256hex(rawNonce)) fail(401, 'nonce');
  if (!claims.sub) fail(401, 'subject');
  return claims;
}

async function signInWithApple(request, env) {
  // The real Worker never signs in without its Apple key (retro 8); only a
  // test Worker may run without one.
  if (!hasAppleKey(env) && !env.TEST_LOGIN) fail(503, 'apple-config');
  const body = await request.json().catch(() => ({}));
  const claims = await verifyAppleToken(body.identityToken, body.nonce);
  // A nonce is good once (replay): kept a day, then let go.
  try {
    await env.DB.prepare('INSERT INTO used_nonces (nonce, used_at) VALUES (?, ?)').bind(await sha256hex(body.nonce), nowISO()).run();
  } catch { fail(401, 'nonce-used'); }
  await env.DB.prepare("DELETE FROM used_nonces WHERE used_at < ?").bind(new Date(clockNow() - 86400_000).toISOString()).run();

  let user = await env.DB.prepare('SELECT * FROM users WHERE apple_sub = ?').bind(claims.sub).first();
  let isNew = false;
  if (!user) {
    isNew = true;
    const id = crypto.randomUUID();
    const tz = request.headers.get('x-koco-tz') || 'UTC';
    await env.DB.prepare('INSERT INTO users (id, apple_sub, name, tz, created_at) VALUES (?, ?, ?, ?, ?)')
      .bind(id, claims.sub, 'Koco ' + id.slice(0, 6), safeTZ(tz), nowISO()).run();
    await firstName(env, id, typeof body.name === 'string' ? body.name : '');
    user = await env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(id).first();
  }
  if (user.banned) fail(403, 'banned');
  user = await settleName(env, user);
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
  const expires = new Date(clockNow() + SESSION_DAYS * 86400_000).toISOString();
  await env.DB.prepare('INSERT INTO sessions (token_hash, user_id, expires_at, created_at) VALUES (?, ?, ?, ?)')
    .bind(await sha256hex(token), user.id, expires, nowISO()).run();
  return json({ token, isNew, user: await meView(env, user) });
}

/// A test account and session without Apple (test Worker only).
async function testSession(request, env) {
  const b = await request.json().catch(() => ({}));
  const sub = 'test:' + String(b.sub || 'a');
  let user = await env.DB.prepare('SELECT * FROM users WHERE apple_sub = ?').bind(sub).first();
  if (!user) {
    const id = crypto.randomUUID();
    await env.DB.prepare('INSERT INTO users (id, apple_sub, name, tz, is_admin, created_at) VALUES (?, ?, ?, ?, ?, ?)')
      .bind(id, sub, String(b.name || 'Test').slice(0, 30), safeTZ(b.tz || 'UTC'), b.admin ? 1 : 0, nowISO()).run();
    user = await env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(id).first();
  }
  if (user.banned) fail(403, 'banned');
  user = await settleName(env, user);
  const token = randomToken();
  await env.DB.prepare('INSERT INTO sessions (token_hash, user_id, expires_at, created_at) VALUES (?, ?, ?, ?)')
    .bind(await sha256hex(token), user.id, new Date(clockNow() + SESSION_DAYS * 86400_000).toISOString(), nowISO()).run();
  return json({ token, user: await meView(env, user) });
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
  // Real time, always: a session's life isn't the test clock's business.
  if (!row || row.expires_at < new Date().toISOString()) fail(401, 'signed-out');
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

// ---------------------------------------------------------------- names (S3)

/// Names are one to a person (user 11/25): compared without spaces, case or
/// full-/half-width differences; a few words are kept for the house.
const NAME_DAYS = 30;
const RESERVED = ['koco', '官方', '暗房', '管理员', '客服', 'admin', 'official', 'darkroom', 'moderator', 'support'];
function nameKey(name) { return name.normalize('NFKC').toLowerCase().replace(/[\s\u3000·・.,，。_\-'"]/g, ''); }
function checkName(name) {
  const n = [...name].length;
  if (n < 2 || n > 12 || badWords(name) || /https?:\/\/|www\./i.test(name)) fail(422, 'words');
  const key = nameKey(name);
  if ([...key].length < 2) fail(422, 'words');
  if (RESERVED.some(r => key.includes(r))) fail(422, 'reserved');
  return key;
}
/// Holds a name for someone (theirs, or asked for); false if it is another's.
async function claimName(env, userId, key, kind) {
  const r = await env.DB.prepare(
    'INSERT INTO names (name_norm, user_id, kind, created_at) VALUES (?, ?, ?, ?) ON CONFLICT(name_norm) DO NOTHING'
  ).bind(key, userId, kind, nowISO()).run();
  if (r.meta.changes === 1) return true;
  const row = await env.DB.prepare('SELECT user_id FROM names WHERE name_norm = ?').bind(key).first();
  return !!row && row.user_id === userId;
}
/// A new account: Koco + digits in public; the name Apple gave, if it fits
/// and is free, asked for like any other (shown to them, to others once approved).
async function firstName(env, id, given) {
  const fallback = 'Koco ' + id.slice(0, 6);
  await claimName(env, id, nameKey(fallback), 'current');
  await env.DB.prepare('UPDATE users SET name_norm = ? WHERE id = ?').bind(nameKey(fallback), id).run();
  const name = given.replace(/\s+/g, ' ').trim();
  let key = null;
  try { key = checkName(name); } catch { key = null; }
  if (key && await claimName(env, id, key, 'pending')) {
    await env.DB.prepare('UPDATE users SET pending_name = ?, pending_at = ? WHERE id = ?').bind(name, nowISO(), id).run();
  }
}
/// An account from before names were one to a person: its name is held now,
/// or, if someone earlier holds it, it is asked to choose another.
/// Who signed up first keeps it (retro S3): a later account that settled
/// first, with the name it always had, gives it back and is asked to choose.
async function settleName(env, user) {
  if (user.name_norm || user.must_rename) return user;
  const key = nameKey(user.name);
  if (key && await claimName(env, user.id, key, 'current')) {
    await env.DB.prepare('UPDATE users SET name_norm = ? WHERE id = ?').bind(key, user.id).run();
    return { ...user, name_norm: key };
  }
  const holder = key ? await env.DB.prepare(
    `SELECT u.id, u.created_at, u.name_changed_at, n.kind FROM names n JOIN users u ON u.id = n.user_id WHERE n.name_norm = ?`).bind(key).first() : null;
  const earlier = holder && (user.created_at < holder.created_at || (user.created_at === holder.created_at && user.id < holder.id));
  if (holder && earlier && holder.kind === 'current' && !holder.name_changed_at) {
    const moved = await env.DB.batch([
      env.DB.prepare('UPDATE names SET user_id = ?, created_at = ? WHERE name_norm = ? AND user_id = ?').bind(user.id, nowISO(), key, holder.id),
      env.DB.prepare('UPDATE users SET name_norm = NULL, must_rename = 1 WHERE id = ? AND name_norm = ?').bind(holder.id, key),
      env.DB.prepare('UPDATE users SET name_norm = ? WHERE id = ?').bind(key, user.id),
    ]);
    if (moved[0].meta.changes === 1) return { ...user, name_norm: key };
  }
  await env.DB.prepare('UPDATE users SET must_rename = 1 WHERE id = ?').bind(user.id).run();
  return { ...user, must_rename: 1 };
}
/// Every account not yet settled, oldest first (run once after deploying S3,
/// so a name is held for those who haven't signed in since).
/// Ten at a time (a request may make at most 50 queries on the free plan):
/// called again until `left` is 0.
async function settleAllNames(env) {
  const rows = (await env.DB.prepare('SELECT * FROM users WHERE name_norm IS NULL AND must_rename = 0 ORDER BY created_at, id LIMIT 10').all()).results;
  for (const u of rows) await settleName(env, u);
  const left = (await env.DB.prepare('SELECT count(*) AS n FROM users WHERE name_norm IS NULL AND must_rename = 0').first()).n;
  return json({ settled: rows.length, left });
}
/// Asking for a new name: held for them at once (no one else can take it
/// meanwhile), shown to them at once, to others once approved.
async function requestName(request, env, me) {
  const b = await request.json().catch(() => ({}));
  const name = typeof b.name === 'string' ? b.name.replace(/\s+/g, ' ').trim() : '';
  const key = checkName(name);
  if (!me.must_rename && me.name_changed_at && clockNow() - Date.parse(me.name_changed_at) < NAME_DAYS * 86400_000) fail(429, 'too-soon');
  await rateLimit(env, me, 'rename', 10, 86400);
  const oldPending = me.pending_name ? nameKey(me.pending_name) : null;
  if (key === me.name_norm) {
    // Back to the name they have: whatever was asked for is let go.
    if (oldPending) await env.DB.prepare("DELETE FROM names WHERE name_norm = ? AND user_id = ? AND kind = 'pending'").bind(oldPending, me.id).run();
    await env.DB.prepare('UPDATE users SET pending_name = NULL, pending_at = NULL, shown_name = NULL WHERE id = ?').bind(me.id).run();
    return json(await meView(env, { ...me, pending_name: null, shown_name: null }));
  }
  if (!await claimName(env, me.id, key, 'pending')) fail(409, 'taken');
  // Only if nothing else changed their request meanwhile (two at once: one wins,
  // the other's hold is let go).
  const at = nowISO();
  const set = await env.DB.prepare(
    'UPDATE users SET pending_name = ?, pending_at = ?, shown_name = NULL WHERE id = ? AND pending_at IS ?').bind(name, at, me.id, me.pending_at ?? null).run();
  if (set.meta.changes !== 1) {
    if (key !== oldPending) await env.DB.prepare("DELETE FROM names WHERE name_norm = ? AND user_id = ? AND kind = 'pending'").bind(key, me.id).run();
    fail(409, 'busy');
  }
  if (oldPending && oldPending !== key) {
    await env.DB.prepare("DELETE FROM names WHERE name_norm = ? AND user_id = ? AND kind = 'pending'").bind(oldPending, me.id).run();
  }
  return json(await meView(env, { ...me, pending_name: name, pending_at: at }));
}
async function adminNames(env) {
  const rows = (await env.DB.prepare(
    'SELECT id, name, pending_name, pending_at FROM users WHERE pending_name IS NOT NULL ORDER BY pending_at LIMIT 100').all()).results;
  return json({ names: rows.map(r => ({ userId: r.id, name: r.name, requested: r.pending_name, requestedAt: r.pending_at, version: r.pending_at })) });
}
async function decideName(request, env, admin, userId, decision) {
  const b = await request.json().catch(() => ({}));
  const u = await env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(userId).first();
  if (!u || !u.pending_name) fail(404, 'not-found');
  // The request the admin saw, not one made since.
  if (typeof b.version !== 'string' || b.version !== u.pending_at) fail(409, 'stale');
  const key = nameKey(u.pending_name);
  // Every step only if the request is still the one seen (one transaction:
  // a new request in between leaves everything as it was, 409).
  const still = 'EXISTS (SELECT 1 FROM users WHERE id = ? AND pending_at = ?)';
  let steps;
  if (decision === 'approve') {
    steps = [
      env.DB.prepare(`UPDATE names SET kind = 'current' WHERE name_norm = ? AND user_id = ? AND ${still}`).bind(key, userId, userId, b.version),
      env.DB.prepare(`DELETE FROM names WHERE name_norm = ? AND user_id = ? AND ? != ? AND ${still}`)
        .bind(u.name_norm || '', userId, u.name_norm || '', key, userId, b.version),
      logStep(env, admin, 'name-approve', 'user', userId, u.pending_name),
      // The 30 days count from when they asked, not from the approval; the
      // first real name after the placeholder ("Koco xxxxxx") isn't a change.
      env.DB.prepare(`UPDATE users SET name = pending_name, name_norm = ?,
                      name_changed_at = CASE WHEN name = 'Koco ' || substr(id, 1, 6) THEN name_changed_at ELSE pending_at END,
                      pending_name = NULL, pending_at = NULL, shown_name = NULL, must_rename = 0
                      WHERE id = ? AND pending_at = ?`).bind(key, userId, b.version),
    ];
  } else {
    // Turned down without a word to them (user 11/25): the name is let go.
    steps = [
      env.DB.prepare(`DELETE FROM names WHERE name_norm = ? AND user_id = ? AND kind = 'pending' AND ${still}`).bind(key, userId, userId, b.version),
      logStep(env, admin, 'name-reject', 'user', userId, u.pending_name),
      // They go on seeing it themselves; nothing starts the 30 days.
      env.DB.prepare('UPDATE users SET shown_name = pending_name, pending_name = NULL, pending_at = NULL WHERE id = ? AND pending_at = ?').bind(userId, b.version),
    ];
  }
  const done = await env.DB.batch(steps);
  if (done[done.length - 1].meta.changes !== 1) fail(409, 'stale');   // nothing else applied either
  return json(null, 204);
}

/// The name one sees of oneself: the one asked for at once, and a turned-down
/// one too (a refusal says nothing, user 11/25); others see the approved name.
const selfName = (u) => u.pending_name || u.shown_name || u.name;
const selfBio = (u) => u.pending_bio || u.shown_bio || u.bio || null;

// ---------------------------------------------------------------- messages (S5)

/// The smallest safe version (user 11/25): only between two people who follow
/// each other, text only, one first message until the other answers (then
/// both write freely), open to everyone (no age gate, user 11/25), no links or
/// contacts, 20 sent a day; a report carries the last 20 messages. Unfollowing
/// stops new messages (the old ones stay readable); a block, a ban or leaving
/// hides the conversation altogether. Order is the order written (rowid), never
/// a clock read before writing.
const DM_MAX = 300, DM_DAY = 20, DM_PAGE = 50;
const dmPair = (a, b) => (a < b ? `${a}:${b}` : `${b}:${a}`);
// Both follow each other, both are there, no block either way (?1 me, ?2 them).
const MUTUAL = `EXISTS (SELECT 1 FROM follows WHERE follower = ?1 AND followee = ?2)
  AND EXISTS (SELECT 1 FROM follows WHERE follower = ?2 AND followee = ?1)
  AND EXISTS (SELECT 1 FROM users WHERE id = ?2 AND banned = 0 AND leaving_at IS NULL)
  AND NOT EXISTS (SELECT 1 FROM blocks WHERE (blocker = ?1 AND blocked = ?2) OR (blocker = ?2 AND blocked = ?1))`;
// Only the first waits (user 11/25): once the other has answered at all, both
// write freely (still 20 a day); before that, one message (?3 pair).
const MY_TURN = `(EXISTS (SELECT 1 FROM messages WHERE pair = ?3 AND sender = ?2)
  OR NOT EXISTS (SELECT 1 FROM messages WHERE pair = ?3 AND sender = ?1))`;
// Fewer than 20 actually sent in the last day (?8: a day ago); failed tries count nothing.
const DM_ROOM = `(SELECT count(*) FROM messages WHERE sender = ?1 AND created_at > ?8) < ${DM_DAY}`;

// Unread messages from anyone one can still see (no block either way, not banned or leaving).
const DM_UNREAD = `SELECT count(*) AS n FROM messages m JOIN users u ON u.id = m.sender WHERE m.recipient = ? AND m.read_at IS NULL
  AND u.banned = 0 AND u.leaving_at IS NULL
  AND NOT EXISTS (SELECT 1 FROM blocks WHERE (blocker = m.recipient AND blocked = m.sender) OR (blocker = m.sender AND blocked = m.recipient))`;

function dmView(m, me) {
  return { id: m.id, mine: m.sender === me.id, text: m.text, at: m.created_at, unread: m.recipient === me.id && !m.read_at };
}

/// The messages of theirs the app showed on screen: those are read, nothing else.
async function readDM(request, env, me, other) {
  const b = await request.json().catch(() => null);
  const ids = b && Array.isArray(b.ids) ? b.ids.filter(x => typeof x === 'string' && x.length <= 64) : [];
  if (!ids.length || ids.length > DM_PAGE) fail(400, 'ids');
  await env.DB.prepare(
    `UPDATE messages SET read_at = ? WHERE recipient = ? AND sender = ? AND read_at IS NULL AND id IN (${ids.map(() => '?').join(',')})`
  ).bind(nowISO(), me.id, other, ...ids).run();
  return json(null, 204);
}

async function dmState(env, me, other) {
  const r = await env.DB.prepare(`SELECT (${MUTUAL}) AS mutual, (${MY_TURN}) AS turn, (${DM_ROOM.replace('?8', '?4')}) AS room`)
    .bind(me.id, other, dmPair(me.id, other), new Date(clockNow() - 86400_000).toISOString()).first();
  return { mutual: !!r.mutual, myTurn: !!r.turn, room: !!r.room };
}

async function sendDM(request, env, me, other) {
  needRules(me);
  const b = await request.json().catch(() => null);
  if (!b || typeof b.clientId !== 'string' || !/^[A-Za-z0-9-]{8,64}$/.test(b.clientId)) fail(400, 'client-id');
  // The same message sent again (a retry, even at the same moment): that one.
  const sentBefore = () => env.DB.prepare('SELECT * FROM messages WHERE sender = ? AND client_id = ? AND recipient = ?')
    .bind(me.id, b.clientId, other).first();
  const again = await sentBefore();
  if (again) return json(dmView(again, me));
  if (other === me.id) fail(400, 'self');
  const text = typeof b.text === 'string' ? b.text.replace(/[ \t]+/g, ' ').replace(/\n{3,}/g, '\n\n').trim() : '';
  if (!text || [...text].length > DM_MAX || badWords(text) || offKoco(text)) fail(422, 'words');
  const id = crypto.randomUUID(), at = nowISO(), pair = dmPair(me.id, other);
  const dayAgo = new Date(clockNow() - 86400_000).toISOString();
  // One statement: still mutual, still my turn, room left today, then written.
  let put;
  try {
    put = await env.DB.prepare(
      `INSERT INTO messages (id, pair, sender, recipient, text, client_id, created_at)
       SELECT ?4, ?3, ?1, ?2, ?5, ?6, ?7 WHERE ${MUTUAL} AND ${MY_TURN} AND ${DM_ROOM}`)
      .bind(me.id, other, pair, id, text, b.clientId, at, dayAgo).run();
  } catch (e) {
    // The same client id written meanwhile by its twin: answer with that one.
    const twin = await sentBefore();
    if (twin) return json(dmView(twin, me));
    throw e;
  }
  if (put.meta.changes !== 1) {
    const twin = await sentBefore();
    if (twin) return json(dmView(twin, me));
    const st = await dmState(env, me, other);
    if (!st.mutual) fail(403, 'not-mutual');
    if (!st.room) fail(429, 'too-many');
    fail(409, 'wait-reply');
  }
  return json(dmView({ id, sender: me.id, text, created_at: at }, me), 201);
}

/// One's conversations: the other person, the last word, how many unread;
/// only with people one may still write to or read (no blocks, bans, leaving).
async function dmThreads(env, url, me) {
  const cur = Number(url.searchParams.get('cursor') || 0);
  const rows = (await env.DB.prepare(
    `SELECT t.*, u.name AS other_name FROM (
       SELECT m.*, CASE WHEN m.sender = ?1 THEN m.recipient ELSE m.sender END AS other,
              ROW_NUMBER() OVER (PARTITION BY m.pair ORDER BY m.rowid DESC) AS rn, m.rowid AS seq
       FROM messages m WHERE m.sender = ?1 OR m.recipient = ?1) t
     JOIN users u ON u.id = t.other
     WHERE t.rn = 1 AND u.banned = 0 AND u.leaving_at IS NULL AND (?2 = 0 OR t.seq < ?2)
       AND NOT EXISTS (SELECT 1 FROM blocks WHERE (blocker = ?1 AND blocked = t.other) OR (blocker = t.other AND blocked = ?1))
     ORDER BY t.seq DESC LIMIT 31`).bind(me.id, cur).all()).results;
  const page = rows.slice(0, 30);
  const unread = (await env.DB.prepare(
    `SELECT sender, count(*) AS n FROM messages WHERE recipient = ? AND read_at IS NULL GROUP BY sender`).bind(me.id).all()).results;
  const byOther = Object.fromEntries(unread.map(r => [r.sender, r.n]));
  const threads = page.map(r => ({ with: { id: r.other, name: r.other_name }, last: dmView(r, me), unread: byOther[r.other] || 0 }));
  // The total over every conversation one can see, not only this page (as on /v1/me).
  const total = (await env.DB.prepare(DM_UNREAD).bind(me.id).first()).n;
  return json({ threads, unread: total, next: rows.length > 30 ? String(page[page.length - 1].seq) : null });
}

/// A conversation, newest first, 50 a page. Reading it marks nothing: the app
/// says which of theirs it actually showed (`readDM`, retro 13).
async function dmThread(env, url, me, other) {
  await visibleAuthor(env, me, other);   // blocked, banned, left: not there
  const pair = dmPair(me.id, other);
  const cur = Number(url.searchParams.get('cursor') || 0);
  const rows = (await env.DB.prepare(
    `SELECT rowid AS seq, * FROM messages WHERE pair = ? AND (? = 0 OR rowid < ?)
     ORDER BY rowid DESC LIMIT ${DM_PAGE + 1}`).bind(pair, cur, cur).all()).results;
  const page = rows.slice(0, DM_PAGE);
  const st = await dmState(env, me, other);
  const last = page[page.length - 1];
  return json({ messages: page.map(m => dmView(m, me)), canWrite: st.mutual && st.myTurn, mutual: st.mutual,
                waiting: st.mutual && !st.myTurn, next: rows.length > DM_PAGE && last ? String(last.seq) : null });
}

/// A report carries the last 20 messages as they were, for an admin to judge
/// (the only time anyone but the two reads them); the admins hear by email.
async function reportDM(request, env, me, other) {
  const b = await request.json().catch(() => null);
  if (!b || !REASONS.includes(b.reason)) fail(400, 'reason');
  await rateLimit(env, me, 'report', 30, 86400);
  // The twenty up to and including the message reported (or the latest), so
  // later ones never push it out of the evidence.
  const pair = dmPair(me.id, other);
  let upTo = null;
  if (typeof b.messageId === 'string') {
    upTo = await env.DB.prepare('SELECT rowid AS seq FROM messages WHERE id = ? AND pair = ? AND sender = ?').bind(b.messageId, pair, other).first();
    if (!upTo) fail(404, 'not-found');
  }
  const recent = (await env.DB.prepare(
    'SELECT id, sender, text, created_at FROM messages WHERE pair = ? AND (? = 0 OR rowid <= ?) ORDER BY rowid DESC LIMIT 20')
    .bind(pair, upTo?.seq ?? 0, upTo?.seq ?? 0).all()).results;
  if (!recent.length) fail(404, 'not-found');
  await env.DB.prepare('INSERT INTO dm_reports (reporter, reported, reason, transcript, created_at) VALUES (?, ?, ?, ?, ?)')
    .bind(me.id, other, b.reason, JSON.stringify(recent.reverse().map(m => ({ ...m, reported: m.id === b.messageId }))), nowISO()).run();
  await notify(env, 'report', `${b.reason} in messages (see Mine → Reports)`);
  return json(null, 204);
}

async function adminDMReports(env) {
  const rows = (await env.DB.prepare(
    `SELECT r.*, a.name AS reporter_name, b.name AS reported_name FROM dm_reports r
     JOIN users a ON a.id = r.reporter JOIN users b ON b.id = r.reported
     WHERE r.handled = 0 ORDER BY r.created_at LIMIT 50`).all()).results;
  return json({ reports: rows.map(r => ({ id: r.id, reason: r.reason, at: r.created_at,
    reporter: { id: r.reporter, name: r.reporter_name }, reported: { id: r.reported, name: r.reported_name },
    messages: JSON.parse(r.transcript).map(m => ({ from: m.sender === r.reporter ? 'reporter' : 'reported', text: m.text, at: m.created_at, reported: !!m.reported })) })) });
}

// ---------------------------------------------------------------- bio (S2b)

/// A line about oneself on one's page: 40 letters, approved before others see
/// it, shown to oneself at once (a refusal says nothing). No links or ways to
/// reach someone off Koco (user 11/25): addresses, handles, numbers, the apps'
/// names people use to pass them on.
const BIO_MAX = 40;
function offKoco(text) {
  const t = text.normalize('NFKC').toLowerCase();
  // Anything shaped like an address: a dot between letters and a known or any
  // 2–12 letter ending (example.dev, x.co, a.b.cn), with or without a scheme.
  return /https?:|www\.|:\/\//.test(t)
    || /[a-z0-9-]+[.。][a-z]{2,12}\b/.test(t)
    || /[a-z0-9-]+\s*(点|\bdot\b)\s*[a-z]{2,12}\b/.test(t)
    || /[\w.+-]+@[\w-]+\.[\w.]+/.test(t)
    // Any handle: @ followed by a letter or number, however short.
    || /[@＠]\s*[\w\u4e00-\u9fff]/.test(t)
    || /\d[\d\s-]{6,}\d/.test(t)
    || /微信|威信|薇信|vx|v信|wx|weixin|wechat|扣扣|qq|telegram|电报|whatsapp|\bline\b|instagram|\bins\b|\big\b|小红书|抖音|douyin|tiktok|weibo|微博|私聊|私信我|加我|联系我/.test(t);
}

async function requestBio(request, env, me) {
  const b = await request.json().catch(() => null);
  if (!b || typeof b.bio !== 'string') fail(400, 'bio');
  const bio = b.bio.replace(/\s+/g, ' ').trim();
  // What can't be kept is refused before it counts against the day's ten.
  if (bio && ([...bio].length > BIO_MAX || badWords(bio) || offKoco(bio))) fail(422, 'words');
  await rateLimit(env, me, 'bio', 10, 86400);
  if (!bio) {
    // Taking it away needs nobody's approval.
    await env.DB.prepare('UPDATE users SET bio = NULL, pending_bio = NULL, pending_bio_at = NULL, shown_bio = NULL WHERE id = ?').bind(me.id).run();
    return json(await meView(env, { ...me, bio: null, pending_bio: null, pending_bio_at: null, shown_bio: null }));
  }
  if ([...bio].length > BIO_MAX || badWords(bio) || offKoco(bio)) fail(422, 'words');
  if (bio === me.bio) {
    await env.DB.prepare('UPDATE users SET pending_bio = NULL, pending_bio_at = NULL, shown_bio = NULL WHERE id = ?').bind(me.id).run();
    return json(await meView(env, { ...me, pending_bio: null, pending_bio_at: null, shown_bio: null }));
  }
  const at = nowISO();
  await env.DB.prepare('UPDATE users SET pending_bio = ?, pending_bio_at = ?, shown_bio = NULL WHERE id = ?').bind(bio, at, me.id).run();
  return json(await meView(env, { ...me, pending_bio: bio, pending_bio_at: at, shown_bio: null }));
}

async function adminBios(env) {
  const rows = (await env.DB.prepare(
    `SELECT id, name, bio, pending_bio, pending_bio_at FROM users WHERE pending_bio IS NOT NULL
       AND banned = 0 AND leaving_at IS NULL ORDER BY pending_bio_at LIMIT 100`).all()).results;
  return json({ bios: rows.map(r => ({ userId: r.id, name: r.name, bio: r.bio, requested: r.pending_bio, version: r.pending_bio_at })) });
}

/// Only the request the admin saw (its time as the version); one statement.
async function decideBio(request, env, admin, userId, decision) {
  const b = await request.json().catch(() => null);
  if (!b || typeof b.version !== 'string') fail(409, 'stale');
  const u = await env.DB.prepare('SELECT pending_bio FROM users WHERE id = ? AND pending_bio_at = ?').bind(userId, b.version).first();
  if (!u) fail(409, 'stale');
  const set = decision === 'approve'
    ? 'bio = pending_bio, shown_bio = NULL'
    : 'shown_bio = pending_bio';   // turned down: they go on seeing it, nobody else does
  const done = await env.DB.prepare(`UPDATE users SET ${set}, pending_bio = NULL, pending_bio_at = NULL WHERE id = ? AND pending_bio_at = ?`)
    .bind(userId, b.version).run();
  if (done.meta.changes !== 1) fail(409, 'stale');
  await logStep(env, admin, `bio-${decision}`, 'user', userId, u.pending_bio).run();   // logged once it happened
  return json(null, 204);
}

async function meView(env, user) {
  const rewards = (await env.DB.prepare('SELECT milestone, film_id, claimed_at FROM rewards WHERE user_id = ? ORDER BY milestone').bind(user.id).all()).results;
  const reached = (await env.DB.prepare('SELECT milestone FROM eligibility WHERE user_id = ? ORDER BY milestone').bind(user.id).all()).results;
  const blocked = (await env.DB.prepare('SELECT blocked FROM blocks WHERE blocker = ?').bind(user.id).all()).results.map(r => r.blocked);
  return {
    // One's own requested name shows to oneself at once; others keep the old
    // one until it's approved, and a refusal says nothing (user 11/25).
    profile: { id: user.id, name: selfName(user), tz: user.tz },
    bio: selfBio(user),
    dmUnread: (await env.DB.prepare(DM_UNREAD).bind(user.id).first()).n,
    needsRename: !!user.must_rename,
    renameAfter: user.must_rename || !user.name_changed_at ? null
      : new Date(Date.parse(user.name_changed_at) + NAME_DAYS * 86400_000).toISOString(),
    streak: await streak(env, user),
    rewards: rewards.map(r => ({ milestone: r.milestone, filmId: r.film_id, claimedAt: r.claimed_at })),
    eligible: reached.map(r => r.milestone),   // reached for good, claimed or not
    blocked,
    isAdmin: !!user.is_admin,
    rulesAgreed: user.rules_version || 0,
    rulesCurrent: RULES_VERSION,
  };
}

/// Leaving: every row and every picture of theirs, and their sessions.
/// Every picture under a person's prefix.
async function purgePhotos(env, userId) {
  let cursor;
  do {
    const list = await env.PHOTOS.list({ prefix: userId + '/', cursor });
    if (list.objects.length) await env.PHOTOS.delete(list.objects.map(o => o.key));
    cursor = list.truncated ? list.cursor : undefined;
  } while (cursor);
}

async function leave(env, me) {
  // Rows first (sessions end at once, so no new upload starts); pictures
  // after; and the prefix is cleared again by the hourly job, for an upload
  // that was already on its way (retro 8).
  // Apple's grant revoked; if Apple can't be reached (or the key isn't set
  // yet), kept to revoke later — never lost, never claimed done.
  let apple = 'no-grant-kept';   // signed in before the key was set: nothing to revoke here
  // Rewards claimed stay claimed for this Apple account, even after leaving
  // (user 11/24: no claiming again by rebuilding). Only a hash is kept. Copied
  // in the same transaction that deletes the account (retro 8): a claim just
  // before is copied too, one just after finds no account.
  const subHash = await sha256hex('koco-departed:' + me.apple_sub);
  // Leaving first (retro 9): no claim can land from here on, so the list
  // of claimed milestones read next is final. Deleting again after an
  // interruption starts from here safely.
  await env.DB.prepare('UPDATE users SET leaving_at = COALESCE(leaving_at, ?) WHERE id = ?').bind(nowISO(), me.id).run();
  // The ledger then (C11): outside the database, so restoring D1 can't
  // bring the account back; with the milestones claimed, so a restore can't
  // give them again. If it can't be written, nothing is deleted.
  const claimedNow = (await env.DB.prepare('SELECT milestone FROM rewards WHERE user_id = ?').bind(me.id).all()).results.map(r => r.milestone);
  try {
    await env.PHOTOS.put(`ledger/deleted/${me.id}`, JSON.stringify({ subHash, milestones: claimedNow, at: nowISO() }));
  } catch (e) {
    console.error(JSON.stringify({ rid: clock.getStore()?.rid, error: 'ledger' }));
    fail(503, 'try-again');
  }
  const steps = [env.DB.prepare('INSERT OR IGNORE INTO departed_rewards (sub_hash, milestone) SELECT ?, milestone FROM rewards WHERE user_id = ?')
    .bind(subHash, me.id)];
  steps.push(env.DB.prepare('DELETE FROM users WHERE id = ?').bind(me.id));   // cascades
  steps.push(env.DB.prepare('INSERT OR REPLACE INTO pending_purges (user_id, passes, created_at) VALUES (?, 0, ?)').bind(me.id, nowISO()));
  if (me.apple_refresh) {
    const ok = hasAppleKey(env) && await revokeApple(env, me.apple_refresh).catch(() => false);
    apple = ok ? 'revoked' : 'pending';
    if (!ok) steps.push(env.DB.prepare('INSERT OR IGNORE INTO pending_revocations (refresh_token, created_at) VALUES (?, ?)').bind(me.apple_refresh, nowISO()));
  }
  await env.DB.batch(steps);
  await purgePhotos(env, me.id).catch(e => console.error('purge', e));
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
  const now = Math.floor(clockNow() / 1000);
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
  const { results } = await env.DB.prepare(
    "SELECT p.*, u.name AS author_name, 0 AS liked FROM posts p JOIN users u ON u.id = p.author WHERE p.state = 'pending' ORDER BY p.created_at ASC LIMIT 60").all();
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
  const window = Math.floor(clockNow() / 1000 / seconds);
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
    ['queue', waiting.n >= 50 || (waiting.oldest && clockNow() - Date.parse(waiting.oldest) > 12 * 3600_000), String(waiting.n)],
    ['reports', open.n >= 10, String(open.n)],
    // A business-volume warning, not a byte meter: R2's free 10 GB is about
    // 5,000 posts at ~2 MB with room to spare (Cloudflare's own usage
    // notifications are the real meter, set in its dashboard).
    ['storage', stored.n >= 4000, String(stored.n)],
  ];
  for (const [kind, hit, text] of checks) {
    if (!hit) continue;
    const r = await env.DB.prepare('INSERT OR IGNORE INTO alerts (kind, day, text, created_at) VALUES (?, ?, ?, ?)').bind(kind, day, text, nowISO()).run();
    if (r.meta.changes) await notify(env, kind, `${kind}: ${text}`, day);   // once a day each
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

// ---------------------------------------------------------------- rewards

/// A milestone's roll, once per Apple account: reached (kept for good, even
/// after the run breaks), not claimed yet, not claimed by this Apple account
/// before it left (user 11/24). Claiming again returns the same roll.
async function claimReward(request, env, me, milestone) {
  const m0 = MILESTONES.find(([days]) => days === milestone);
  if (!m0) fail(400, 'milestone');
  // Someone who already has the milestone's roll (bought, or all films: the
  // phone knows, not the server) takes a voucher for a roll instead (user 11/24).
  const b = await request.json().catch(() => ({}));
  // Owning all films (the phone knows): a keepsake badge instead (user 11/24).
  const m = milestone === 3 && b.badge === true ? [milestone, BADGE]
          : milestone === 3 && b.voucher === true ? [milestone, VOUCHER] : m0;
  const had = await env.DB.prepare('SELECT film_id FROM rewards WHERE user_id = ? AND milestone = ?').bind(me.id, milestone).first();
  if (had) return json({ filmId: had.film_id });
  const subHash = await sha256hex('koco-departed:' + me.apple_sub);
  // Checked and written in one statement: a reward exists only if the
  // milestone is still reached at that moment (a quick delete may take it
  // back) and this Apple account never had it before leaving (retro: C5).
  const res = await env.DB.prepare(
    `INSERT OR IGNORE INTO rewards (user_id, milestone, film_id, claimed_at)
     SELECT ?, ?, ?, ? WHERE EXISTS (SELECT 1 FROM eligibility WHERE user_id = ? AND milestone = ?)
       AND NOT EXISTS (SELECT 1 FROM departed_rewards WHERE sub_hash = ? AND milestone = ?)
       AND EXISTS (SELECT 1 FROM users WHERE id = ? AND leaving_at IS NULL) -- not while leaving (retro 9)
    `
  ).bind(me.id, milestone, m[1], nowISO(), me.id, milestone, subHash, milestone, me.id).run();
  if (!res.meta.changes) {
    const now = await env.DB.prepare('SELECT film_id FROM rewards WHERE user_id = ? AND milestone = ?').bind(me.id, milestone).first();
    if (now) return json({ filmId: now.film_id });   // a claim at the same moment won
    const before = await env.DB.prepare('SELECT 1 FROM departed_rewards WHERE sub_hash = ? AND milestone = ?').bind(subHash, milestone).first();
    fail(409, before ? 'claimed-before' : 'not-yet');
  }
  return json({ filmId: m[1] });
}

const VOUCHER = 'voucher';
const BADGE = 'badge';   // the 3-day keepsake for those who own every roll
// The community rules' version: raising it asks everyone to agree again
// before they next post or comment (C4a).
const RULES_VERSION = 2;   // 2 (11/25): rule 7, on letters
function needRules(me) { if ((me.rules_version || 0) < RULES_VERSION) fail(428, 'rules'); }
// What a voucher can become: the regular paid rolls (from films.json; add
// a new paid roll here when it ships). Never a free or a limited one.
const VOUCHER_ROLLS = new Set(["c200", "ccd", "cine500t", "doublex", "ektachrome", "fp100c", "grneg", "kodachrome64", "natura1600", "portra400", "pro400h", "velvia50", "vista100"]);

/// A voucher turned into a roll, once: one the person doesn't have yet
/// (any paid roll now, or a new one later if they have every roll).
async function redeemVoucher(request, env, me, milestone) {
  const b = await request.json().catch(() => ({}));
  const film = typeof b.filmId === 'string' ? b.filmId : '';
  // A regular paid roll, or the badge (a voucher with no roll left to become).
  if (!VOUCHER_ROLLS.has(film) && film !== BADGE) fail(400, 'film');   // refused before anything is spent
  const res = await env.DB.prepare('UPDATE rewards SET film_id = ?, claimed_at = ? WHERE user_id = ? AND milestone = ? AND film_id = ?')
    .bind(film, nowISO(), me.id, milestone, VOUCHER).run();
  if (!res.meta.changes) {
    const had = await env.DB.prepare('SELECT film_id FROM rewards WHERE user_id = ? AND milestone = ?').bind(me.id, milestone).first();
    if (had && had.film_id === film) return json({ filmId: film });   // the same request again
    fail(409, 'no-voucher');
  }
  return json({ filmId: film });
}

// ---------------------------------------------------------------- uploads

/// An upload: its two pictures go to private R2 under the person's own id.
async function newUpload(env, me) {
  const recent = await env.DB.prepare('SELECT count(*) AS n FROM uploads WHERE user_id = ? AND created_at > ?')
    .bind(me.id, new Date(clockNow() - 3600_000).toISOString()).first();
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
    .bind(new Date(clockNow() - 86400_000).toISOString()).all()).results;
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
  needRules(me);
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
    .bind(me.id, new Date(clockNow() - 86400_000).toISOString()).first();
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

/// A post as the app sees it. Lists pass rows that already carry the
/// author's name and the like (one query a page, C12: the free plan allows
/// 50 queries a request); a single post looks them up.
async function postView(env, url, me, p) {
  // One's own pictures carry the name one sees of oneself (asked for, or turned down).
  const authorName = p.author === me.id ? selfName(me) : p.author_name !== undefined ? p.author_name
    : (await env.DB.prepare('SELECT name FROM users WHERE id = ?').bind(p.author).first())?.name;
  const liked = p.liked !== undefined ? p.liked
    : !!(await env.DB.prepare('SELECT 1 FROM likes WHERE post_id = ? AND user_id = ?').bind(p.id, me.id).first());
  return {
    id: p.id, author: { id: p.author, name: authorName }, themeId: p.theme_id,
    // Admins, and the author for their own (hidden ones too: the review is never felt).
    photoURL: await photoLink(env, url, p.id, 'full', me.is_admin || p.author === me.id),
    thumbURL: await photoLink(env, url, p.id, 'thumb', me.is_admin || p.author === me.id),
    filmId: p.film_id, caption: p.caption || undefined, takenAt: p.taken_at || undefined, createdAt: p.created_at,
    likeCount: p.like_count, likedByMe: !!liked, state: p.state,
  };
}

/// A theme's posts, newest first, a page at a time: public ones, without
/// those of people I blocked; my own waiting ones on the first page.
async function themePosts(url, env, me, themeId, filmId = null, following = false, authorId = null) {
  const limit = Math.min(Math.max(Number(url.searchParams.get('limit')) || 30, 1), 60);
  const cursor = url.searchParams.get('cursor');   // "<createdAt>|<id>" of the last one shown
  let [cAt, cId] = cursor ? cursor.split('|') : ['9999', ''];
  if (!cAt || cId === undefined) fail(400, 'cursor');
  const { results } = await env.DB.prepare(
    `SELECT p.*, u.name AS author_name, EXISTS (SELECT 1 FROM likes l WHERE l.post_id = p.id AND l.user_id = ?) AS liked
     FROM posts p JOIN users u ON u.id = p.author
     WHERE (? IS NULL OR p.theme_id = ?) AND (? IS NULL OR p.film_id = ?)
       AND (? = 0 OR p.author IN (SELECT followee FROM follows WHERE follower = ?))
       AND (? IS NULL OR p.author = ?)
       AND (p.state = 'public' OR (p.author = ? AND ? = 0))   -- one's own always, whatever its review (user 11/24); not in the following feed
       AND p.author NOT IN (SELECT blocked FROM blocks WHERE blocker = ?)
       AND (p.created_at < ? OR (p.created_at = ? AND p.id < ?))
     ORDER BY p.created_at DESC, p.id DESC LIMIT ?`
  ).bind(me.id, themeId, themeId, filmId || null, filmId || null, following ? 1 : 0, me.id, authorId, authorId, me.id, following ? 1 : 0,
         me.id, cAt, cAt, cId || '￿', limit + 1).all();
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
  if (p.approved_at && p.approved_day && clockNow() - Date.parse(p.approved_at) < QUICK_DELETE_MS) {
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
    const mine = 'SELECT 1 FROM posts WHERE id = ? AND approved_stamp = ?';
    // The run of days ending on this one, counted in the database itself, in
    // the same transaction as the day it adds (retro 8): what another
    // approval or a quick delete wrote just before is what it counts.
    const run = `(WITH RECURSIVE run(d) AS (
                    SELECT ? WHERE EXISTS (SELECT 1 FROM checkins WHERE user_id = ? AND day = ?)
                    UNION ALL SELECT date(d, '-1 day') FROM run
                    WHERE EXISTS (SELECT 1 FROM checkins WHERE user_id = ? AND day = date(d, '-1 day')))
                  SELECT count(*) FROM run)`;
    await env.DB.batch([
      log,
      env.DB.prepare("UPDATE posts SET state = 'public', approved_at = ?, approved_day = ?, approved_stamp = ? WHERE id = ? AND approved_at IS NULL")
        .bind(at, day, stamp, id),
      env.DB.prepare(`INSERT OR IGNORE INTO checkins (user_id, day) SELECT ?, ? WHERE EXISTS (${mine})`).bind(author.id, day, id, stamp),
      ...MILESTONES.map(([days]) =>
        env.DB.prepare(`INSERT OR IGNORE INTO eligibility (user_id, milestone, reached_at)
                        SELECT ?, ?, ? WHERE EXISTS (${mine}) AND ${run} >= ?`)
          .bind(author.id, days, at, id, stamp, day, author.id, day, author.id, days)),
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
  if (p.state !== 'public' && p.author !== me.id) fail(409, 'not-public');
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
  const added = await env.DB.prepare('INSERT OR IGNORE INTO reports (post_id, reporter, reason, note, created_at) VALUES (?, ?, ?, ?, ?)')
    .bind(id, me.id, b.reason, note, nowISO()).run();
  // Each new report is an alert for the admins, and goes out by email: one
  // message an hour however many come (C6a).
  await env.DB.prepare('INSERT OR IGNORE INTO alerts (kind, day, text, created_at) VALUES (?, ?, ?, ?)')
    .bind('report:' + id + ':' + me.id, nowISO().slice(0, 10), b.reason, nowISO()).run();
  if (added.meta.changes) await notify(env, 'report', `${b.reason} on picture ${id}`);   // a repeat is no new report
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
    // Blocking ends following both ways (S1).
    await env.DB.batch([
      env.DB.prepare('INSERT OR IGNORE INTO blocks (blocker, blocked, created_at) VALUES (?, ?, ?)').bind(me.id, userId, nowISO()),
      env.DB.prepare('DELETE FROM follows WHERE (follower = ? AND followee = ?) OR (follower = ? AND followee = ?)').bind(me.id, userId, userId, me.id),
    ]);
  } else {
    await env.DB.prepare('DELETE FROM blocks WHERE blocker = ? AND blocked = ?').bind(me.id, userId).run();
  }
  return json(null, 204);
}

// ---------------------------------------------------------------- author page (S2)

/// Someone one may look at: there, not banned, not leaving, no block either way.
async function visibleAuthor(env, me, id) {
  const u = await env.DB.prepare(
    `SELECT id, name, bio, created_at FROM users WHERE id = ? AND banned = 0 AND leaving_at IS NULL
       AND NOT EXISTS (SELECT 1 FROM blocks WHERE (blocker = ? AND blocked = users.id) OR (blocker = users.id AND blocked = ?))`
  ).bind(id, me.id, me.id).first();
  if (!u) fail(404, 'not-found');
  return u;
}

/// Their name (as others see it), the film they use most and how many films
/// they have shot, from their public pictures only (user 11/25: no counts of
/// people, just their films); and whether I follow them.
async function authorCard(env, me, id) {
  const u = await visibleAuthor(env, me, id);
  const films = (await env.DB.prepare(
    `SELECT film_id, count(*) AS n, max(created_at) AS last FROM posts WHERE author = ? AND state = 'public'
     GROUP BY film_id ORDER BY n DESC, last DESC`).bind(id).all()).results;
  const followed = !!(await env.DB.prepare('SELECT 1 FROM follows WHERE follower = ? AND followee = ?').bind(me.id, id).first());
  return json({ id: u.id, name: u.id === me.id ? selfName(me) : u.name, bio: (u.id === me.id ? selfBio(me) : u.bio) || null, topFilm: films[0]?.film_id ?? null, films: films.length, followed, since: u.created_at });
}

// ---------------------------------------------------------------- following (S1)

/// At most this many followed: the list one gets back is always all of them.
const FOLLOW_MAX = 500;

/// Following someone (or not any more). Not oneself, nobody blocked either
/// way, nobody banned or leaving. Repeating it changes nothing.
async function follow(env, me, userId, on) {
  if (userId === me.id) fail(400, 'self');
  if (on) {
    await rateLimit(env, me, 'follow', 200, 86400);
    // One statement: no block either way and the account still there, checked
    // as the row goes in (a block landing in between can't leave one behind).
    const r = await env.DB.prepare(
      `INSERT OR IGNORE INTO follows (follower, followee, created_at)
       SELECT ?, ?, ? WHERE EXISTS (SELECT 1 FROM users WHERE id = ? AND banned = 0 AND leaving_at IS NULL)
         AND NOT EXISTS (SELECT 1 FROM blocks WHERE (blocker = ? AND blocked = ?) OR (blocker = ? AND blocked = ?))
         AND (SELECT count(*) FROM follows WHERE follower = ?) < ?`
    ).bind(me.id, userId, nowISO(), userId, me.id, userId, userId, me.id, me.id, FOLLOW_MAX).run();
    if (r.meta.changes !== 1) {
      const already = await env.DB.prepare('SELECT 1 FROM follows WHERE follower = ? AND followee = ?').bind(me.id, userId).first();
      if (already) return json(null, 204);
      const n = (await env.DB.prepare('SELECT count(*) AS n FROM follows WHERE follower = ?').bind(me.id).first()).n;
      fail(n >= FOLLOW_MAX ? 409 : 404, n >= FOLLOW_MAX ? 'too-many' : 'not-found');
    }
  } else {
    await env.DB.prepare('DELETE FROM follows WHERE follower = ? AND followee = ?').bind(me.id, userId).run();
  }
  return json(null, 204);
}

/// Who I follow, or who follows me: only for me, newest first, no totals
/// anywhere else. Nobody blocked, banned or leaving.
async function followList(env, me, which) {
  const [mine, other] = which === 'following' ? ['follower', 'followee'] : ['followee', 'follower'];
  const rows = (await env.DB.prepare(
    `SELECT u.id, u.name, f.created_at FROM follows f JOIN users u ON u.id = f.${other}
     WHERE f.${mine} = ? AND u.banned = 0 AND u.leaving_at IS NULL
       AND u.id NOT IN (SELECT blocked FROM blocks WHERE blocker = ?)
     ORDER BY f.created_at DESC LIMIT 500`).bind(me.id, me.id).all()).results;
  return json({ people: rows.map(r => ({ id: r.id, name: r.name, since: r.created_at })) });
}

// ---------------------------------------------------------------- outbox (C6a)

const OUTBOX_MAX_TRIES = 8;
const SUBJECTS = { report: 'Koco: new reports', queue: 'Koco: pictures waiting', reports: 'Koco: open reports',
                   'posts-today': 'Koco: a busy day', storage: 'Koco: storage nearing the free plan' };

/// A message for the admins, merged by kind and hour (or the given bucket):
/// a second one in the same hour adds a line to the first.
async function notify(env, kind, line, bucket) {
  const key = `${kind}:${bucket || nowISO().slice(0, 13)}`;
  await env.DB.prepare(
    `INSERT INTO outbox (kind, merge_key, subject, body, next_at, created_at) VALUES (?, ?, ?, ?, ?, ?)
     ON CONFLICT(merge_key) DO UPDATE SET body = body || char(10) || excluded.body, count = count + 1, version = version + 1,
       attempts = CASE WHEN state IN ('sent', 'failed') THEN 0 ELSE attempts END,
       next_at = CASE WHEN state IN ('sent', 'failed') THEN excluded.next_at ELSE next_at END,
       state = CASE WHEN state IN ('sent', 'failed') THEN 'pending' ELSE state END`
  ).bind(kind, key, SUBJECTS[kind] || 'Koco', line, nowISO(), nowISO()).run();
  // Try now, past the response; the hourly job tries again whatever's left.
  clock.getStore()?.ctx?.waitUntil?.(drainOutbox(env).catch(e => console.error('outbox', e)));
}

/// How it's sent: Cloudflare's email binding once a sending domain is set
/// (SEND_EMAIL, MAIL_FROM, REPORT_EMAIL); on a test Worker a fake that keeps
/// a record and can fail on purpose; otherwise nothing (it waits, untried).
async function sendMail(env, subject, body) {
  if (env.SEND_EMAIL && env.MAIL_FROM && env.REPORT_EMAIL) {
    const { EmailMessage } = await import('cloudflare:email');
    const raw = [`From: Koco <${env.MAIL_FROM}>`, `To: ${env.REPORT_EMAIL}`, `Subject: ${subject}`,
                 'Content-Type: text/plain; charset=utf-8', '', body].join('\r\n');
    await env.SEND_EMAIL.send(new EmailMessage(env.MAIL_FROM, env.REPORT_EMAIL, raw));
    return 'sent';
  }
  if (env.TEST_LOGIN) {
    const flag = await env.DB.prepare("UPDATE test_flags SET n = n - 1 WHERE key = 'fail' AND n > 0 RETURNING n").first();
    if (flag) throw new Error('fake failure');
    await env.DB.prepare('INSERT INTO test_mail (subject, body, at) VALUES (?, ?, ?)').bind(subject, body, nowISO()).run();
    return 'sent';
  }
  return null;   // no way to send yet
}

/// Sends what's due: a failure waits 2, 4, 8… minutes (up to six hours),
/// and is given up after eight tries.
async function drainOutbox(env) {
  if (!(env.SEND_EMAIL && env.MAIL_FROM && env.REPORT_EMAIL) && !env.TEST_LOGIN) {
    // No way to send yet: everything waits, untried.
    await env.DB.prepare("UPDATE outbox SET last_error = 'no-sender' WHERE state = 'pending'").run();
    return;
  }
  const now = nowISO();
  const { results } = await env.DB.prepare(
    "SELECT id FROM outbox WHERE state IN ('pending', 'sending') AND next_at <= ? ORDER BY id LIMIT 20").bind(now).all();
  for (const { id } of results) {
    // Taken by one sender only, for ten minutes (a sender that died lets it go).
    const row = await env.DB.prepare(
      "UPDATE outbox SET state = 'sending', next_at = ? WHERE id = ? AND state IN ('pending', 'sending') AND next_at <= ? RETURNING *"
    ).bind(new Date(clockNow() + 600_000).toISOString(), id, now).first();
    if (!row) continue;
    const fresh = row.body.slice(row.sent_len).replace(/^\n/, '');   // only what hasn't gone out
    try {
      // Numbered: if a send went out but its record didn't, the repeat is recognisable.
      await sendMail(env, `${row.subject} (${fresh.split('\n').length}) [#${row.id}.${row.version}]`, fresh);
      // Sent what was taken; lines added meanwhile go next time.
      await env.DB.prepare(
        `UPDATE outbox SET state = CASE WHEN version = ? THEN 'sent' ELSE 'pending' END, sent_len = ?, sent_at = ?,
           attempts = 0, last_error = NULL, next_at = ? WHERE id = ?`
      ).bind(row.version, row.body.length, nowISO(), nowISO(), id).run();
    } catch (e) {
      const tries = row.attempts + 1;
      const wait = Math.min(2 ** tries, 360) * 60_000;
      await env.DB.prepare('UPDATE outbox SET attempts = ?, state = ?, next_at = ?, last_error = ? WHERE id = ?')
        .bind(tries, tries >= OUTBOX_MAX_TRIES ? 'failed' : 'pending', new Date(clockNow() + wait).toISOString(),
              String(e && e.message || e).slice(0, 200), id).run();
    }
  }
}

/// After restoring the database to an earlier point (runbook-backup.md):
/// every account deleted since is deleted again, its no-claiming-again
/// record put back, its pictures cleared. Safe to run any time.
async function replayDeletions(env, me) {
  let cursor, again = 0, unpurged = 0;
  do {
    const list = await env.PHOTOS.list({ prefix: 'ledger/deleted/', cursor });
    for (const o of list.objects) {
      const userId = o.key.split('/').pop();
      const entry = await (await env.PHOTOS.get(o.key))?.json().catch(() => null);
      const steps = [];
      if (entry?.subHash) {
        // The milestones as the ledger has them, and any the restored rows hold.
        for (const m of entry.milestones || []) steps.push(env.DB.prepare(
          'INSERT OR IGNORE INTO departed_rewards (sub_hash, milestone) VALUES (?, ?)').bind(entry.subHash, m));
        steps.push(env.DB.prepare(
          'INSERT OR IGNORE INTO departed_rewards (sub_hash, milestone) SELECT ?, milestone FROM rewards WHERE user_id = ?').bind(entry.subHash, userId));
      }
      steps.push(env.DB.prepare('DELETE FROM users WHERE id = ?').bind(userId));
      const done = await env.DB.batch(steps);
      if (done[done.length - 1].meta.changes) again++;
      // A clearing that fails is kept for the hourly job, and said.
      const ok = await purgePhotos(env, userId).then(() => true, () => false);
      if (!ok) {
        unpurged++;
        await env.DB.prepare('INSERT OR REPLACE INTO pending_purges (user_id, passes, created_at) VALUES (?, 0, ?)').bind(userId, nowISO()).run();
      }
    }
    cursor = list.truncated ? list.cursor : undefined;
  } while (cursor);
  await env.DB.batch([logStep(env, me, 'replay-deletions', 'db', String(again), unpurged ? `unpurged ${unpurged}` : null)]);
  return json({ deletedAgain: again, picturesStillToClear: unpurged, complete: unpurged === 0 });
}

/// What admins should see at a glance: what waits, since when, and mail.
async function adminStatus(env) {
  const q = await env.DB.prepare("SELECT count(*) AS n, min(created_at) AS oldest FROM posts WHERE state = 'pending'").first();
  const c = await env.DB.prepare("SELECT count(*) AS n, min(created_at) AS oldest FROM comments WHERE state = 'pending'").first();
  const r = await env.DB.prepare(
    'SELECT (SELECT count(*) FROM reports WHERE handled = 0) + (SELECT count(*) FROM comment_reports WHERE handled = 0) AS n').first();
  const o = await env.DB.prepare(
    "SELECT sum(state IN ('pending', 'sending')) AS pending, sum(state = 'failed') AS failed, max(sent_at) AS last_sent, max(last_error) AS last_error FROM outbox").first();
  return json({ pictures: { waiting: q.n, oldest: q.oldest || undefined },
                comments: { waiting: c.n, oldest: c.oldest || undefined }, openReports: r.n,
                mail: { pending: o.pending || 0, failed: o.failed || 0, lastSent: o.last_sent || undefined,
                        configured: !!(env.SEND_EMAIL && env.MAIL_FROM && env.REPORT_EMAIL), lastError: o.last_error || undefined } });
}

// ---------------------------------------------------------------- comments

/// A comment as one person sees it.
function commentView(c, me) {
  return { id: c.id, postId: c.post_id, author: { id: c.author, name: c.author === me.id ? selfName(me) : c.author_name }, text: c.text,
           createdAt: c.created_at, state: c.state, mine: c.author === me.id };
}

/// Blocking hides both ways (retro 7): neither sees the other's comments.
const NOT_BLOCKED = `c.author NOT IN (SELECT blocked FROM blocks WHERE blocker = ?)
                    AND c.author NOT IN (SELECT blocker FROM blocks WHERE blocked = ?)`;

/// A public picture's comments, oldest first (it reads as a conversation),
/// with one's own waiting ones; none while the picture itself isn't public.
async function listComments(env, url, me, postId) {
  const p = await visiblePost(env, me, postId);
  if (p.state !== 'public' && !me.is_admin && p.author !== me.id) return json({ comments: [] });
  const after = url.searchParams.get('cursor') || '';
  const { results } = await env.DB.prepare(
    `SELECT c.*, u.name AS author_name FROM comments c JOIN users u ON u.id = c.author
     WHERE c.post_id = ? AND (c.state = 'public' OR c.author = ?)
       AND ${NOT_BLOCKED} AND (c.created_at || '|' || c.id) > ?
     ORDER BY c.created_at, c.id LIMIT 51`).bind(postId, me.id, me.id, me.id, after).all();
  const page = results.slice(0, 50), last = page[page.length - 1];
  return json({ comments: page.map(c => commentView(c, me)),
                next: results.length > 50 ? `${last.created_at}|${last.id}` : undefined });
}

/// A comment, once per client id; it waits for approval like a post.
async function addComment(request, env, me, postId) {
  needRules(me);
  const b = await request.json().catch(() => ({}));
  if (typeof b.clientId !== 'string' || !/^[A-Za-z0-9-]{8,64}$/.test(b.clientId)) fail(400, 'client-id');
  const again = await env.DB.prepare('SELECT c.*, u.name AS author_name FROM comments c JOIN users u ON u.id = c.author WHERE c.author = ? AND c.client_id = ?')
    .bind(me.id, b.clientId).first();
  if (again) return json(commentView(again, me));
  const p = await visiblePost(env, me, postId);
  // On one's own picture still in review, writing works as anywhere (user 11/24:
  // nobody should notice the review); it shows to others once both are out.
  if (p.state !== 'public' && p.author !== me.id) fail(409, 'not-public');
  const text = typeof b.text === 'string' ? b.text.replace(/\s+/g, ' ').trim() : '';
  if (!text || [...text].length > 120 || badWords(text) || /https?:\/\/|www\./i.test(text)) fail(422, 'words');
  // Someone who blocked the commenter, or whom they blocked, isn't written to.
  const blocked = await env.DB.prepare('SELECT 1 FROM blocks WHERE (blocker = ? AND blocked = ?) OR (blocker = ? AND blocked = ?)')
    .bind(p.author, me.id, me.id, p.author).first();
  if (blocked) fail(403, 'blocked');
  await rateLimit(env, me, 'comment', 30, 86400);
  const id = crypto.randomUUID();
  await env.DB.prepare('INSERT INTO comments (id, post_id, author, text, client_id, created_at) VALUES (?, ?, ?, ?, ?, ?)')
    .bind(id, postId, me.id, text, b.clientId, nowISO()).run();
  return json(commentView({ id, post_id: postId, author: me.id, author_name: me.name, text, created_at: nowISO(), state: 'pending' }, me), 201);
}

/// The commenter, the picture's author, or an admin.
async function deleteComment(env, me, id) {
  const c = await env.DB.prepare('SELECT c.*, p.author AS post_author FROM comments c JOIN posts p ON p.id = c.post_id WHERE c.id = ?').bind(id).first();
  if (!c || !(c.author === me.id || c.post_author === me.id || me.is_admin)) fail(404, 'not-found');
  const steps = [env.DB.prepare('DELETE FROM comments WHERE id = ?').bind(id)];
  if (me.is_admin && c.author !== me.id && c.post_author !== me.id) steps.push(logStep(env, me, 'delete', 'comment', id, null));
  await env.DB.batch(steps);
  return json(null, 204);
}

/// Reporting a comment; three people hide it until an admin looks.
async function reportComment(request, env, me, id) {
  const b = await request.json().catch(() => ({}));
  if (!REASONS.includes(b.reason)) fail(400, 'reason');
  await rateLimit(env, me, 'report', 30, 86400);
  const c = await env.DB.prepare("SELECT * FROM comments WHERE id = ? AND state = 'public'").bind(id).first();
  if (!c) fail(404, 'not-found');
  const done = await env.DB.batch([
    env.DB.prepare('INSERT OR IGNORE INTO comment_reports (comment_id, reporter, reason, created_at) VALUES (?, ?, ?, ?)').bind(id, me.id, b.reason, nowISO()),
    env.DB.prepare('INSERT OR IGNORE INTO alerts (kind, day, text, created_at) VALUES (?, ?, ?, ?)')
      .bind('comment-report:' + id + ':' + me.id, nowISO().slice(0, 10), b.reason, nowISO()),
    env.DB.prepare(`UPDATE comments SET state = 'hidden' WHERE id = ? AND state = 'public'
                    AND (SELECT count(*) FROM comment_reports WHERE comment_id = ? AND handled = 0) >= 3`).bind(id, id),
  ]);
  if (done[0].meta.changes) await notify(env, 'report', `${b.reason} on comment ${id}`);
  return json(null, 204);
}

/// Comments waiting, reported or hidden, each with its picture's id.
async function adminComments(env, url) {
  const which = url.searchParams.get('state') || 'pending';
  const where = which === 'reported'
    ? "c.id IN (SELECT comment_id FROM comment_reports WHERE handled = 0)"
    : which === 'hidden' ? "c.state = 'hidden'" : "c.state = 'pending'";
  const { results } = await env.DB.prepare(
    `SELECT c.*, u.name AS author_name,
            (SELECT group_concat(reason) FROM comment_reports r WHERE r.comment_id = c.id AND r.handled = 0) AS reasons
     FROM comments c JOIN users u ON u.id = c.author WHERE ${where} ORDER BY c.created_at LIMIT 100`).all();
  return json(results.map(c => ({ ...commentView(c, { id: '' }), reasons: c.reasons ? c.reasons.split(',') : [] })));
}

/// One's own pictures and comments, whatever their state (C10): what waits,
/// what was turned down, what is out.
async function mine(env, url, me) {
  const posts = (await env.DB.prepare(
    `SELECT p.*, ? AS author_name, EXISTS (SELECT 1 FROM likes l WHERE l.post_id = p.id AND l.user_id = ?) AS liked
     FROM posts p WHERE p.author = ? ORDER BY p.created_at DESC LIMIT 60`).bind(selfName(me), me.id, me.id).all()).results;
  const comments = (await env.DB.prepare(
    `SELECT c.*, u.name AS author_name FROM comments c JOIN users u ON u.id = c.author
     WHERE c.author = ? AND c.state != 'public' ORDER BY c.created_at DESC LIMIT 30`).bind(me.id).all()).results;
  return json({ posts: await Promise.all(posts.map(p => postView(env, url, me, p))),
                comments: comments.map(c => commentView(c, me)) });
}

/// Some of my own posts by id, whatever their age (the film album asks for
/// the ones its pictures went into, retro 10): only mine, at most 20; one
/// not returned was deleted (or is someone else's).
async function myPosts(env, url, me) {
  const ids = (url.searchParams.get('ids') || '').split(',').map(s => s.trim()).filter(Boolean);
  if (ids.length === 0) return json({ posts: [] });
  if (ids.length > 20) fail(400, 'too-many');
  const marks = ids.map(() => '?').join(',');
  const posts = (await env.DB.prepare(
    `SELECT p.*, ? AS author_name, EXISTS (SELECT 1 FROM likes l WHERE l.post_id = p.id AND l.user_id = ?) AS liked
     FROM posts p WHERE p.author = ? AND p.id IN (${marks})`).bind(selfName(me), me.id, me.id, ...ids).all()).results;
  return json({ posts: await Promise.all(posts.map(p => postView(env, url, me, p))) });
}

/// What's new for me since I last looked: approved comments on my pictures
/// (others'). Nothing about one's own review (C16).
async function news(env, url, me) {
  const row = await env.DB.prepare('SELECT at FROM seen WHERE user_id = ?').bind(me.id).first();
  const since = row ? row.at : '1970';
  const onMine = (await env.DB.prepare(
    `SELECT c.*, u.name AS author_name FROM comments c JOIN posts p ON p.id = c.post_id JOIN users u ON u.id = c.author
     WHERE p.author = ? AND p.state = 'public' AND c.author != ? AND c.state = 'public' AND c.approved_at > ? AND ${NOT_BLOCKED}
     ORDER BY c.approved_at DESC LIMIT 30`).bind(me.id, me.id, since, me.id, me.id).all()).results;
  // No count of one's own pictures approved: that would let the review be
  // felt (C16, retro 10); only what others did shows, and opens to something.
  return json({ comments: onMine.map(c => commentView(c, me)), postsApproved: 0,
                count: onMine.length });
}

/// S4 notices, worked out when asked (no table of notices): others' public
/// comments on my public pictures, likes merged per picture (each person
/// once), new followers merged per day. Never one's own review or one's own
/// doings; nobody blocked either way, banned or leaving. Darkroom picks have no
/// real source yet, so the kind doesn't appear. The last 30 days, 30 a page.
/// Each kind is sorted and paged in the database, then the three are merged,
/// so nothing past a row limit is ever out of reach.
/// "Read" means shown: the app acknowledges each notice it showed (its key and
/// time); a group that grows later (a new like) is unread again. Nothing it
/// didn't show is marked.
const NOTICE_DAYS = 30, NOTICE_PAGE = 30;
const ACTOR_OK = (col) => `${col} != ? AND ${col} IN (SELECT id FROM users WHERE banned = 0 AND leaving_at IS NULL)
  AND ${col} NOT IN (SELECT blocked FROM blocks WHERE blocker = ?) AND ${col} NOT IN (SELECT blocker FROM blocks WHERE blocked = ?)`;
// Each kind as rows of (key, at, ...), newest first.
const NOTICE_SQL = {
  comment: `SELECT 'c:' || c.id AS key, c.approved_at AS at, c.post_id, c.text, c.author AS who, u.name, 1 AS n
    FROM comments c JOIN posts p ON p.id = c.post_id JOIN users u ON u.id = c.author
    WHERE p.author = ?1 AND p.state = 'public' AND c.state = 'public' AND c.approved_at > ?2
      AND ${ACTOR_OK('c.author').replace(/\?/g, '?1')}`,
  likes: `SELECT 'l:' || l.post_id AS key, MAX(l.created_at) AS at, l.post_id, NULL AS text, NULL AS who, NULL AS name, COUNT(*) AS n
    FROM likes l JOIN posts p ON p.id = l.post_id
    WHERE p.author = ?1 AND p.state = 'public' AND l.created_at > ?2 AND ${ACTOR_OK('l.user_id').replace(/\?/g, '?1')}
    GROUP BY l.post_id`,
  follows: `SELECT 'f:' || substr(f.created_at, 1, 10) AS key, MAX(f.created_at) AS at, NULL AS post_id, NULL AS text, NULL AS who, NULL AS name, COUNT(*) AS n
    FROM follows f WHERE f.followee = ?1 AND f.created_at > ?2 AND ${ACTOR_OK('f.follower').replace(/\?/g, '?1')}
    GROUP BY substr(f.created_at, 1, 10)`,
};
// A notice's version is its time and how many it holds: a like landing in the
// same millisecond still makes the group new.
const UNREAD = `NOT EXISTS (SELECT 1 FROM notice_marks r WHERE r.user_id = ?1 AND r.key = k.key
  AND (r.at > k.at OR (r.at = k.at AND r.n >= k.n)))`;

async function notices(env, url, me) {
  const since = new Date(clockNow() - NOTICE_DAYS * 86400000).toISOString();
  const cur = url.searchParams.get('cursor') || '';
  const bar = cur.indexOf('|');
  const cAt = bar > 0 ? cur.slice(0, bar) : '9999', cKey = bar > 0 ? cur.slice(bar + 1) : '\uffff';
  const older = `(k.at < ?3 OR (k.at = ?3 AND k.key < ?4))`;
  const kinds = Object.keys(NOTICE_SQL);
  const pages = await env.DB.batch([
    ...kinds.map(kind => env.DB.prepare(
      `SELECT k.*, ${UNREAD} AS unread FROM (${NOTICE_SQL[kind]}) k WHERE ${older} ORDER BY k.at DESC, k.key DESC LIMIT ${NOTICE_PAGE + 1}`
    ).bind(me.id, since, cAt, cKey)),
    env.DB.prepare(`SELECT COUNT(*) AS n FROM (${kinds.map(kind => `SELECT * FROM (${NOTICE_SQL[kind]})`).join(' UNION ALL ')}) k
      WHERE ${UNREAD} LIMIT 1`).bind(me.id, since),
  ]);
  const unreadTotal = Math.min(99, pages[kinds.length].results[0]?.n || 0);
  const merged = kinds.flatMap((kind, i) => pages[i].results.map(r => ({ kind, ...r })))
    .sort((a, b) => (a.at === b.at ? (a.key < b.key ? 1 : -1) : (a.at < b.at ? 1 : -1)));
  const page = merged.slice(0, NOTICE_PAGE);
  // The first two names of each group on this page (newest first).
  const likePosts = page.filter(i => i.kind === 'likes').map(i => i.post_id);
  const followDays = page.filter(i => i.kind === 'follows').map(i => i.key.slice(2));
  const names = new Map();
  const people = [];
  if (likePosts.length) people.push(env.DB.prepare(
    `SELECT 'l:' || post_id AS key, who, name FROM (SELECT l.post_id, l.user_id AS who, u.name,
       ROW_NUMBER() OVER (PARTITION BY l.post_id ORDER BY l.created_at DESC) AS rn
       FROM likes l JOIN users u ON u.id = l.user_id
       WHERE l.post_id IN (${likePosts.map(() => '?').join(',')}) AND l.created_at > ? AND ${ACTOR_OK('l.user_id')}) WHERE rn <= 2`
  ).bind(...likePosts, since, me.id, me.id, me.id));
  if (followDays.length) people.push(env.DB.prepare(
    `SELECT 'f:' || day AS key, who, name FROM (SELECT substr(f.created_at, 1, 10) AS day, f.follower AS who, u.name,
       ROW_NUMBER() OVER (PARTITION BY substr(f.created_at, 1, 10) ORDER BY f.created_at DESC) AS rn
       FROM follows f JOIN users u ON u.id = f.follower
       WHERE f.followee = ? AND substr(f.created_at, 1, 10) IN (${followDays.map(() => '?').join(',')}) AND f.created_at > ?
         AND ${ACTOR_OK('f.follower')}) WHERE rn <= 2`
  ).bind(me.id, ...followDays, since, me.id, me.id, me.id));
  if (people.length) for (const res of await env.DB.batch(people)) for (const r of res.results) {
    if (!names.has(r.key)) names.set(r.key, []);
    names.get(r.key).push({ id: r.who, name: r.name });
  }
  const out = await Promise.all(page.map(async i => ({
    key: i.key, kind: i.kind, at: i.at, count: i.n, unread: !!i.unread,
    postId: i.post_id || null, text: i.text ? [...i.text].slice(0, 60).join('') : null,
    people: i.kind === 'comment' ? [{ id: i.who, name: i.name }] : (names.get(i.key) || []),
    thumbURL: i.post_id ? await photoLink(env, url, i.post_id, 'thumb') : null })));
  const last = page[page.length - 1];
  return json({ notices: out, unread: unreadTotal,
                nextCursor: merged.length > NOTICE_PAGE && last ? `${last.at}|${last.key}` : null });
}

/// The notices the app showed, each with the version it showed (time and
/// count, as returned): those, and
/// only those, are read. At most a page at a time; old marks are swept.
async function noticesSeen(request, env, me) {
  const b = await request.json().catch(() => null);
  const shown = b && typeof b === 'object' && Array.isArray(b.shown) ? b.shown : [];
  if (!shown.length || shown.length > NOTICE_PAGE) fail(400, 'shown');
  const iso = /^\d{4}-\d\d-\d\dT[\d:.]+Z$/;
  for (const s_ of shown) if (typeof s_?.key !== 'string' || !/^[clf]:[\w.:-]{1,80}$/.test(s_.key) || !iso.test(s_.at || '')
    || !Number.isInteger(s_.count) || s_.count < 1) fail(400, 'shown');
  const now = nowISO(), since = new Date(clockNow() - NOTICE_DAYS * 86400000).toISOString();
  await env.DB.batch([
    // Only ever forward: a later version replaces, an older one changes nothing.
    ...shown.map(s_ => env.DB.prepare(`INSERT INTO notice_marks (user_id, key, at, n) VALUES (?, ?, ?, ?)
      ON CONFLICT(user_id, key) DO UPDATE SET at = excluded.at, n = excluded.n
      WHERE excluded.at > notice_marks.at OR (excluded.at = notice_marks.at AND excluded.n > notice_marks.n)`)
      .bind(me.id, s_.key, s_.at > now ? now : s_.at, s_.count)),
    env.DB.prepare('DELETE FROM notice_marks WHERE user_id = ? AND at < ?').bind(me.id, since),
  ]);
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
  const exp = Math.floor(clockNow() / 1000 / step) * step + (admin ? 600 : LINK_SECONDS);
  const adm = admin ? 1 : 0;
  return `${url.origin}/v1/photos/${postId}/${kind}?exp=${exp}&adm=${adm}&sig=${await hmac(env, `${postId}/${kind}/${exp}/${adm}`)}`;
}

/// A picture, while its link is good and its post still public or waiting
/// (hidden, deleted and banned ones are gone at once).
async function servePhoto(url, env, postId, kind) {
  const exp = Number(url.searchParams.get('exp'));
  const sig = url.searchParams.get('sig') || '';
  const adm = url.searchParams.get('adm') === '1' ? 1 : 0;
  if (!(exp > clockNow() / 1000) || sig !== await hmac(env, `${postId}/${kind}/${exp}/${adm}`)) fail(403, 'link');
  const p = await env.DB.prepare('SELECT photo_key, thumb_key, state FROM posts WHERE id = ?').bind(postId).first();
  if (!p || (p.state === 'hidden' && !adm)) fail(404, 'not-found');
  const obj = await env.PHOTOS.get(kind === 'full' ? p.photo_key : p.thumb_key);
  if (!obj) fail(404, 'not-found');
  // Checked with the server each time it's shown: hidden means gone at once.
  return new Response(obj.body, { headers: { 'content-type': 'image/jpeg', 'cache-control': 'private, no-cache' } });
}

export { verifyAppleToken, streak, dayIn, dayBefore, badWords };   // for checks
