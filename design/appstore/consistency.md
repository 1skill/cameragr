# Release material — consistency check (2026-11-21)

Checked: `metadata.md`, `review-notes.md`, `Config/Koco.storekit`,
`cameragr/Resources/Films/films.json`, `design/appstore/iap/`, `docs/`
(support and privacy pages), the app itself. Nothing personal filled in.

## Fixed in this check
| What | Where | Was | Now |
|---|---|---|---|
| Sample comparison called the original "iPhone" | film page (app, incl. VoiceOver), store description EN/中文 | "iPhone original" / “iPhone 原图” — but sample originals are AI-generated | app: "Original"/“原图” for samples, "iPhone" only for the user's own photo, VoiceOver likewise; description: "a sample original" / “样张原图” |
| "Every film is computed from spectral data" | description EN/中文 | GR Neg and CCD are fitted to real camera pictures, not film data | says so |
| Purchase review screenshots showed old code-drawn canisters | `design/appstore/iap/*.png` (7) | stand-in canisters, "iPhone" label | re-shot with the GPT canisters, current labels and prices |

## Agree (no action)
- Products: 7 non-consumables — 6 films + All Films; IDs match the app; prices $1.99 / $14.99 (¥12 / ¥68 in metadata); Family Sharing on in the local configuration.
- Free films: Gold 200, Tri-X 400, Instax in the app = "three films are free" in the description, review notes and support page.
- Trial shots: 3 per paid film everywhere.
- Privacy: "no account, no uploads, no tracking" matches the privacy manifests (no data collected) and the privacy page.

## Still open
| # | What | Where | Needs | Owner |
|---|---|---|---|---|
| 1 | Film brand names (Portra, Kodachrome, Tri-X, Instax, Kodak, Fuji, Polaroid…) in keywords, description and promotional text; the can says "CHROME 64" while text says Kodachrome | metadata.md, canisters | decide how far brand names may be used (trademark risk at review) | user — QUEUE B3 |
| 2 | "Half-open the phone for a waist-level finder" | description EN/中文, review notes | the waist-level finder (F2) is not built yet; keep the sentence only if it ships | me, after B12 |
| 3 | Open-flat film library not in the store description (review notes describe the drawer) | description; review notes | add to the description and update the notes once the design is final | me, after B10 |
| 3b | "Save the iPhone original too" setting and description line vs the earlier decision "no unfiltered original kept" | Settings, description EN/中文 | which is current: keep the setting (then update the decision) or remove it (then the line goes) | user — QUEUE B13 |
| 3c | App Review contact (name, phone, email) | App Store Connect → App Review Information | filled in by the account holder; check before submitting | user — 2.8 |
| 4 | Copyright line | metadata.md | name or company | user — B2 |
| 5 | Support URL, privacy URL, support email | metadata.md, review notes | GitHub Pages address final; new support email | user — B5/B6 |
| 6 | App name "Koco Film" / "Koco 胶片相机" availability | App Store Connect | check when creating the app | user — B6 |
| 7 | Version | project.yml MARKETING_VERSION 0.1.0 | set to 1.0 for the release build | me, at 2.4 |
| 8 | Share video says "iPhone → Koco" | ComparisonVideo (not wired yet) | use "Original" wording for samples when it is wired (B4) | me |
| 9 | App Store screenshots | design/appstore/shots | sample only; full set after style approval | user — B11 |
| 10 | Family Sharing, prices, names in App Store Connect | App Store Connect | must match this list when the products are created | user — 2.1/2.3 |
