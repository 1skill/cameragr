# Release material — consistency check (2026-11-21, rechecked 2026-11-22)

Checked: `metadata.md`, `review-notes.md`, `Config/Koco.storekit`,
`cameragr/Resources/Films/films.json`, `design/appstore/iap/`, `docs/`
(support and privacy pages), the app itself. Nothing personal filled in.

## Fixed in this check
| What | Where | Was | Now |
|---|---|---|---|
| Sample comparison called the original "iPhone" | film page (app, incl. VoiceOver), store description EN/中文 | "iPhone original" / “iPhone 原图” — but sample originals are AI-generated | app: "Original"/“原图” for samples, "iPhone" only for the user's own photo, VoiceOver likewise; description: "a sample original" / “样张原图” |
| "Every film is computed from spectral data" | description EN/中文 | Grit Neg and CCD are fitted to real camera pictures, not film data | says so |
| Purchase review screenshots showed old code-drawn canisters | `design/appstore/iap/*.png` (7) | stand-in canisters, "iPhone" label | re-shot with the GPT canisters, current labels and prices |

## Agree (rechecked 2026-11-22 against the current build)
- Films: 16 in the catalogue; free: Golden 200, Tri-Ax 400, Instant 800 = "three films are free" everywhere.
- Products: 14 non-consumables — 13 films + All Films; IDs in `Config/Koco.storekit` match metadata.md and the app; $1.99 / $14.99 USA base, Apple’s automatic equivalents elsewhere (China ¥15 / ¥98, user’s choice 11/22); Family Sharing on. Created in App Store Connect 11/22 (all READY_TO_SUBMIT), review screenshots `design/appstore/iap2/` (14, current interface).
- Trial shots: 3 per paid film everywhere.
- Store description: lists all 16 films; describes the half-fold finder (built), the inner-screen bag, sharing (photo / video / letter) and the photo book.
- Review notes: thirteen paid films; the bag's three tabs; the photo book section (3.2.2(x), local only, restore excludes the earned film).
- Privacy: "no account, no uploads, no tracking" matches the privacy manifests and the privacy page; the photo book keeps its copies on the device only.

## Still open
| # | What | Where | Needs | Owner |
|---|---|---|---|---|
| 1 | ✔ (2026-11-22) The photo book was reachable only on iPhone Duo — now the bag opens from FILMS/SETUP on every iPhone, and from the Lock Screen camera after unlocking; description and notes updated | — | — | done |
| 2 | Screenshots: headlines | design/appstore/duo | the user writes the 8 headlines (decision B11-copy); then all shots in each language | user, then me |
| 3 | Version | project.yml MARKETING_VERSION 0.1.0 | 1.0 for the release build | me, at 2.4 |
| 4 | App Review contact (name, phone, email) | App Store Connect | filled in by the account holder | user — 2.8 |
| 5 | Support URL, privacy URL, support email | metadata.md, review notes | GitHub Pages address final; new support email | user — B5/B6 |
| 6 | App name availability | App Store Connect | check when creating the app | user — B6 |
| 7 | Family Sharing, prices, names of the 14 products | App Store Connect | must match metadata.md when created | user — 2.1/2.3 |
| 8 | Photo book recording for review | review notes checklist | a short recording of three days and the claim | me, before submitting |
| 9 | Traditional Chinese, Japanese, Korean texts | metadata.md, app | machine-made; a native read | user — B14 |

Closed since 2026-11-21: brand names (renamed, user's decision), waist-level finder (built), open-flat library in the description (now the bag), "save the iPhone original" (kept, B13), copyright (© 2026 水婴), share video wording (wired, "Original" for samples).

## 2026-11-22 · 改名结果（用户决定，避开胶卷厂商商标）
上面的旧记录经过机械替换，名称已是新名；原名对照如下：
Portra 400 → Porto 400 · Gold 200 → Golden 200 · Kodachrome 64 → Chroma 64 · Tri-X 400 → Tri-Ax 400 · Instax → Instant 800 · GR Neg → Grit Neg · Velvia 50 → Velva 50 · FP-100C → Peel 100C · Vista 100 → Vesta 100 · Ektachrome 100 → Electra 100 · Natura 1600 → Nature 1600。
不改：C200、Cine 500T、CCD、Double-X、Pro 400H。罐子标签已按新名重画（Chroma 罐写 CHROMA 64）。商品 ID 不变。
