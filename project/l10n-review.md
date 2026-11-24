# 母语校对清单（C13）

这些译文是我翻的，标着 needs_review，上架前请母语者看一遍。中文简体是基准，用户定过的文案不改。
校对方法：每行看繁中 / 日 / 韩是否通顺、语气是否一致（亲切、简短），占位符（%@、%lld）要保留；改好后把 Xcode 字符串表里对应语言的状态改为“已翻译”。

待校对：繁中 401 条、日语 401 条、韩语 401 条（共 401 个原文）。

另外请注意：
- 名字、照片说明、留言是用户写的，不翻译；含 emoji 时字号按系统处理。
- 复数：英文原文里的“%lld days”等，中日韩不区分单复数，已按一种写法处理。
- 长文（规则、删号说明、隐私）在日语、韩语里通常更长，界面已能滚动；请看有没有不自然的断句。

| 原文（英） | 简体中文 | 繁中 | 日语 | 韩语 |
|---|---|---|---|---|
| %@ is banned; their pictures are hidden. | 已封 %@，TA 的照片都已隐藏。 | 已停權 %@，對方的照片都已隱藏。 | %@を利用停止にし、写真を非表示にしました。 | %@ 님을 이용 정지했고 사진을 숨겼어요. |
| %@ is yours. It’s in the bag. | %@ 归你了，已经放进相机包。 | %@ 歸你了，已經放進相機包。 | %@があなたのものに。カメラバッグに入れました。 | %@ 이(가) 생겼어요. 카메라 가방에 넣었어요. |
| %@ samples · AI originals, film rendered by Koco | %@ 样张 · 原图由 AI 生成，胶片效果由 Koco 渲染 | %@ 樣張 · 原圖由 AI 生成，底片效果由 Koco 算繪 | %@の作例 · 元画像はAI生成、フィルムはKocoで描画 | %@ 샘플 · 원본은 AI 생성, 필름은 Koco가 렌더링 |
| %@ · %lld | %@ · %lld 张 | %@ · %lld 張 | %@ · %lld枚 | %@ · %lld장 |
| %@ · %lld · %lld/%lld | %@ · %lld 张 · %lld/%lld | %@ · %lld 張 · %lld/%lld | %@ · %lld枚 · %lld/%lld | %@ · %lld장 · %lld/%lld |
| %@ — no pictures yet | %@ — 还没拍过 | %@ — 還沒拍過 | %@ — まだ撮影なし | %@ — 아직 찍은 사진 없음 |
| %@ — pictures deleted or hidden | %@ — 照片已删除或看不到 | %@ — 相片已刪除或看不到 | %@ — 写真が削除されたか見えません | %@ — 사진이 삭제되었거나 보이지 않음 |
| %@: earned in the Community only | %@：只能在社区里打卡获得 | %@：只能在社群裡打卡獲得 | %@：コミュニティで連続記録して手に入れる | %@: 커뮤니티에서 연속 기록으로만 얻을 수 있어요 |
| %@: free shots used up | %@ 的试拍用完了 | %@ 的試拍用完了 | %@：無料の試し撮りは終了 | %@: 무료 체험 촬영 끝 |
| %lld days | %lld 天 | %lld 天 | %lld日 | %lld일 |
| %lld days in a row | 连续 %lld 天 | 連續 %lld 天 | %lld日連続 | %lld일 연속 |
| %lld days in a row and it’s yours | 连续打卡 %lld 天，送你这一卷 | 連續打卡 %lld 天，送你這一卷 | %lld日続けたらもらえる | %lld일 연속이면 이 필름을 |
| %lld days reached: take your roll from the pouch. | 已连续打卡 %lld 天：去信封里领这一卷。 | 已連續打卡 %lld 天：去信封裡領這一卷。 | %lld日達成：封筒からフィルムを受け取ろう。 | %lld일 달성: 봉투에서 필름을 받아 가세요. |
| %lld free trial shots left | 还可免费试拍 %lld 张 | 還可免費試拍 %lld 張 | 無料の試し撮りあと%lld枚 | 무료 체험 촬영 %lld장 남음 |
| %lld more days | 还差 %lld 天 | 還差 %lld 天 | あと%lld日 | %lld일 더 |
| %lld of %lld days in a row. See you tomorrow. | 已连续 %1$lld / %2$lld 天，明天见。 | 已連續 %1$lld / %2$lld 天，明天見。 | %2$lld日中%1$lld日連続。また明日。 | %2$lld일 중 %1$lld일 연속. 내일 봐요. |
| %lld of %lld days in a row. Today’s still to come. | 已连续 %1$lld / %2$lld 天，今天的还没放。 | 已連續 %1$lld / %2$lld 天，今天的還沒放。 | %2$lld日中%1$lld日連続。今日の分はまだ。 | %2$lld일 중 %1$lld일 연속. 오늘 것은 아직. |
| %lld of %lld days. See you tomorrow. | 第 %1$lld / %2$lld 天，明天见。 | 第 %1$lld / %2$lld 天，明天見。 | %2$lld日中%1$lld日目。また明日。 | %2$lld일 중 %1$lld일째. 내일 봐요. |
| %lld of %lld days. Today’s still to come. | 已经 %1$lld / %2$lld 天，今天的还没放。 | 已經 %1$lld / %2$lld 天，今天的還沒放。 | %2$lld日中%1$lld日。今日の分はまだ。 | %2$lld일 중 %1$lld일. 오늘 것은 아직. |
| %lld of %lld paid films are yours | 已拥有 %1$lld / %2$lld 卷付费胶卷 | 已擁有 %1$lld / %2$lld 卷付費底片 | 有料フィルム %2$lld本中 %1$lld本を所有 | 유료 필름 %2$lld개 중 %1$lld개 보유 |
| %lld open reports | %lld 条举报未处理 | %lld 則檢舉未處理 | 未処理の通報 %lld件 | 처리할 신고 %lld건 |
| %lld pictures stored: nearing the free storage | 已存 %lld 张照片，接近免费存储上限 | 已存 %lld 張照片，接近免費儲存上限 | 保存済み %lld枚：無料ストレージの上限が近づいています | 사진 %lld장 저장됨: 무료 저장 공간 한도에 가까워요 |
| %lld pictures waiting for approval | %lld 张照片待审 | %lld 張照片待審 | %lld枚が審査待ち | 사진 %lld장이 검토 대기 중 |
| %lld posts today | 今天 %lld 条投稿 | 今天 %lld 則投稿 | 今日の投稿 %lld件 | 오늘 게시 %lld건 |
| 3 to 2 | 3 比 2 | 3 比 2 | 3対2 | 3대2 |
| A click when you shoot | 按快门时咔嚓一声 | 按快門時喀嚓一聲 | 撮るときにカシャッと鳴ります | 찍을 때 찰칵 소리가 납니다 |
| A day was missed: start again today. The pictures before stay. | 隔了一天，今天重新开始。前面的照片还在。 | 隔了一天，今天重新開始。前面的照片還在。 | 1日空いたので今日からやり直し。前の写真はそのまま。 | 하루 빠져서 오늘부터 다시. 이전 사진은 그대로예요. |
| A film camera for iPhone: choose a roll, load it and shoot. | iPhone 上的胶片相机：挑一卷，装上，拍。 | iPhone 上的底片相機：挑一捲，裝上，拍。 | iPhone のフィルムカメラ：フィルムを選んで、装填して、撮る。 | iPhone용 필름 카메라: 필름을 골라 넣고 찍으세요. |
| A light tap under your finger | 指尖下轻轻一震 | 指尖下輕輕一震 | 指先に軽い手応え | 손끝에 가벼운 진동 |
| A picture approved in a theme counts its day. Three days in a row give Porto 400; seven and fourteen give limited rolls that are never sold. Once reached, a roll stays yours to claim. | 在题目下有照片通过审核，那天就算打卡。连续 3 天送 Porto 400；连续 7 天、14 天送不卖的限定卷。达到过的档位一直可以领。 | 在題目下有照片通過審核，那天就算打卡。連續 3 天送 Porto 400；連續 7 天、14 天送不賣的限定捲。達到過的檔位一直可以領。 | お題で写真が承認されるとその日が記録されます。3日連続でPorto 400、7日・14日連続で非売品の限定フィルムがもらえます。一度届いた段階はいつでも受け取れます。 | 주제에 올린 사진이 승인되면 그날이 기록돼요. 3일 연속이면 Porto 400, 7일·14일 연속이면 판매하지 않는 한정 필름을 받아요. 한 번 달성한 단계는 언제든 받을 수 있어요. |
| A voucher for a roll is yours: choose one in Mine. | 你得到一张胶卷兑换凭证，在“我的”里挑一卷。 | 你得到一張底片兌換憑證，在「我的」裡挑一捲。 | フィルム引換券をもらいました。マイページで1本選んでください。 | 필름 교환권을 받았어요. 내 정보에서 하나 골라 주세요. |
| About | 关于 | 關於 | このアプリについて | 정보 |
| About Koco | 关于 Koco | 關於 Koco | Koco について | Koco 정보 |
| Access | 权限 | 權限 | アクセス | 권한 |
| Add Koco from the Lock Screen’s and Control Center’s controls to start shooting without unlocking. | 在锁屏和控制中心的控件里添加 Koco，不用解锁就能开拍。 | 在鎖定畫面和控制中心的控制項裡加入 Koco，不用解鎖就能開拍。 | ロック画面とコントロールセンターのコントロールにKocoを追加すると、ロックを解除せずに撮影を始められます。 | 잠금 화면과 제어 센터의 제어 항목에 Koco를 추가하면 잠금을 풀지 않고 바로 촬영할 수 있습니다. |
| Alerts | 提醒 | 提醒 | お知らせ | 알림 |
| All films | 全部胶卷 | 全部底片 | すべてのフィルム | 모든 필름 |
| All films %@ | 全部胶卷 %@ | 全部底片 %@ | 全フィルム %@ | 모든 필름 %@ |
| All films Try again | 全部胶卷 点此重试 | 全部底片 點此重試 | 全フィルム 再試行 | 모든 필름 다시 시도 |
| All films are yours | 全部胶卷都已解锁 | 全部底片都已解鎖 | すべてのフィルムを所有しています | 모든 필름을 보유 중 |
| All yours | 全部已拥有 | 全部已擁有 | すべて所有 | 모두 보유 |
| Allow access | 允许访问 | 允許取用 | アクセスを許可 | 접근 허용 |
| Allow access to Photos to see your pictures here. | 允许访问照片后，这里会显示拍过的照片。 | 允許取用照片後，這裡會顯示拍過的相片。 | 写真へのアクセスを許可すると、撮った写真がここに表示されます。 | 사진 접근을 허용하면 찍은 사진이 여기에 표시됩니다. |
| Allow Photos in Settings to see them | 在设置里允许访问照片才能看到 | 在設定裡允許取用照片才能看到 | 見るには設定で写真へのアクセスを許可してください | 보려면 설정에서 사진 접근을 허용하세요 |
| Allowed | 已允许 | 已允許 | 許可済み | 허용됨 |
| Approve | 批准 | 核准 | 承認 | 승인 |
| Auto | 自动 | 自動 | 自動 | 자동 |
| Awaiting approval | 待批准 | 等待核准 | 承認待ち | 승인 대기 |
| Back | 返回 | 返回 | 戻る | 뒤로 |
| Ban | 封号 | 停權 | 利用停止 | 이용 정지 |
| Ban %@? | 确定封 %@？ | 確定停權 %@？ | %@を利用停止にしますか？ | %@ 님을 이용 정지할까요? |
| Black & white | 黑白 | 黑白 | モノクロ | 흑백 |
| Block %@ | 拉黑 %@ | 封鎖 %@ | %@ をブロック | %@ 차단 |
| Buy %@ | 购买 %@ | 購買 %@ | %@で購入 | %@ 구입 |
| Buy %@ to save it | 买下 %@ 再存 | 買下 %@ 再存 | %@で購入して保存 | %@에 구입하고 저장 |
| Buy %@ → | 购买 %@ → | 購買 %@ → | %@で購入 → | %@ 구입 → |
| Buy all films · %@ → | 买下全部胶卷 · %@ → | 買下全部膠卷 · %@ → | すべてのフィルムを購入 · %@ → | 모든 필름 구매 · %@ → |
| Buy it · %@ | 买下 · %@ | 買下 · %@ | 購入 · %@ | 구매 · %@ |
| Buying… | 正在购买… | 正在購買… | 購入中… | 구매 중… |
| Camera | 相机 | 相機 | カメラ | 카메라 |
| Camera & Photos access | 相机和照片权限 | 相機和照片權限 | カメラと写真へのアクセス | 카메라와 사진 접근 |
| Camera and Photos access | 相机和相册权限 | 相機和照片權限 | カメラと写真へのアクセス | 카메라 및 사진 접근 |
| Camera not allowed | 相机未允许 | 相機未允許 | カメラ未許可 | 카메라 허용 안 됨 |
| Camera: allowed | 相机：已允许 | 相機：已允許 | カメラ：許可済み | 카메라: 허용됨 |
| Camera: not allowed | 相机：未允许 | 相機：未允許 | カメラ：未許可 | 카메라: 허용 안 됨 |
| Can't be bought right now | 暂时买不了 | 暫時無法購買 | 現在は購入できません | 지금은 구입할 수 없음 |
| Cancel | 取消 | 取消 | キャンセル | 취소 |
| Change film | 更换胶卷 | 更換底片 | フィルムを交換 | 필름 교체 |
| Change name | 改名字 | 改名字 | 名前を変える | 이름 바꾸기 |
| Choose a roll for your voucher | 用凭证换一卷 | 用憑證換一捲 | 引換券と交換するフィルム | 교환권으로 받을 필름 |
| Choose another roll | 换一卷 | 換一捲 | 別のフィルムにする | 다른 필름 고르기 |
| Choose Film | 选择胶卷 | 選擇底片 | フィルムを選ぶ | 필름 선택 |
| Choose Films | 选胶卷 | 選膠卷 | フィルムを選ぶ | 필름 고르기 |
| Claim | 领取 | 領取 | 受け取る | 받기 |
| Claim a voucher | 领兑换凭证 | 領兌換憑證 | 引換券を受け取る | 교환권 받기 |
| Claimed | 已领取 | 已領取 | 受け取り済み | 받음 |
| Close | 关闭 | 關閉 | 閉じる | 닫기 |
| Close the bag | 扣上包，回到相机 | 扣上包，回到相機 | 留め具を留めてカメラへ | 가방을 닫고 카메라로 |
| Close the bag and load %@ | 扣上包，装入 %@ | 扣上包，裝入 %@ | 留め具を留めて%@を装填 | 가방을 닫고 %@ 장전 |
| Close the film chamber | 关上胶卷仓 | 關上底片艙 | フィルム室を閉じる | 필름실 닫기 |
| Close the phone to load it · tap to undo | 合上手机就装进相机 · 再点撤回 | 闔上手機就裝進相機 · 再點一下取消 | スマホを閉じると装填 · もう一度タップで取り消し | 휴대폰을 접으면 장전 · 다시 탭하면 취소 |
| Close the phone to load it. | 合上手机，就装进相机。 | 闔上手機，就裝進相機。 | スマホを閉じるとカメラに装填されます。 | 휴대폰을 접으면 카메라에 장전됩니다. |
| Close the phone, or turn it upright to shoot | 合上手机，或竖过来就能拍 | 闔上手機，或豎過來就能拍 | 閉じるか、縦に持てば撮れます | 닫거나 세로로 들면 찍을 수 있어요 |
| Close the phone, or turn it upright to shoot · tap to undo | 合上手机，或竖过来就能拍 · 点这里撤销 | 闔上手機，或豎過來就能拍 · 點這裡撤銷 | 閉じるか、縦に持てば撮れます · タップで取り消し | 닫거나 세로로 들면 찍을 수 있어요 · 탭해서 취소 |
| Colour | 彩色 | 彩色 | カラー | 컬러 |
| Comments %lld | 留言 %lld | 留言 %lld | コメント %lld | 댓글 %lld |
| Comments waiting: %lld | 待审留言：%lld | 待審留言：%lld | 審査待ちのコメント：%lld | 검토 대기 댓글: %lld |
| Community | 社区 | 社群 | コミュニティ | 커뮤니티 |
| Community rules | 社区规则 | 社群規則 | コミュニティのルール | 커뮤니티 규칙 |
| Comparison video | 对比视频 | 對比影片 | 比較動画 | 비교 영상 |
| Couldn’t keep that just now. Tap again. | 刚才没存上，再点一下。 | 剛才沒存上，再點一下。 | 今は保存できませんでした。もう一度タップして。 | 방금 저장하지 못했어요. 다시 탭하세요. |
| Couldn’t load more. Scroll again to try. | 没能载入更多，再滑一下试试。 | 沒能載入更多，再滑一下試試。 | 続きを読み込めませんでした。もう一度スクロールしてください。 | 더 불러오지 못했어요. 다시 스크롤해 보세요. |
| Couldn’t load. Pull down to try again. | 没能载入，下拉再试。 | 沒能載入，下拉再試。 | 読み込めませんでした。下に引いて再試行。 | 불러오지 못했어요. 아래로 당겨 다시 시도하세요. |
| Couldn’t load. Tap to try again. | 没能载入，点一下再试。 | 沒能載入，點一下再試。 | 読み込めませんでした。タップして再試行。 | 불러오지 못했어요. 눌러서 다시 시도하세요. |
| Couldn’t open that one | 这张打不开 | 這張打不開 | この写真は開けません | 이 사진은 열 수 없어요 |
| Couldn’t post. Check the connection and try again. | 没有投成功，请检查网络后再试。 | 沒有投成功，請檢查網路後再試。 | 投稿できませんでした。接続を確認してもう一度。 | 올리지 못했어요. 연결을 확인하고 다시 시도해 주세요. |
| Couldn’t save · try again | 没存上 · 再试一次 | 沒存上 · 再試一次 | 保存できず · もう一度 | 저장 실패 · 다시 시도 |
| Couldn’t sign in. Try again. | 没能登录，再试一次。 | 沒能登入，再試一次。 | サインインできませんでした。もう一度お試しください。 | 로그인하지 못했어요. 다시 시도해 주세요. |
| Delete | 删除 | 刪除 | 削除 | 삭제 |
| Delete account | 删除账号 | 刪除帳號 | アカウントを削除 | 계정 삭제 |
| Delete my account | 删除我的账号 | 刪除我的帳號 | アカウントを削除する | 내 계정 삭제 |
| Delete your account? Your name, pictures, comments, likes, reports, blocks and rewards in the community are deleted for good, and Koco's access to your Apple ID is withdrawn. Rolls already given stay on this iPhone; your pictures in Photos are not touched. | 确定删除账号？你在社区里的名字、照片、留言、点赞、举报、拉黑和奖励会永久删除，Koco 对你 Apple ID 的访问也会撤回。已经送你的胶卷留在这台 iPhone 上；相册里的照片不受影响。 | 確定刪除帳號？你在社群裡的名字、照片、留言、按讚、檢舉、封鎖和獎勵會永久刪除，Koco 對你 Apple ID 的存取也會撤回。已經送你的底片留在這台 iPhone 上；相簿裡的照片不受影響。 | アカウントを削除しますか？コミュニティでの名前、写真、コメント、いいね、通報、ブロック、ごほうびは完全に削除され、KocoのApple IDへのアクセスも取り消されます。もらったフィルムはこのiPhoneに残り、写真アプリの写真には影響しません。 | 계정을 삭제할까요? 커뮤니티의 이름, 사진, 댓글, 좋아요, 신고, 차단, 보상이 영구 삭제되고 Koco의 Apple ID 접근도 철회돼요. 이미 받은 필름은 이 iPhone에 남고, 사진 앱의 사진은 그대로예요. |
| Deleting… | 删除中… | 刪除中… | 削除中… | 삭제 중… |
| Do up the bag’s clasp to load it | 扣上包就装进相机 | 扣上包就裝進相機 | 留め具を留めると装填 | 똑딱이를 채우면 장전 |
| Do up the bag’s clasp to load it · tap to undo | 扣上包就装进相机 · 再点撤回 | 扣上包就裝進相機 · 再點撤回 | 留め具を留めると装填 · もう一度で取り消し | 똑딱이를 채우면 장전 · 다시 누르면 취소 |
| Done: three days in a row. | 完成啦：连续三天。 | 完成啦：連續三天。 | 達成：3日連続！ | 완료: 3일 연속! |
| Drag the white line to compare. Sample originals are AI-generated; the film is rendered live by the app. | 左右拖动白线对比。样张原图由 AI 生成，效果为 App 实时渲染。 | 左右拖動白線比較。樣張原圖由 AI 生成，效果為 App 即時算繪。 | 白い線をドラッグして比べられます。作例の元画像はAIで生成、フィルムの効果はアプリがリアルタイムで描画しています。 | 흰 선을 드래그해 비교하세요. 샘플 원본은 AI로 생성했고, 필름 효과는 앱이 실시간으로 렌더링합니다. |
| Drag the white line to compare. Your photo is processed on this phone and never uploaded. | 左右拖动白线对比。你的照片只在本机处理，不会上传。 | 左右拖動白線比較。你的相片只在這支手機上處理，不會上傳。 | 白い線をドラッグして比べられます。写真はこのiPhone上で処理され、アップロードされません。 | 흰 선을 드래그해 비교하세요. 사진은 이 기기에서만 처리되며 업로드되지 않습니다. |
| DSEG LCD fonts | DSEG 液晶字体 | DSEG 液晶字型 | DSEG 液晶フォント | DSEG LCD 글꼴 |
| Earn it in the Community · %lld days → | 在社区里连续打卡 %lld 天获得 → | 在社群裡連續打卡 %lld 天獲得 → | コミュニティに%lld日続けて入れるともらえる → | 커뮤니티에 %lld일 연속 넣으면 받아요 → |
| Every film for sale is yours | 所有在售胶卷都是你的 | 所有在售底片都是你的 | 販売中のフィルムはすべてあなたのもの | 판매 중인 필름은 모두 당신 것 |
| Every film for sale, now and later, in one purchase. Limited rolls come only from the Community. | 现在出售的所有胶卷，加上以后新出的，一次买下，随便拍。限定胶卷只能在社区里打卡获得，不卖。 | 現在出售的所有底片，加上以後新出的，一次買下，隨便拍。限定底片只能在社群裡打卡獲得，不賣。 | いま販売中のすべてのフィルムと、今後追加されるフィルムをまとめて購入。好きなだけ撮れます。限定フィルムはコミュニティでのみもらえ、販売はしません。 | 지금 판매 중인 모든 필름과 앞으로 추가될 필름을 한 번에 구매. 마음껏 찍으세요. 한정 필름은 커뮤니티에서만 받을 수 있고 판매하지 않아요. |
| Every film for sale, yours to keep | 所有在售胶卷，永久拥有 | 所有在售底片，永久擁有 | 販売中の全フィルムをずっと | 판매 중인 모든 필름을 영구 소장 |
| Every film here now and every one added later, in one purchase. Shoot any of them as much as you like. | 现在的和以后新增的胶卷，一次买齐，想拍哪卷拍哪卷。 | 現在的和以後新增的膠卷，一次買齊，想拍哪捲拍哪捲。 | 今あるフィルムも、これから増えるフィルムも一度の購入で。好きなだけ撮れます。 | 지금 있는 필름도, 앞으로 추가될 필름도 한 번에. 마음껏 찍으세요. |
| Every film is yours, including new ones as they come. | 全部胶卷都是你的了，以后上新也一样。 | 全部底片都是你的了，之後上新也一樣。 | すべてのフィルムがあなたのもの。今後追加されるフィルムも含みます。 | 모든 필름이 당신의 것입니다. 앞으로 추가될 필름도 포함됩니다. |
| Every film, now and later. One purchase, shared with your family. | 现有和以后的所有胶卷，买一次，家人也能用。 | 現有和之後的所有底片，買一次，家人也能用。 | 今あるフィルムも今後のフィルムも。一度の購入で、家族とも共有できます。 | 지금과 앞으로의 모든 필름. 한 번 구입으로 가족과도 공유됩니다. |
| Every film, yours to keep | 所有胶卷，永久拥有 | 所有膠卷，永久擁有 | すべてのフィルムを、ずっと | 모든 필름, 영원히 내 것 |
| Every picture and comment is looked at before it shows; ones that break these rules are turned down or taken away, and accounts that keep breaking them are closed. | 每张照片、每条留言都会先审核再公开；违反规则的不会通过或会被撤下，多次违反的账号会被封。 | 每張照片、每則留言都會先審核再公開；違反規則的不會通過或會被撤下，多次違反的帳號會被停權。 | 写真もコメントも公開前に確認します。ルール違反は掲載しないか削除し、繰り返すアカウントは利用停止にします。 | 모든 사진과 댓글은 공개 전에 검토해요. 규칙을 어기면 반려되거나 내려가고, 반복하는 계정은 이용이 정지돼요. |
| Everyone can see what you post. | 投进去的照片所有人都能看到。 | 投進去的照片所有人都能看到。 | 投稿した写真はみんなが見られます。 | 올린 사진은 모두가 볼 수 있어요. |
| Exposure compensation | 曝光补偿 | 曝光補償 | 露出補正 | 노출 보정 |
| Festival theme | 节日题目 | 節日題目 | 季節のお題 | 시즌 주제 |
| Film | 胶卷 | 底片 | フィルム | 필름 |
| Film colour and grain come from the open-source Spectral Film LUT, computed from each stock’s spectral and grain data; Grit Neg and CCD were fitted by Koco to real camera samples. Sample originals on the detail pages are AI-generated; the film is rendered live by the app. | 胶卷的颜色和颗粒来自开源的 Spectral Film LUT，按各胶卷的光谱和颗粒数据计算；Grit Neg和 CCD 是 Koco 按真机样片拟合的。详情页的样张原图由 AI 生成，效果为 App 实时渲染。 | 底片的色彩和顆粒來自開源的 Spectral Film LUT，依各底片的光譜和顆粒資料計算；Grit Neg和 CCD 是 Koco 依實機樣片擬合的。詳情頁的樣張原圖由 AI 生成，效果為 App 即時算繪。 | フィルムの色と粒子はオープンソースのSpectral Film LUTによるもので、各フィルムの分光・粒状性データから計算しています。Grit NegとCCDは実機の作例にKocoが合わせたものです。詳細ページの作例の元画像はAIで生成、フィルムの効果はアプリがリアルタイムで描画しています。 | 필름의 색과 입자는 오픈 소스 Spectral Film LUT에서 왔으며, 각 필름의 분광·입자 데이터로 계산했습니다. Grit Neg와 CCD는 Koco가 실제 카메라 샘플에 맞춰 만들었습니다. 상세 페이지의 샘플 원본은 AI로 생성했고, 필름 효과는 앱이 실시간으로 렌더링합니다. |
| Film details | 胶卷详情 | 底片詳情 | フィルムの詳細 | 필름 상세 |
| Film Shelf | 胶卷架 | 底片架 | フィルム棚 | 필름 선반 |
| Film store | 胶卷商店 | 底片商店 | フィルムストア | 필름 스토어 |
| Films | 胶卷 | 底片 | フィルム | 필름 |
| Flash | 闪光灯 | 閃光燈 | フラッシュ | 플래시 |
| Fold the phone halfway like a laptop: the lower half becomes a waist-level finder with a level and a shutter key, the upper half is the camera. | 像笔记本电脑一样把手机折到一半：下半屏是带水平仪和快门键的腰平取景器，上半屏是相机。 | 像筆電一樣把手機摺到一半：下半螢幕是帶水平儀和快門鍵的腰平取景器，上半螢幕是相機。 | ノートパソコンのように半分折ると、下半分は水準器とシャッターキー付きのウエストレベルファインダー、上半分はカメラになります。 | 노트북처럼 반쯤 접으면 아래쪽은 수평계와 셔터 키가 있는 웨이스트 레벨 파인더, 위쪽은 카메라가 됩니다. |
| Foldable iPhone | 折叠屏 iPhone | 折疊 iPhone | 折りたたみiPhone | 폴더블 iPhone |
| Follow Koco | 关注 Koco | 追蹤 Koco | Kocoをフォロー | Koco 팔로우 |
| For the viewfinder | 取景器要用 | 取景器要用 | ファインダーに使います | 뷰파인더에 필요해요 |
| Format | 画幅 | 畫幅 | フォーマット | 화면 비율 |
| Free | 免费 | 免費 | 無料 | 무료 |
| Free today | 今日 限免 | 今日 限免 | 今日 無料 | 오늘 무료 |
| Free films and trial shots are always there. | 免费胶卷和试拍随时可用。 | 免費底片和試拍隨時可用。 | 無料フィルムと試し撮りはいつでも使えます。 | 무료 필름과 체험 촬영은 언제든 쓸 수 있습니다. |
| Free shots used up · buy %@ → | 试拍用完了 · 买下 %@ → 或换一卷 | 試拍用完了 · 買下 %@ → 或換一捲 | 無料の試し撮りは終了 · %@ で購入 → または別のフィルムを選ぶ | 무료 체험 촬영 끝 · %@에 구매 → 또는 다른 필름 선택 |
| Free shots used up · choose another roll | 试拍用完了 · 换一卷吧 | 試拍用完了 · 換一捲吧 | 無料の試し撮りは終了 · 別のフィルムを選んでください | 무료 체험 촬영 끝 · 다른 필름을 고르세요 |
| Free today, as many shots as you like · load it → | 今日限免，随便拍 · 装上它 → | 今日限免，隨便拍 · 裝上它 → | 今日は無料、何枚でも · 入れる → | 오늘 무료, 마음껏 · 넣기 → |
| Free today: %@, as many shots as you like. The pictures stay. | 今日限免：%@，当天随便拍，照片都留着。 | 今日限免：%@，當天隨便拍，照片都留著。 | 今日の無料：%@。何枚でも撮れて、写真は残ります。 | 오늘 무료: %@. 마음껏 찍고, 사진은 남아요. |
| Free trial shots used up | 免费试拍已用完 | 免費試拍已用完 | 無料の試し撮りを使い切りました | 무료 체험 촬영을 모두 사용함 |
| Front | 前置 | 前置 | 前面 | 전면 |
| Get more films | 获取更多胶卷 | 取得更多底片 | フィルムを追加 | 필름 더 받기 |
| Half-folded | 半折 | 半摺 | 半分折り | 반쯤 접기 |
| Haptics | 触感反馈 | 觸覺回饋 | 触覚フィードバック | 햅틱 |
| Hate | 仇恨言论 | 仇恨言論 | ヘイト | 혐오 |
| Help | 帮助 | 說明 | ヘルプ | 도움말 |
| Hidden %lld | 隐藏 %lld | 隱藏 %lld | 非表示 %lld | 숨김 %lld |
| Hide | 隐藏 | 隱藏 | 非表示 | 숨기기 |
| I agree | 我同意 | 我同意 | 同意する | 동의해요 |
| If something here is wrong, report it from its ⋯. Blocking someone hides them from you and you from them. | 看到不对的内容，点它旁边的 ⋯ 举报。拉黑某人后，你们互相看不到对方。 | 看到不對的內容，點它旁邊的 ⋯ 檢舉。封鎖某人後，你們互相看不到對方。 | 問題のある内容は「⋯」から通報してください。ブロックするとお互いに見えなくなります。 | 문제가 있는 내용은 ⋯에서 신고해 주세요. 차단하면 서로 보이지 않아요. |
| In camera | 相机里 | 相機裡 | 装填中 | 장전됨 |
| In the camera | 已在相机里 | 已在相機裡 | カメラに装填中 | 카메라에 장전됨 |
| In the camera: %@ | 相机里：%@ | 相機裡：%@ | 装填中：%@ | 장전됨: %@ |
| In the iPhone’s Settings › Camera › Camera Control, choose Koco to open it with a press, even from the Lock Screen. | 在 iPhone 的“设置 › 相机 › 相机控制”里选择 Koco，按一下就能打开，锁屏时也可以。 | 在 iPhone 的「設定 › 相機 › 相機控制」裡選擇 Koco，按一下就能打開，鎖定時也可以。 | iPhoneの「設定 › カメラ › カメラコントロール」でKocoを選ぶと、ボタンを押すだけで開けます。ロック中でも使えます。 | iPhone의 ‘설정 › 카메라 › 카메라 제어’에서 Koco를 선택하면 버튼을 눌러 바로 열 수 있습니다. 잠금 상태에서도 됩니다. |
| In use | 正在使用 | 使用中 | 使用中 | 사용 중 |
| In your Photos | 已存进相册 | 已存進相簿 | 写真に保存しました | 사진에 저장됨 |
| It didn't go. Your picture and words are kept: tap Put it in to try again. | 没发出去。照片和文字都还在，再点“放进去”试一次。 | 沒發出去。照片和文字都還在，再點「放進去」試一次。 | 送れませんでした。写真と文はそのままです。もう一度「入れる」を押してください。 | 보내지 못했어요. 사진과 글은 그대로예요. ‘넣기’를 다시 눌러 주세요. |
| It fell asleep | 它睡着了 | 牠睡著了 | 寝ちゃった | 잠들었어 |
| Just this picture · SHARE to send | 只发这张照片 · 按 SHARE 发出 | 只傳這張照片 · 按 SHARE 傳出 | この写真だけ · SHAREで送る | 이 사진만 · SHARE로 보내기 |
| Keep | 保留 | 保留 | そのまま | 유지 |
| Keep the roll in the camera | 不换了，用相机里这卷 | 不換了，用相機裡這卷 | 今のフィルムのままにする | 지금 필름 그대로 쓰기 |
| Kit | 维护 | 維護 | メンテ | 관리 |
| Koco Camera | Koco 相机 | Koco 相機 | Kocoカメラ | Koco 카메라 |
| Koco develops your pictures on your iPhone and saves them to your photo library. Only the pictures you post to the community leave the phone, with your name, the film and your caption; you sign in with Apple to post, and can delete your account at any time. | Koco 在你的 iPhone 上冲洗照片并存入相册。只有你投到社区的照片会离开手机，连同你的名字、胶卷和配文；投稿需用 Apple 登录，账号随时可以删除。 | Koco 在你的 iPhone 上沖洗照片並存入相簿。只有你投到社群的照片會離開手機，連同你的名字、底片和說明；投稿需用 Apple 登入，帳號隨時可以刪除。 | Koco は写真を iPhone 上で現像し、写真ライブラリに保存します。端末の外に出るのは、コミュニティに投稿した写真と名前・フィルム・キャプションだけです。投稿には Apple でサインインが必要で、アカウントはいつでも削除できます。 | Koco는 사진을 iPhone에서 현상해 사진 보관함에 저장합니다. 휴대폰 밖으로 나가는 것은 커뮤니티에 올린 사진과 이름, 필름, 설명뿐입니다. 게시하려면 Apple로 로그인해야 하며, 계정은 언제든 삭제할 수 있습니다. |
| Koco film certificate | Koco 胶卷凭证 | Koco 膠卷憑證 | Koco フィルム証書 | Koco 필름 증서 |
| Koco handbook | Koco 使用手册 | Koco 使用手冊 | Koco ハンドブック | Koco 핸드북 |
| Koco has no access to Photos, so the picture wasn’t saved. Allow it in Settings. | 没有相册权限，照片未保存。请在系统设置里允许访问照片。 | 沒有照片權限，相片沒有儲存。請在設定裡允許取用照片。 | 写真へのアクセスがないため保存されませんでした。設定で許可してください。 | 사진 접근 권한이 없어 저장하지 못했습니다. 설정에서 허용해 주세요. |
| Koco has no access to the camera. Allow it in Settings. | 没有相机权限，请在系统设置里允许 Koco 使用相机。 | 沒有相機權限，請在設定裡允許 Koco 使用相機。 | カメラへのアクセスがありません。設定で許可してください。 | 카메라 접근 권한이 없습니다. 설정에서 허용해 주세요. |
| Koco uses no analytics or advertising and does not track you. Purchases are handled by Apple; Koco only learns which films your Apple ID owns. | Koco 没有统计分析和广告，也不追踪你。购买由 Apple 处理，Koco 只知道你的 Apple ID 拥有哪些胶卷。 | Koco 沒有分析和廣告，也不追蹤你。購買由 Apple 處理，Koco 只知道你的 Apple 帳號擁有哪些底片。 | Kocoは解析も広告も使わず、あなたを追跡しません。購入はAppleが処理し、KocoにはApple Accountが所有するフィルムだけが伝わります。 | Koco는 분석이나 광고를 쓰지 않으며, 사용자를 추적하지 않습니다. 구입은 Apple이 처리하며 Koco는 Apple 계정이 어떤 필름을 보유했는지만 알 수 있습니다. |
| Koco works entirely on your iPhone. Your pictures are developed on the phone and saved to your photo library; nothing is uploaded, and Koco has no servers or accounts. | Koco 完全在你的 iPhone 上运行。照片在手机上冲洗并存入你的相册，不会上传任何内容，Koco 没有服务器，也没有账号。 | Koco 完全在你的 iPhone 上運作。相片在手機上沖洗並存入你的照片圖庫，不會上傳任何內容，Koco 沒有伺服器，也沒有帳號。 | KocoはすべてiPhone上で動作します。写真は端末内で現像されて写真ライブラリに保存され、何もアップロードされません。Kocoにはサーバーもアカウントもありません。 | Koco는 모든 것이 iPhone 안에서 동작합니다. 사진은 기기에서 현상되어 사진 보관함에 저장되며, 아무것도 업로드되지 않습니다. Koco에는 서버도 계정도 없습니다. |
| Koco — a film camera for iPhone | Koco —— iPhone 上的胶片相机 | Koco — iPhone 上的底片相機 | Koco — iPhoneのフィルムカメラ | Koco — iPhone용 필름 카메라 |
| Language | 语言 | 語言 | 言語 | 언어 |
| Last picture | 上一张照片 | 上一張相片 | 直前の写真 | 마지막 사진 |
| Letter | 来信 | 來信 | レター | 편지 |
| Letter: tap for the other line | 来信：点一下换一句话 | 來信：點一下換一句話 | レター：タップで別のひと言 | 편지: 탭하면 다른 문구 |
| Licence text missing. | 许可文本缺失。 | 授權文字遺失。 | ライセンス文が見つかりません。 | 라이선스 문구가 없습니다. |
| Licences | 许可 | 授權 | ライセンス | 라이선스 |
| Like | 点赞 | 按讚 | いいね | 좋아요 |
| Limited | 部分允许 | 部分允許 | 一部のみ | 일부만 |
| Limited rolls are earned in the Community, not bought. | 限定胶卷只能在社区里打卡获得，不卖。 | 限定底片只能在社群裡打卡獲得，不賣。 | 限定フィルムはコミュニティでのみもらえます（販売なし）。 | 한정 필름은 커뮤니티에서만 받을 수 있어요(판매 안 함). |
| Load this roll | 装上这卷 | 裝上這卷 | このフィルムを装填 | 이 필름 장전 |
| Load this roll → | 装上这卷 → | 裝上這卷 → | このフィルムを装填 → | 이 필름 장전 → |
| Loaded · %@ | 已装上 · %@ | 已裝上 · %@ | 装填しました · %@ | 장전 완료 · %@ |
| Lock Screen and Control Center | 锁屏和控制中心 | 鎖定畫面和控制中心 | ロック画面とコントロールセンター | 잠금 화면과 제어 센터 |
| Mine | 我的 | 我的 | マイページ | 내 정보 |
| Mine’s asleep again. Your turn. | 我家这只又睡着了，轮到你拍了。 | 我家這隻又睡著了，輪到你拍了。 | うちの子、また寝てる。次はきみの番。 | 우리 애 또 잠들었어. 이제 네 차례야. |
| MIT License · © 2026 Jan Lohse | MIT 许可 · © 2026 Jan Lohse | MIT 授權 · © 2026 Jan Lohse | MITライセンス · © 2026 Jan Lohse | MIT 라이선스 · © 2026 Jan Lohse |
| More | 更多 | 更多 | その他 | 더 보기 |
| My posts | 我的投稿 | 我的投稿 | 自分の投稿 | 내 게시물 |
| New comments | 新留言 | 新留言 | 新しいコメント | 새 댓글 |
| New report: %@ | 新举报：%@ | 新檢舉：%@ | 新しい通報：%@ | 새 신고: %@ |
| Next | 下一卷 | 下一捲 | 次 | 다음 |
| Next film | 下一卷 | 下一卷 | 次のフィルム | 다음 필름 |
| Next roll | 下一卷 | 下一卷 | 次のフィルム | 다음 필름 |
| No ads, spam or links. Comments are short and kind. | 不发广告、垃圾信息或链接。留言简短、友善。 | 不發廣告、垃圾訊息或連結。留言簡短、友善。 | 広告、スパム、リンクは禁止です。コメントは短く、やさしく。 | 광고·스팸·링크는 안 돼요. 댓글은 짧고 다정하게. |
| No alerts. | 没有提醒。 | 沒有提醒。 | お知らせはありません。 | 알림이 없어요. |
| No comments yet. | 还没有留言。 | 還沒有留言。 | まだコメントはありません。 | 아직 댓글이 없어요. |
| No nudity or sexual content, no violence or gore, no hate or harassment, nothing illegal. | 不发裸露或色情内容、暴力或血腥内容、仇恨或骚扰内容，不发违法内容。 | 不發裸露或色情內容、暴力或血腥內容、仇恨或騷擾內容，不發違法內容。 | ヌードや性的な内容、暴力や流血、ヘイトや嫌がらせ、違法なものは投稿しないでください。 | 노출·성적인 내용, 폭력·잔인한 내용, 혐오·괴롭힘, 불법적인 내용은 올리지 마세요. |
| No open reports. | 没有未处理的举报。 | 沒有未處理的檢舉。 | 未処理の通報はありません。 | 처리할 신고가 없어요. |
| No other purchases on this Apple ID. | 这个 Apple 账户没有其他购买。 | 這個 Apple 帳號沒有其他購買項目。 | このApple Accountにほかの購入はありません。 | 이 Apple 계정에 다른 구입 항목이 없습니다. |
| No pictures on this roll yet. | 这卷还没拍过照片。 | 這卷還沒拍過相片。 | このフィルムではまだ撮影していません。 | 이 필름으로 아직 찍은 사진이 없습니다. |
| No pictures taken with Koco yet. Take one first. | 还没有用 Koco 拍过照片，先去拍一张吧。 | 還沒有用 Koco 拍過照片，先去拍一張吧。 | まだ Koco で撮った写真がありません。まず1枚撮ってみて。 | 아직 Koco로 찍은 사진이 없어요. 먼저 한 장 찍어 보세요. |
| Not allowed | 未允许 | 未允許 | 未許可 | 허용 안 됨 |
| Not approved | 未通过 | 未通過 | 非承認 | 승인 안 됨 |
| Not asked yet | 还没问过 | 還沒問過 | 未確認 | 아직 묻지 않음 |
| Not bought yet | 尚未购买 | 尚未購買 | 未購入 | 아직 구입 안 함 |
| Not for sale | 非卖品 | 非賣品 | 非売品 | 비매품 |
| Not now | 先不 | 先不 | あとで | 나중에 |
| Not taken with Koco | 不是用 Koco 拍的 | 不是用 Koco 拍的 | Koco で撮った写真ではない | Koco로 찍은 사진이 아님 |
| Not yet: keep going. | 还没到，继续加油。 | 還沒到，繼續加油。 | まだです。続けましょう。 | 아직이에요. 계속해 봐요. |
| Nothing hidden. | 没有隐藏的。 | 沒有隱藏的。 | 非表示のものはありません。 | 숨긴 것이 없어요. |
| Nothing taken today yet. Close the phone and take one. | 今天还没拍，合上手机去拍一张吧。 | 今天還沒拍，合上手機去拍一張吧。 | 今日はまだ撮ってないよ。閉じて1枚撮ろう。 | 오늘은 아직 안 찍었어요. 폰을 닫고 한 장 찍어요. |
| Nothing taken with Koco yet. Go back to the camera and take one. | 还没有用 Koco 拍过照片。回到相机拍一张吧。 | 還沒有用 Koco 拍過照片。回到相機拍一張吧。 | まだ Koco で撮った写真がありません。カメラに戻って一枚撮りましょう。 | 아직 Koco로 찍은 사진이 없어요. 카메라로 돌아가 한 장 찍어 보세요. |
| Nothing waiting. | 没有待审的。 | 沒有待審的。 | 審査待ちはありません。 | 검토 대기 중인 것이 없어요. |
| Notice | 提示 | 提示 | お知らせ | 알림 |
| Nudity | 裸露 | 裸露 | ヌード | 노출 |
| Off | 关 | 關 | オフ | 끔 |
| OK | 好 | 好 | OK | 확인 |
| oldest %@ | 最早 %@ | 最早 %@ | 最も古い %@ | 가장 오래된 것 %@ |
| On | 开 | 開 | オン | 켬 |
| On a film’s page, choose Try my photo to see it on any picture from your library. | 在胶卷详情页点“用我的照片试试”，从相册选一张就能看效果。 | 在底片詳情頁點「用我的相片試試」，從照片圖庫選一張就能看效果。 | フィルムのページで「自分の写真で試す」を選ぶと、ライブラリの好きな写真で効果を確かめられます。 | 필름 페이지에서 ‘내 사진으로 해보기’를 누르면 보관함의 사진으로 효과를 볼 수 있습니다. |
| One Roll | 一卷胶卷 | 一卷底片 | 1本のフィルム | 필름 한 롤 |
| One sample from each film · AI originals, film rendered by Koco · tap one to look at that film | 每卷一张样张 · 原图由 AI 生成，胶片效果由 Koco 渲染 · 点一张就看那卷 | 每捲一張樣張 · 原圖由 AI 生成，膠片效果由 Koco 渲染 · 點一張就看那捲 | 各フィルムの作例 · 元画像は AI 生成、フィルムの風合いは Koco が描写 · タップでそのフィルムへ | 필름마다 샘플 한 장 · 원본은 AI 생성, 필름 효과는 Koco 렌더링 · 누르면 그 필름 보기 |
| Only pictures taken with Koco | 只能投 Koco 拍的照片 | 只能投 Koco 拍的照片 | Koco で撮った写真だけ | Koco로 찍은 사진만 |
| Only post people who agreed to be shared, and never someone else's private details. | 照片里有别人，要先得到对方同意；不公开任何人的隐私信息。 | 照片裡有別人，要先得到對方同意；不公開任何人的隱私資訊。 | 人が写っている場合は本人の同意を得てください。他人の個人情報は載せないでください。 | 다른 사람이 나오면 먼저 동의를 받고, 누구의 개인 정보도 올리지 마세요. |
| Open Community | 打开社区 | 打開社群 | コミュニティを開く | 커뮤니티 열기 |
| Open reports: %lld | 未处理举报：%lld | 未處理檢舉：%lld | 未処理の通報：%lld | 처리할 신고: %lld |
| Open Settings | 打开设置 | 打開設定 | 設定を開く | 설정 열기 |
| Open Settings → | 去设置 → | 去設定 → | 設定を開く → | 설정 열기 → |
| Open the film door and tap FILMS: in the bag, tap a roll to look at it, tap its tag to choose it, and do up the bag’s clasp to load it. | 打开胶卷仓点 FILMS：在相机包里点胶卷看它，点它的纸签选作下一卷，扣上包扣就装进相机。 | 打開底片倉點 FILMS：在相機包裡點底片看它，點它的紙籤選作下一捲，扣上包扣就裝進相機。 | フィルム扉を開けて FILMS をタップ：バッグでフィルムをタップして見て、タグで選び、バッグの留め金を留めると装填されます。 | 필름 도어를 열고 FILMS를 누르세요: 가방에서 필름을 눌러 보고, 태그를 눌러 고른 뒤 가방 걸쇠를 채우면 장전됩니다. |
| Open the Koco film camera. | 打开 Koco 胶片相机。 | 打開 Koco 底片相機。 | Kocoフィルムカメラを開きます。 | Koco 필름 카메라를 엽니다. |
| Open the phone flat: tap a roll to look at it, tap its tag to choose it, and close the phone all the way to load it. Closed, you can also open the film door and pick another roll. | 把手机完全展开：点胶卷看它，点它的纸签选作下一卷，把手机完全合上就装进相机。合着的时候，也可以打开胶卷仓换一卷。 | 把手機完全展開：點膠捲看它，點它的紙籤選作下一捲，把手機完全闔上就裝進相機。闔著的時候，也可以打開膠捲倉換一捲。 | スマホを全開にして、フィルムをタップで見る、タグをタップで次の一本に。完全に閉じると装填されます。閉じたままフィルム室を開けて入れ替えることもできます。 | 휴대폰을 완전히 펼쳐 필름을 눌러 보고, 태그를 눌러 다음 롤로 고른 뒤 완전히 닫으면 장전됩니다. 닫힌 상태에서 필름실을 열어 바꿀 수도 있어요. |
| Open the phone halfway: the outer half is the camera, the inner half becomes a waist-level finder. | 把手机半开：外侧一半是相机，里侧一半变成腰平取景器。 | 把手機半開：外側一半是相機，內側一半變成腰平取景器。 | スマホを半分開くと、外側がカメラ、内側がウエストレベルファインダーになります。 | 휴대폰을 반쯤 펼치면 바깥쪽은 카메라, 안쪽은 웨이스트 레벨 파인더가 됩니다. |
| Open-source licences | 开源许可 | 開源授權 | オープンソースライセンス | 오픈 소스 라이선스 |
| Or all films for %@, new ones included | 或 %@ 买全部胶卷（含以后上新） | 或以 %@ 購買全部底片（含之後上新） | または全フィルムを%@で（今後の追加分も含む） | 또는 모든 필름을 %@에 (앞으로 추가될 필름 포함) |
| Or all films for %@, new ones included (limited rolls are earned in the Community) | 或 %@ 买下全部胶卷，含以后的新卷（限定胶卷要在社区里获得） | 或 %@ 買下全部底片，含以後的新卷（限定底片要在社群裡獲得） | または全フィルムを%@で（今後の新作込み。限定フィルムはコミュニティで） | 또는 전체 필름 %@ (새 필름 포함, 한정 필름은 커뮤니티에서) |
| or buy it · %@ | 或直接买下 · %@ | 或直接買下 · %@ | または購入 · %@ | 또는 바로 구매 · %@ |
| Or free: get a picture approved in the Community three days running. | 也可以在社区连续三天各有一张照片通过审核，免费领。 | 也可以在社群連續三天各有一張照片通過審核，免費領。 | または、コミュニティで3日続けて写真が承認されれば無料でもらえます。 | 또는 커뮤니티에서 3일 연속 사진이 승인되면 무료로 받을 수 있어요. |
| Or free: three days running in the Community | 或免费：社区连续打卡三天 | 或免費：社群連續打卡三天 | または無料：コミュニティに3日連続 | 또는 무료: 커뮤니티에 3일 연속 |
| Original | 原图 | 原圖 | 元画像 | 원본 |
| Out | 已公开 | 已公開 | 公開中 | 공개됨 |
| Photo | 照片 | 照片 | 写真 | 사진 |
| Photos | 相册 | 相簿 | 写真 | 사진 |
| Photos not allowed | 相册未允许 | 照片未允許 | 写真未許可 | 사진 허용 안 됨 |
| Photos: allowed | 照片：已允许 | 照片：已允許 | 写真：許可済み | 사진: 허용됨 |
| Photos: not allowed | 照片：未允许 | 照片：未允許 | 写真：未許可 | 사진: 허용 안 됨 |
| Pick a favourite roll and tap to shoot with it. | 选一卷常用的胶卷，点一下直接开拍。 | 選一卷常用的底片，點一下直接開拍。 | お気に入りのフィルムを選んで、タップですぐ撮影。 | 자주 쓰는 필름을 골라 탭 한 번으로 촬영하세요. |
| Pick one, then put it in. | 选一张，再放进去。 | 選一張，再放進去。 | 1枚選んでから入れよう。 | 한 장 고른 뒤 넣어요. |
| Pick the rolls for this shelf, in the order they stand. | 选这个架子上放哪几卷，按选的顺序摆。 | 選這個架子上放哪幾捲，按選的順序擺。 | この棚に並べるフィルムを、並べる順に選びます。 | 이 선반에 둘 필름을 놓을 순서대로 고르세요. |
| Pick the rolls for this widget, in the order they stand. | 按摆放顺序挑选这个小组件里的胶卷（同一卷只能选一次）。 | 選這個小工具裡放哪幾捲，按選的順序擺，同一捲只能選一次。 | このウィジェットに並べるフィルムを、並べる順に選びます（同じフィルムは一度だけ）。 | 이 위젯에 둘 필름을 놓을 순서대로 고르세요(같은 필름은 한 번만). |
| Picture of %@ | %@ 的照片 | %@ 的照片 | %@の写真 | %@ 사진 |
| Picture taken %@ | 拍摄于 %@ 的照片 | 拍攝於 %@ 的照片 | %@ に撮影した写真 | %@에 찍은 사진 |
| Picture taken at %@ | %@ 拍的照片 | %@ 拍的照片 | %@に撮った写真 | %@에 찍은 사진 |
| Picture to share | 要分享的照片 | 要分享的照片 | シェアする写真 | 공유할 사진 |
| Pictures on this roll | 这卷拍的照片 | 這卷拍的相片 | このフィルムで撮った写真 | 이 필름으로 찍은 사진 |
| Pictures waiting: %lld | 待审照片：%lld | 待審照片：%lld | 審査待ちの写真：%lld | 검토 대기 사진: %lld |
| Post one | 投一张 | 投一張 | 1枚投稿 | 한 장 올리기 |
| Post only pictures you took with Koco, that fit the theme. | 只投用 Koco 拍的、符合题目的照片。 | 只投用 Koco 拍的、符合題目的照片。 | Kocoで撮った、お題に合う写真だけを投稿してください。 | Koco로 찍은, 주제에 맞는 사진만 올려 주세요. |
| Posted — it’s in the sleeve. | 放进去了，在插页里。 | 放進去了，在插頁裡。 | 入れました。スリーブにあります。 | 넣었어요. 앨범에 있어요. |
| Press the shutter again to choose a roll or buy this one | 再按一下快门，去换一卷或买下这卷 | 再按一下快門，去換一捲或買下這捲 | もう一度シャッターを押すと、フィルムを選ぶか購入できます | 셔터를 한 번 더 누르면 필름을 고르거나 살 수 있어요 |
| Previous film | 上一卷 | 上一卷 | 前のフィルム | 이전 필름 |
| Prices couldn't be loaded. Check the connection and tap to try again. | 价格没能加载，请检查网络后点这里重试。 | 價格沒能載入，請檢查網路後點這裡重試。 | 価格を読み込めませんでした。接続を確認してタップで再試行してください。 | 가격을 불러오지 못했습니다. 연결을 확인하고 탭해서 다시 시도하세요. |
| Prices unavailable · try again | 价格没加载出来 · 再试一次 | 價格沒載入 · 再試一次 | 価格を取得できません · 再試行 | 가격을 불러올 수 없음 · 다시 시도 |
| Privacy | 隐私 | 隱私權 | プライバシー | 개인정보 보호 |
| Purchase waiting for approval | 购买正等待批准 | 購買正在等待核准 | 購入は承認待ちです | 구입 승인 대기 중 |
| Purchases restored. | 已恢复购买。 | 已回復購買項目。 | 購入を復元しました。 | 구입 항목을 복원했습니다. |
| Put away | 收起 | 收起 | しまう | 넣기 |
| Put it in | 放进去 | 放進去 | 入れる | 넣기 |
| Put the kit away | 收起维护夹 | 收起維護夾 | メンテナンスキットをしまう | 관리 키트 넣기 |
| Put the share tray away | 收起出片夹 | 收起出片夾 | シェアトレイをしまう | 공유 트레이 닫기 |
| Put today’s in | 放入今天的一张 | 放入今天的一張 | 今日の1枚を入れる | 오늘의 한 장 넣기 |
| Rate Koco | 给 Koco 评分 | 為 Koco 評分 | Kocoを評価 | Koco 평가하기 |
| Ready to load | 待装入 | 待裝入 | 装填待ち | 장전 대기 |
| Ready to load: %@ | 待装入：%@ | 待裝入：%@ | 装填待ち：%@ | 장전 대기: %@ |
| Rear | 后置 | 後置 | 背面 | 후면 |
| Recommend Koco to a friend | 推荐给朋友 | 推薦給朋友 | 友だちにすすめる | 친구에게 추천하기 |
| Redeem a code | 兑换码 | 兌換代碼 | コードを使う | 코드 사용 |
| Report mail: %lld to send, %lld failed | 举报邮件：待发 %lld，失败 %lld | 檢舉郵件：待寄 %lld，失敗 %lld | 通報メール：送信待ち %lld、失敗 %lld | 신고 메일: 보낼 것 %lld, 실패 %lld |
| Report mail: not set up yet (needs a sending domain) | 举报邮件：还没配好（需要发信域名） | 檢舉郵件：還沒設定好（需要寄信網域） | 通報メール：未設定（送信用ドメインが必要） | 신고 메일: 아직 설정 전 (발신 도메인 필요) |
| Report or block | 举报或拉黑 | 舉報或封鎖 | 報告またはブロック | 신고 또는 차단 |
| Report: %@ | 举报：%@ | 檢舉：%@ | 通報：%@ | 신고: %@ |
| Reported. Thank you — it will be looked at. | 已举报，谢谢，我们会查看。 | 已檢舉，謝謝，我們會查看。 | 通報しました。ありがとうございます。確認します。 | 신고했어요. 감사합니다. 확인할게요. |
| Reports %lld | 举报 %lld | 檢舉 %lld | 通報 %lld | 신고 %lld |
| Restore | 恢复 | 恢復 | 復元 | 복원 |
| Restore purchases | 恢复购买 | 回復購買項目 | 購入を復元 | 구입 복원 |
| Restoring… | 正在恢复… | 正在回復… | 復元中… | 복원 중… |
| Sample %lld | 样张 %lld | 樣張 %lld | 作例 %lld | 샘플 %lld |
| Sample original compared with %@ | 样张原图与 %@ 的对比 | 樣張原圖與 %@ 的比較 | 作例の元画像と%@の比較 | 샘플 원본과 %@ 비교 |
| Samples | 看样张 | 看樣張 | 作例 | 샘플 |
| Samples for this film are on their way. Try it on one of your own photos meanwhile. | 这卷的样张还在制作中。 可以先用你自己的照片试试。 | 這卷的樣張還在製作中。 可以先用你自己的相片試試。 | このフィルムの作例は準備中です。 それまでは自分の写真で試してみてください。 | 이 필름의 샘플은 준비 중입니다. 그동안 내 사진으로 먼저 해보세요. |
| Save | 保存 | 儲存 | 保存 | 저장 |
| Save it · 1 of %lld free shots | 存下来 · 用掉 %lld 张免费里的 1 张 | 存下來 · 用掉 %lld 張免費裡的 1 張 | 保存 · 無料%lld枚のうち1枚 | 저장 · 무료 %lld장 중 1장 사용 |
| Save it, full size | 存下来（全尺寸） | 存下來（全尺寸） | フルサイズで保存 | 원본 크기로 저장 |
| Save the iPhone original too | 同时保存 iPhone 原图 | 同時儲存 iPhone 原圖 | iPhoneの元画像も保存 | iPhone 원본도 저장 |
| Saving… | 正在保存… | 正在儲存… | 保存中… | 저장 중… |
| Say something (optional) | 说一句（可不写） | 說一句（可不寫） | ひとこと（なくても可） | 한마디 (선택) |
| Send | 发送 | 傳送 | 送信 | 보내기 |
| Send feedback | 意见反馈 | 意見回饋 | フィードバックを送る | 의견 보내기 |
| Sending… | 正在发送… | 正在傳送… | 送信中… | 보내는 중… |
| Sent — it shows to everyone once it’s approved. | 已投出——审核通过后大家就能看到。 | 已投出——審核通過後大家就能看到。 | 送信しました。承認されるとみんなに公開されます。 | 보냈어요. 승인되면 모두에게 보여요. |
| Settings | 设置 | 設定 | 設定 | 설정 |
| Share | 分享 | 分享 | 共有 | 공유 |
| Shoot with Koco | 用 Koco 拍照 | 用 Koco 拍照 | Kocoで撮影 | Koco로 촬영 |
| Shooting | 拍摄 | 拍攝 | 撮影 | 촬영 |
| Show the last picture | 查看上一张照片 | 查看上一張相片 | 直前の写真を見る | 마지막 사진 보기 |
| Shown to everyone once it’s approved. | 审核通过后大家都能看到。 | 審核通過後大家都能看到。 | 承認されるとみんなに公開されます。 | 승인되면 모두에게 보여요. |
| Shutter | 快门 | 快門 | シャッター | 셔터 |
| Shutter sound | 快门声音 | 快門聲 | シャッター音 | 셔터 소리 |
| Sign in to post. | 登录后才能投稿。 | 登入後才能投稿。 | 投稿するにはサインインしてください。 | 게시하려면 로그인하세요. |
| Sign in to see everyone’s pictures and post your own. | 登录后能看大家的照片，也能投自己的。 | 登入後能看大家的照片，也能投自己的。 | サインインすると、みんなの写真を見たり自分の写真を投稿したりできます。 | 로그인하면 모두의 사진을 보고 내 사진도 올릴 수 있어요. |
| Sign out | 退出登录 | 登出 | サインアウト | 로그아웃 |
| Signed out. | 已退出登录。 | 已登出。 | サインアウトしました。 | 로그아웃했어요. |
| Some regions always play it. | 部分地区按法律要求始终会有快门声。 | 部分地區依法規一律會有快門聲。 | 一部の地域では常に鳴ります。 | 일부 지역에서는 항상 소리가 납니다. |
| Something else | 其他 | 其他 | その他 | 기타 |
| Spam | 垃圾信息 | 垃圾訊息 | スパム | 스팸 |
| Square | 正方形 | 正方形 | スクエア | 정사각형 |
| Start today. | 今天就开始吧。 | 今天就開始吧。 | 今日から始めよう。 | 오늘부터 시작해요. |
| Swipe up from this edge to leave | 从这条边上滑离开 | 從這條邊上滑離開 | この端から上にスワイプで閉じる | 이 가장자리에서 위로 쓸어 나가기 |
| Switch camera | 切换前后镜头 | 切換前後鏡頭 | カメラを切り替え | 카메라 전환 |
| Take this roll → | 领这一卷 → | 領這一卷 → | このフィルムをもらう → | 이 필름 받기 → |
| Tap a roll to look · its tag to choose · close to load · slide for more | 点卷看照片 · 点签选下一卷 · 合上装入 · 上下滑看更多 | 點捲看照片 · 點籤選下一捲 · 闔上裝入 · 上下滑看更多 | タップで写真 · タグで次の一本 · 閉じて装填 · 上下にスライド | 필름을 눌러 사진 · 태그로 다음 롤 · 닫으면 장전 · 위아래로 더 보기 |
| Tap a roll to look · its tag to choose · do up the clasp to load | 点卷看照片 · 点签选下一卷 · 扣上包就装入 | 點捲看照片 · 點籤選下一捲 · 扣上包就裝入 | タップで写真・タグで次の一本・留め具を留めて装填 | 필름을 눌러 사진 · 태그로 다음 롤 · 똑딱이를 채우면 장전 |
| Tap a roll to look · tap its tag to choose · close the phone to load it | 点胶卷看照片 · 点纸签选下一卷 · 合上手机就装入 | 點膠卷看照片 · 點紙籤選下一捲 · 闔上手機就裝入 | フィルムをタップで写真 · タグで次の一本に · 閉じると装填 | 필름을 눌러 사진 보기 · 태그로 다음 롤 선택 · 닫으면 장전 |
| Tap a roll to start shooting with it. | 点一卷胶卷，直接用它开拍。 | 點一卷底片，直接用它開拍。 | フィルムをタップしてそのまま撮影。 | 필름을 탭해 바로 촬영하세요. |
| Tap a roll’s tag to choose it, then do up the clasp | 先点一卷的价签选好，再扣上包扣 | 先點一捲的價籤選好，再扣上包扣 | フィルムのタグをタップして選び、留め金を留めてください | 필름 태그를 눌러 고른 뒤 걸쇠를 채우세요 |
| Tap again to buy · %@ | 再点一下购买 · %@ | 再點一下購買 · %@ | もう一度タップで購入 · %@ | 다시 탭해 구입 · %@ |
| Tap again to load it | 再点一下，选这卷 | 再點一下，選這卷 | もう一度タップで選ぶ | 다시 탭해 선택 |
| Tap again to try it · %lld shots | 再点一下试拍 · 剩 %lld 张 | 再點一下試拍 · 剩 %lld 張 | もう一度タップで試し撮り · 残り%lld枚 | 다시 탭해 체험 촬영 · %lld장 남음 |
| Tap here to let Koco see your pictures | 点这里，让 Koco 看到你的照片 | 點這裡，讓 Koco 看到你的相片 | ここをタップしてKocoに写真へのアクセスを許可 | 여기를 탭해 Koco가 사진을 볼 수 있게 하기 |
| Tap the film door on the right to open the chamber, then tap the roll to rewind it and pick another. | 点右侧的胶卷仓门打开胶卷仓，再点胶卷把它倒回，然后换一卷。 | 點右側的底片艙門打開底片艙，再點底片把它倒回，然後換一卷。 | 右側のフィルム扉をタップしてフィルム室を開け、フィルムをタップして巻き戻してから別のフィルムを選びます。 | 오른쪽 필름 도어를 탭해 필름실을 열고, 필름을 탭해 되감은 다음 다른 필름을 고르세요. |
| Tap the picture for the other line · SHARE to send | 点预览换一句话 · 按 SHARE 发出 | 點預覽換一句話 · 按 SHARE 傳出 | プレビューをタップで別のひと言 · SHAREで送る | 미리보기를 탭해 다른 문구 · SHARE로 보내기 |
| Tap to choose | 点这里选 | 點這裡選 | タップして選ぶ | 탭해서 선택 |
| Tap to let Koco see your pictures | 点这里，让 Koco 看到你的照片 | 點這裡，讓 Koco 看到你的相片 | タップしてKocoに写真へのアクセスを許可 | 탭해서 Koco가 사진을 볼 수 있게 하기 |
| Terms of use | 用户协议 | 使用條款 | 利用規約 | 이용 약관 |
| Thanks to everyone who tried the early builds and told us what felt wrong. | 感谢每一位试用早期版本、告诉我们哪里不对劲的人。 | 感謝每一位試用早期版本、告訴我們哪裡不對勁的人。 | 初期版を試し、気になる点を教えてくれたすべての方に感謝します。 | 초기 버전을 써 보고 어색한 점을 알려 준 모든 분께 감사드립니다. |
| That didn't go through. Try again. | 没有成功，请再试一次。 | 沒有成功，請再試一次。 | うまくいきませんでした。もう一度お試しください。 | 실패했어요. 다시 시도해 주세요. |
| That name can’t be used. Try another one. | 这个名字不能用，换一个吧。 | 這個名字不能用，換一個吧。 | その名前は使えません。別の名前にしてください。 | 그 이름은 쓸 수 없어요. 다른 이름을 써 주세요. |
| That photo couldn't be opened. Try another one. | 这张照片打不开，换一张试试。 | 這張相片打不開，換一張試試。 | その写真は開けませんでした。別の写真で試してください。 | 그 사진을 열 수 없습니다. 다른 사진으로 해보세요. |
| That picture can't be read from Photos. | 这张照片从相册里读不出来。 | 這張照片從相簿裡讀不出來。 | その写真を写真アプリから読み込めません。 | 그 사진을 사진 앱에서 불러올 수 없어요. |
| That picture isn't there any more. | 那张照片已经不在了。 | 那張照片已經不在了。 | その写真はもうありません。 | 그 사진은 더 이상 없어요. |
| The account couldn't be deleted. Check the connection and try again. | 没能删除账号，请检查网络后再试。 | 沒能刪除帳號，請檢查網路後再試。 | アカウントを削除できませんでした。接続を確認してもう一度お試しください。 | 계정을 삭제하지 못했어요. 연결을 확인하고 다시 시도해 주세요. |
| The App Store could not be reached. Try again later. | 连不上 App Store，请稍后再试。 | 連不上 App Store，請稍後再試。 | App Storeに接続できません。しばらくしてからお試しください。 | App Store에 연결할 수 없습니다. 잠시 후 다시 시도하세요. |
| The App Store couldn’t confirm this purchase. Try Restore Purchases in the bag’s kit. | App Store 没能确认这笔购买。请到相机包的维护页点“恢复购买”试试。 | App Store 沒能確認這筆購買。請到相機包的維護頁點「恢復購買」試試。 | App Store がこの購入を確認できませんでした。バッグのキットで「購入を復元」をお試しください。 | App Store에서 이 구매를 확인하지 못했어요. 가방의 키트에서 구매 복원을 해 보세요. |
| The Camera Control button | 相机控制按钮 | 相機控制按鈕 | カメラコントロール | 카메라 제어 버튼 |
| The camera is used only to take pictures, and the photo library only to save them and to open pictures you choose to try a film on. | 相机只用来拍照；相册只用来保存照片，以及打开你选来试胶卷的照片。 | 相機只用來拍照；照片圖庫只用來儲存相片，以及打開你選來試底片的相片。 | カメラは撮影にのみ、写真ライブラリは保存と、フィルムを試すために選んだ写真を開くためにのみ使います。 | 카메라는 촬영에만, 사진 보관함은 저장과 필름을 시험할 사진을 여는 데에만 사용합니다. |
| The community opens soon. | 社区即将开放。 | 社群即將開放。 | コミュニティはまもなくオープンします。 | 커뮤니티가 곧 열려요. |
| The iPhone picture turning into the film · SHARE to send | iPhone 原图变成胶片的短视频 · 按 SHARE 发出 | iPhone 原圖變成底片的短片 · 按 SHARE 傳出 | iPhoneの写真がフィルムに変わる動画 · SHAREで送る | iPhone 원본이 필름으로 바뀌는 영상 · SHARE로 보내기 |
| The picture couldn’t be developed. | 照片处理失败。 | 相片處理失敗。 | 写真を現像できませんでした。 | 사진을 현상하지 못했습니다. |
| The picture couldn’t be prepared to share. | 这张照片没能准备好分享。 | 這張照片沒能準備好分享。 | 写真をシェアの準備ができませんでした。 | 사진을 공유할 준비를 하지 못했습니다. |
| The picture couldn’t be saved to Photos. | 保存到相册失败。 | 儲存到照片失敗。 | 写真に保存できませんでした。 | 사진에 저장하지 못했습니다. |
| The picture couldn’t be taken. Please try again. | 拍摄失败，请再试一次。 | 拍攝失敗，請再試一次。 | 撮影できませんでした。もう一度お試しください。 | 촬영하지 못했습니다. 다시 시도해 주세요. |
| The purchase didn't go through. Check the connection and try again. | 购买没有成功。请检查网络后再试一次。 | 購買沒有成功。請檢查網路後再試一次。 | 購入できませんでした。接続を確認して、もう一度お試しください。 | 구매가 완료되지 않았어요. 연결을 확인하고 다시 시도해 주세요. |
| The report didn't go through. Try again. | 举报没有发出去，请再试一次。 | 舉報沒有發出去，請再試一次。 | 報告できませんでした。もう一度お試しください。 | 신고가 전송되지 않았어요. 다시 시도해 주세요. |
| The video couldn’t be made. | 视频没能生成。 | 影片沒能產生。 | 動画を作れませんでした。 | 영상을 만들지 못했어요. |
| The video needs the iPhone picture, which wasn’t kept for this shot. Send the letter or the photo. | 这张没留下 iPhone 原图，做不了对比视频。可以发来信或照片。 | 這張沒留下 iPhone 原圖，做不了對比影片。可以傳來信或照片。 | この写真はiPhoneの元画像がないため動画にできません。レターか写真を送れます。 | 이 사진은 iPhone 원본이 없어 영상을 만들 수 없습니다. 편지나 사진을 보낼 수 있어요. |
| These pictures were deleted, or Koco can't see them with the access it has. | 这些照片已删除，或在当前的照片权限下看不到。 | 這些相片已刪除，或在目前的照片權限下看不到。 | これらの写真は削除されたか、現在のアクセス権では見えません。 | 이 사진들은 삭제되었거나 현재 접근 권한으로는 보이지 않습니다. |
| This Apple account has had this roll before. | 这个 Apple 账号以前领过这卷了。 | 這個 Apple 帳號以前領過這捲了。 | このAppleアカウントは以前このフィルムを受け取っています。 | 이 Apple 계정은 전에 이 필름을 받았어요. |
| This film can't be bought right now. Try again later. | 这卷暂时买不了，请稍后再试。 | 這卷暫時無法購買，請稍後再試。 | このフィルムは現在購入できません。しばらくしてからお試しください。 | 이 필름은 지금 구입할 수 없습니다. 나중에 다시 시도하세요. |
| This made my day. Send me one from yours. | 今天被这一幕治愈了，你也拍一张给我看看。 | 今天被這一幕療癒了，你也拍一張給我看看。 | 今日はこれに癒やされた。そっちも一枚撮って見せて。 | 오늘 이 장면에 힐링했어. 너도 한 장 찍어 보여 줘. |
| This theme has closed. | 这个题目已经结束了。 | 這個題目已經結束了。 | このお題は終わりました。 | 이 주제는 끝났어요. |
| This week’s theme | 本周题目 | 本週題目 | 今週のお題 | 이번 주 주제 |
| Those words can’t be posted. Try other ones. | 这句话发不了，换一句吧。 | 這句話發不了，換一句吧。 | その言葉は投稿できません。別の言葉にしてください。 | 그 말은 올릴 수 없어요. 다른 말로 해 주세요. |
| Three days in a row and it’s yours | 连续打卡三天，送你这一卷 | 連續打卡三天，送你這一卷 | 3日続けたらもらえる | 3일 연속이면 이 필름을 |
| Three days in a row, take one with Koco and put it in. Porto 400 is yours. Cats and sleepy people count too. | 连续三天，每天放一张用 Koco 拍的照片进来，Porto 400 就归你。猫猫、睡着的人也算。 | 連續三天，每天放一張用 Koco 拍的照片進來，Porto 400 就歸你。貓貓、睡著的人也算。 | 3日続けて、毎日Kocoで撮った写真を1枚入れよう。Porto 400がもらえる。猫も、寝てる人もOK。 | 3일 연속, 매일 Koco로 찍은 사진을 한 장씩 넣으면 Porto 400을 드려요. 고양이도, 잠든 사람도 OK. |
| Tips | 使用技巧 | 使用技巧 | 使い方のコツ | 사용 팁 |
| Today’s pictures | 今天拍的 | 今天拍的 | 今日の写真 | 오늘 찍은 사진 |
| Today’s theme | 今日题目 | 今日題目 | 今日のお題 | 오늘의 주제 |
| Try %lld | 试拍 %lld | 試拍 %lld | 試写 %lld | 체험 %lld |
| Try a film on your photos | 在自己的照片上试胶卷 | 在自己的相片上試底片 | 自分の写真でフィルムを試す | 내 사진에 필름 입혀 보기 |
| Try again | 重试 | 重試 | 再試行 | 다시 시도 |
| Try it | 试拍 | 試拍 | 試し撮り | 체험 촬영 |
| Try it · %lld free shots → | 试拍 · 免费 %lld 张 → | 試拍 · 免費 %lld 張 → | 試し撮り · 無料%lld枚 → | 체험 촬영 · 무료 %lld장 → |
| Try my photo | 用我的照片试试 | 用我的相片試試 | 自分の写真で試す | 내 사진으로 해보기 |
| Trying | 试拍中 | 試拍中 | 試し撮り中 | 체험 중 |
| Turn down | 不通过 | 不通過 | 却下 | 반려 |
| Use | 使用 | 使用 | 使う | 사용 |
| Version | 版本 | 版本 | バージョン | 버전 |
| Version %@ (%@) | 版本 %1$@（%2$@） | 版本 %1$@（%2$@） | バージョン %1$@（%2$@） | 버전 %1$@ (%2$@) |
| Video | 视频 | 影片 | 動画 | 동영상 |
| Viewfinder | 取景器 | 取景器 | ファインダー | 뷰파인더 |
| Violence | 暴力 | 暴力 | 暴力 | 폭력 |
| Voucher · choose a roll | 兑换凭证 · 挑一卷 | 兌換憑證 · 挑一捲 | 引換券 · 1本選ぶ | 교환권 · 필름 고르기 |
| Voucher: kept for you | 兑换凭证：已为你留着 | 兌換憑證：已為你留著 | 引換券：保管中 | 교환권: 보관 중 |
| Waiting | 审核中 | 審核中 | 審査中 | 검토 중 |
| Waiting %lld | 待审 %lld | 待審 %lld | 審査待ち %lld | 검토 대기 %lld |
| What to share | 分享什么 | 分享什麼 | シェアするもの | 공유할 것 |
| Where your pictures go | 照片存在这里 | 照片存在這裡 | 写真の保存先 | 사진이 저장되는 곳 |
| Write a comment | 写留言 | 寫留言 | コメントを書く | 댓글 쓰기 |
| Yesterday’s free roll · keep it for %@ → | 昨天的限免 · %@ 留下它 → | 昨天的限免 · %@ 留下它 → | 昨日の無料フィルム · %@で手元に → | 어제의 무료 필름 · %@에 소장 → |
| You won’t see %@’s pictures. | 不会再看到 %@ 的照片。 | 不會再看到 %@ 的照片。 | %@ さんの写真は表示されなくなります。 | %@ 님의 사진이 더 이상 보이지 않아요. |
| Your account and everything in it are deleted, and Koco's access to your Apple ID is withdrawn. | 账号和里面的一切都已删除，Koco 对你 Apple ID 的访问已撤回。 | 帳號和裡面的一切都已刪除，Koco 對你 Apple ID 的存取已撤回。 | アカウントとその内容を削除し、KocoのApple IDへのアクセスを取り消しました。 | 계정과 모든 내용을 삭제했고 Koco의 Apple ID 접근을 철회했어요. |
| Your account and everything in it are deleted. | 账号和里面的一切都已删除。 | 帳號和裡面的一切都已刪除。 | アカウントとその内容を削除しました。 | 계정과 모든 내용을 삭제했어요. |
| Your account and everything in it are deleted. Withdrawing Koco's access to your Apple ID will be tried again shortly. | 账号和里面的一切都已删除。撤回 Koco 对你 Apple ID 的访问稍后会再试一次。 | 帳號和裡面的一切都已刪除。撤回 Koco 對你 Apple ID 的存取稍後會再試一次。 | アカウントとその内容を削除しました。Apple IDへのアクセスの取り消しは、まもなく再試行します。 | 계정과 모든 내용을 삭제했어요. Apple ID 접근 철회는 곧 다시 시도할게요. |
| Your Koco pictures | 用 Koco 拍的照片 | 用 Koco 拍的照片 | Koco で撮った写真 | Koco로 찍은 사진 |
| Your photo compared with %@ | 你的照片与 %@ 的对比 | 你的相片與 %@ 的比較 | あなたの写真と%@の比較 | 내 사진과 %@ 비교 |
| Your rewards will be here. | 你的奖励会放在这里。 | 你的獎勵會放在這裡。 | ごほうびはここに届きます。 | 보상은 여기에 모여요. |
| Yours | 已拥有 | 已擁有 | 所有 | 보유 |
| Zoom | 变焦 | 變焦 | ズーム | 줌 |
| “I can’t stop watching my dog sleep. So soothing!” | 「我总是忍不住看我睡着的狗狗 太治愈！」 | 「我總是忍不住看我睡著的狗狗 太療癒！」 | 「寝てるうちの犬、つい見ちゃう。癒やされる！」 | 「잠든 우리 강아지, 자꾸 보게 돼. 너무 힐링!」 |
| ‹ Back | ‹ 返回 | ‹ 返回 | ‹ 戻る | ‹ 뒤로 |
