# Koco Film — App Review notes（v1 待发布稿 2026-11-24：页签换成左下波段窗、每日限免、7/14 天限定卷、试拍用完的新流程；用户点头前不贴进 App Store Connect）

Paste the English part into App Store Connect → App Review Information →
Notes. The Chinese part is for us. Contact details in App Store Connect are
filled in by the account holder, not here.

---

## English (for App Review)

Koco Film is a film-simulation camera. It takes pictures with the iPhone
camera, applies a film look on the device and saves them to Photos (in an
album named "Koco"). No sign-in, no server.

**How to try it**
1. Open the app and allow Camera and Photos. The screen is a camera body:
   the red key takes a picture; the window shows the live view through the
   loaded film.
2. Tap the small film window on the body (it shows the loaded roll) to
   open the film chamber: tap the roll to change films. Beside the open
   chamber, FILMS opens the camera bag (every film, its samples, the photo
   book) and SETUP opens it at its Kit pages (settings). From the Lock
   Screen camera, FILMS and SETUP ask to unlock and open the app there.

**Films and purchases**
- Golden 200, Tri-Ax 400 and Instant 800 are free.
- The other thirteen films are non-consumable in-app purchases, one per film,
  plus "All Films", a single non-consumable that unlocks every film for
  sale, including films for sale added later. Family Sharing is on. There
  are no subscriptions and no ads.
- Each paid film can be tried before buying: 3 free trial shots per film.
  When they are used up, the camera's LCD shows END and the viewfinder
  offers two choices: buy that film, or choose another roll. In the app, a
  trial shot that fails (e.g. the picture could not be saved) is not counted.
- Daily free film: each calendar day (device time zone) one of the thirteen
  paid films is free for everyone for that day, with unlimited shots; its
  tag says "Free today". Pictures taken stay in Photos. The next day it goes
  back to its trial shots. It is worked out on the device from the date; no
  server. It never includes the two limited films below.
- Two limited films, Dusk 200 and Ember 400, are not sold at all (no
  product, no trial shots, not part of All Films). They are earned only in
  the photo book (7 and 14 days, see below). They are Koco's own designed
  looks.
- "Restore Purchases" is on the Films page and in Settings; "Redeem a
  Code" is in Settings.

**Lock Screen camera and Camera Control**
- Koco provides a Lock Screen camera (LockedCameraCapture). Add the "Koco
  Camera" control to the Lock Screen or Control Center, or assign it to the
  Camera Control button (Settings → Camera → Camera Control). Pressing it
  opens the same camera while the phone stays locked.
- Pictures taken while locked are saved to Photos at once and are moved into
  the Koco album the next time the app is opened. Bought films and trial
  shots are shared between the app and the Lock Screen camera.
- In the app, the Camera Control button and the volume buttons also take a
  picture; on supported iPhones, Camera Control also changes film, zoom,
  exposure and flash.

**Folding iPhone (iPhone Duo)**
On a folding iPhone the fold is part of the camera: closed, the outer screen
is the camera; opened flat, the inner screen is a leather camera bag. Its pages are chosen
with a small radio-style band window at the foot of the left page (tap a
name or slide the pointer): Films (choose a roll; its card and the
pictures taken on it), Kit (settings, purchases, help, licences) and Book
(the photo book described below). Closing the phone loads the chosen roll.
Partly open, the lower half is a waist-level finder. Other iPhones use the closed layout only.

**Sample pictures**
The sample originals on each film's page were generated with AI and are
labelled as such on that page ("Sample originals are AI-generated; the film
is rendered live by the app"). The film look on them is rendered by the app
on the device, exactly as on the user's own pictures. "Try my photo" lets
the reviewer apply a film to any picture from Photos; it is processed on the
device and never uploaded.

**Photo book (earn a film by shooting)**
The camera bag (FILMS beside the open film chamber, on any iPhone; on iPhone Duo also the unfolded inner screen) has a third tab, "Book", with a photo book with a theme ("It fell
asleep"). Each calendar day the user puts one picture taken with Koco
(on any day) into the book. Three days in a row earn Porto 400; seven
and fourteen days in a row earn the two limited films, Dusk 200 and
Ember 400, taken from the book's pouch one after another. The longest run
reached is kept if a day is missed later. It rewards a specific in-app activity
(taking pictures in the app), as 3.2.2(x) allows:
- Free films are enough to complete it; nothing is required besides
  taking and choosing one's own pictures in the app.
- No account, upload, sharing, rating, review, download, invitation or
  outside payment is involved or asked for. Nothing leaves the device.
- Porto 400 is also sold as a normal non-consumable in-app purchase. The
  two limited films are not sold anywhere (no product exists for them);
  they are cosmetic film looks, not needed for any other feature. The book
  grants no credits, currency or codes.
- The earned film is kept on this iPhone only. Restore Purchases restores
  App Store purchases, not the book or its film; the book says so.
- Someone who already owns Porto 400 gets only the book's date stamp.
To see it without waiting: the attached screen recording (a test build
with the dates moved forward) shows the 3-, 7- and 14-day claims.

**Privacy**
Koco collects no data: no analytics, no tracking, no sign-in. Pictures stay
on the device and in the user's Photos library. Camera access is used to
take pictures; Photos access to save them, to show a film's pictures on the
light table, and for "Try my photo". The privacy manifest declares
UserDefaults only (to keep settings, purchases and trial counts on the
device). The photo book keeps, on the device only, the dates and a small
copy of each picture put in.

**Purchases in review builds**
Purchases go through StoreKit with the products listed in App Store Connect.
The simulated purchases used during development exist only in debug builds;
the build submitted for review does not contain them.

**Contact**
Support: <support URL> · <support email, to be added>

---

## 简体中文（给我们自己看）

Koco Film 是胶片模拟相机：用 iPhone 相机拍照，在手机上套胶片效果，存进“照片”的 Koco 相簿。没有账号、不登录、没有服务器。

**怎么试**：打开 App，允许相机和照片；机身上的红键拍照，取景窗显示套了胶片的实时画面。点机身上显示当前胶卷的小窗打开片仓，点胶卷就能换卷；片仓旁边的 FILMS 键看全部胶卷和样张，SETUP 是设置。

**胶卷与购买**：Golden 200、Tri-Ax 400、Instant 800 免费；其余 13 卷每卷一个非消耗型内购，另有“全部胶卷”一次买齐全部在售胶卷（含以后新增的在售胶卷），开家人共享，没有订阅和广告。每卷付费胶卷可免费试拍 3 张，用完后液晶屏显示 END，取景器里给两个选择：买下这卷，或换一卷；每日限免：每天按手机日期轮一卷付费胶卷，所有人当天不限张数免费拍，照片保留，第二天回到试拍，本机计算无服务器，不含限定卷；两卷限定胶卷 Dusk 200、Ember 400 完全不卖（没有商品、没有试拍、不在“全部胶卷”里），只能在小册里连续打卡 7 天、14 天获得，是 Koco 自己设计的效果；在 App 里没拍成（比如没存进相册）的试拍不算；锁屏相机里失败的那次仍会算。恢复购买在胶卷页和设置里，兑换码在设置里。

**锁屏相机与相机控制按钮**：提供锁屏相机。把“Koco 相机”控件加到锁屏或控制中心，或在 设置 → 相机 → 相机控制 里指定，就能在锁屏状态下打开同一个相机。锁屏时拍的照片立刻存进“照片”，下次打开 App 时移进 Koco 相簿；购买和试拍次数在 App 和锁屏相机之间同步。App 里相机控制按钮和音量键也能拍照，支持的机型上相机控制按钮还能换卷、变焦、曝光、闪光灯。

**折叠 iPhone（iPhone Duo）**：合上用外屏拍照；全展开是一只皮革相机包，左页最下方一个收音机波段窗切页（点页名或拨指针）：胶卷（选卷，看这卷的卡片和拍过的照片）、维护（设置、购买、说明、许可）、小册（见上）；合上就装入选好的卷；半开时下半屏是腰平取景器。其它 iPhone 只用合上的布局。

**样张**：每卷页面的样张原图由 AI 生成，页面上已注明；上面的胶片效果是 App 在手机上实时渲染的，和用户自己的照片一样。“用我的照片试试”可以给相册里任意照片套胶片，只在手机上处理、不上传。

**小册（拍照换胶卷）**：相机包（任何 iPhone：打开胶卷仓点 FILMS；iPhone Duo 展开内屏也是）第三个页签「小册」，主题「它睡着了」。每天放进一张用 Koco 拍的照片（哪天拍的都行），连续 3 天领 Porto 400，7 天、14 天依次领两卷限定胶卷；断签后已达成的最长天数保留。属于 3.2.2(x) 允许的“奖励 App 内特定行为”：用免费胶卷就能完成；不涉及账号、上传、分享、评分、下载、邀请或站外付款，数据不出手机；Porto 400 照常作为非消耗型内购出售；两卷限定胶卷不卖（没有商品），只是外观效果，不影响其他功能；不发积分、货币或兑换码；赠卷只存在这台手机上，恢复购买只恢复 App Store 购买，小册里写明了；已经有 Porto 400 的人只得纪念章。审核员不必等：附一段测试包（日期往后调）里 3/7/14 天领取的录屏。

**隐私**：不收集任何数据，没有统计、追踪、账号。照片只在手机和用户的相册里。相机权限用来拍照；照片权限用来存照片、在相机包里显示拍过的照片、把照片放进小册、以及“用我的照片试试”。隐私清单只声明了 UserDefaults（在手机上存设置、购买和试拍次数）。

**审核包里的购买**：走 StoreKit 和 App Store Connect 里的商品；开发时的模拟购买只存在于调试版，提交审核的包里没有。

**联系方式**：支持网址 <待填> · 支持邮箱 <新邮箱开好后填>

## Before submitting — check these against the build
- [x] The waist-level finder (part-open) is finished.
- [ ] Product names and prices in App Store Connect match the list in
      metadata.md, and all fourteen products have Family Sharing turned on.
- [ ] Attach a short screen recording of the photo book (three days, then
      claiming Porto 400) so the reviewer need not wait three days.
- [ ] Paste only the English part, and only once the placeholders below
      are filled in.
- [ ] Support URL and email filled in (new accounts, QUEUE B5).
- [ ] Film names on the canisters and in the catalogue settled (QUEUE B3).
