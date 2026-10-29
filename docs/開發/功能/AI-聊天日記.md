# AI 聊天日記

從首頁新增入口選擇聊天寫作；未完成聊天列在首頁，正式儲存日記後可由日記檢視頁開啟完成聊天。手機直接連線使用者指定的服務，開發者不提供 AI 中繼伺服器。

## 連線與提示詞

| 提供商 | 協定與圖片傳送 |
|------|------|
| OpenAI | Responses；圖片經 Files API 上傳後引用 |
| Claude | Messages；圖片經 Files API 上傳後引用 |
| Gemini | GenerateContent；圖片經 Files API 上傳後引用 |
| Custom | Chat Completions、Responses、Claude Messages、Gemini GenerateContent 或 Ollama Chat；圖片使用所選協定的內嵌格式 |

Custom 的 Base URL 可含 `/v1`、`/v1beta` 或 `/api`；原生協定需要時補上預設前綴，已有版本路徑時不重複加入。Chat Completions 的 Base URL 須包含服務要求的 API 前綴。模型可手動輸入；模型選單只在開啟時查詢，最多等待 30 秒，失敗仍能手動輸入。Ollama 透過 `/api/show` 的 `capabilities` 判斷圖片支援，不依模型名稱猜測。

API Key 放在裝置安全儲存。Custom 金鑰依正規化網址分開保存；切換網址先清空顯示，再讀取該目的地的金鑰。清空欄位並儲存即可刪除該目的地金鑰。Claude Messages 額外提供 Workspace ID。

連線測試送出一則「Reply with OK.」的非串流請求，確認有文字回覆，最多等待 45 秒。失敗顯示錯誤種類與 HTTP 狀態，不顯示服務商回應本文。一般請求等待標頭及讀取串流／非串流本文都有五分鐘逾時；本文逾時會中止連線。

聊天與日記生成各有一份系統提示詞，繁中／英文預設放在 `lib/l10n/*.arb`。覆寫值為 null 時使用目前 App 語言的預設；自訂內容不隨語系切換改寫，還原只清除該用途的覆寫。設定預覽與請求共用 `resolveChatDiaryPrompt`。

聊天室儲存新設定後，停止舊請求並保留進度，下一次改用新設定。舊回覆保留連線與有效提示詞快照；日記生成另存生成時的快照。資料傳送、可能計費及文字隱藏不會遮蔽照片的說明放在設定內；提供商政策連結見[隱私權政策](../../privacy-policy.md)。

## 訊息與分支

- 固定歡迎訊息只在本機顯示，不進入聊天請求、生成上下文或日記事實；續聊沿用原開場。
- `parentId` 建立訊息樹，`selectedChildren` 保存各分支選取，`activeMessages` 是目前路徑。編輯重送與重新回覆都新增版本；切換版本只讀本機。
- 編輯期間以 `editBackup` 保存未送輸入、私密標記與附件，取消或送出後還原。取消編輯只移除沒有任何分支、輸入或備份引用的圖片。
- 聊天列表延遲建立可見訊息；接近底部時跟隨串流，閱讀舊內容時保留位置。等待動畫尊重減少動態效果設定。
- 傳送中停用功能按鈕，仍可捲動與返回。失敗、中斷回覆保留在原位置，可重試；一般操作錯誤使用共用 toast。
- 傳送預覽包含目前路徑的使用者訊息、完整 AI 回覆與未送內容，系統提示詞預設收合；不包含失敗／中斷回覆及日記生成請求。編輯訊息時只預覽該訊息以前的上下文。
- 完成聊天唯讀，仍可切換版本。進入背景時停止請求、遮蔽畫面並關閉圖片與預覽；鎖定時清除畫面中的聊天與輸入。

## 文字隱私

`ChatDiaryPrivacyProcessor` 只替換使用者反白的區間，不把相同原文套到其他未反白位置。每次請求依原文與保存的區間重算使用者外送文字；有效提示詞則會替換目前分支已標記過的私密原文。接著對剩餘文字比對人物名冊的姓名與別名。

人物與私密片段共用遞增序號，使用 `⟦P01⟧`、`⟦S02⟧` 等至少兩位的大寫十六進位代號，超過 `FF` 繼續為 `100`。同一人物的姓名與別名共用人物 ID 對應的代號；同一私密原文沿用代號。序號不循環、不重用。

原文、私密區間與對照表只在本機加密保存。還原與私密補記只處理目前分支；生成未引用但已送出的私密片段會在手機補進「私密補記」，不把還原後原文送回模型。不另外辨識電話、地址或一般敏感詞，也不遮蔽照片內容。

## 圖片與清理

聊天與一般日記共用系統挑圖及圖片檢視。聊天保存原圖；一般日記新挑選的圖片仍套用個人化壓縮設定。圖片交接不重選、不重壓縮。

傳送副本保留原尺寸及 JPEG／PNG／WebP／GIF 壓縮像素，只保留顯示所需的區塊、色彩、方向與動畫資料，移除私密及未知附屬區塊；動畫 WebP 影格內也會清理。其他可解碼格式轉為原尺寸 PNG。大型圖片的純位元組清理在背景 isolate 執行；不另設張數或容量上限。

內建提供商上傳成功後，先保存遠端清理紀錄才發布上傳快取。紀錄失敗會嘗試刪除遠端檔案，重試重新上傳。清理紀錄依當次連線快照分檔，不含 API Key；服務切換後不混用檔案識別。完成或刪除聊天時嘗試清理，失敗於之後進入 AI 功能時重試；未完成聊天的遠端圖片保留。重試只移除這次已刪除的參照，不覆寫等待期間新增的紀錄。

本機圖片引用包含所有分支、目前輸入與編輯備份。取消附圖後晚到的寫入也會刪除；清理同時涵蓋圖片與 `.previous`、`.tmp`。

## 儲存與日記交接

| 位置 | 內容 |
|------|------|
| `vault/chat_diary_drafts/<chatId>/` | 未完成聊天、原圖及 `editor/` 下的日記生成草稿 |
| `vault/entries/YYYY/MM/<entryId>.chat.json.enc` | 與正式日記相鄰的加密聊天 JSON，包含所有分支及快照 |
| `vault/chat_diary_remote_cleanup/` | 加密的遠端檔案清理紀錄 |
| `quill_diary_ai` 安全儲存 namespace | 連線、API Key、自訂提示詞及人物隱藏偏好 |

一段聊天共用一份日記草稿。生成文字以 Markdown 一級標題開頭時取該行為標題，其餘為內文；否則全部保留為內文。`generatedFromMessageId` 記錄來源版本，切換分支或新增內容後提示草稿可能過期；內容指紋用來辨識人工編輯，取代前要求確認。

生成附件逐張解密、暫存，發布前再次確認操作有效。發布前取消或失敗只刪除本次暫存，保留原草稿與附件；提交點同步更新來源、連線、提示詞與內容指紋，提交後即使離頁仍完成本機保存。

目前分支圖片依本機附件 ID 去重並保持首次送出順序。正式日記成功提交後才保存完成聊天、刪除整個聊天草稿資料夾及解密預覽。收尾中斷會在下次載入草稿清單時補完；重複收尾可辨識已完成聊天。

完成聊天只沿用正式日記附件。未收錄或已移除的照片顯示「圖片已刪除」；從日記返回時重新讀取。刪除聊天不刪日記與附件；刪除日記包含相鄰聊天及恢復檔。改日期與修復搬移同時處理聊天；重複日記的聊天須先保留於權威位置，內容衝突時保留來源並回報。

vault 內加密檔沿用 LDJ2 與復原金鑰輪替。完整備份、還原與可攜式匯出的包含／排除以[備份與還原](備份與還原.md)為準。

## 驗證

自動測試使用合成內容、mock、本機 HTTP 服務及測試日記庫，不呼叫付費 API。核心案例涵蓋隱私區間與分支隔離、取消操作的磁碟清理、生成草稿保護、備份往返、連線逾時及長對話捲動。

人工驗收使用非私密的繁中與英文案例：尊重拒答與換題、不捏造事件或情緒、區分未來計畫與已發生事實、採用使用者更正、保留私密代號及指定語言。連線與圖片可能計費，使用測試者自己的金鑰。

### 開發入口與回歸分工

| 層 | 入口與測試重點 |
|------|------|
| domain | [`ChatDiarySession`](../../../lib/domain/chat_diary/chat_diary_session.dart) 保存訊息樹、選取與圖片引用；[`ChatDiaryPrivacyProcessor`](../../../lib/domain/chat_diary/chat_diary_privacy_processor.dart) 負責區間、代號與還原，使用純單元案例 |
| application | [`ChatDiaryController`](../../../lib/application/chat_diary/chat_diary_controller.dart) 協調操作版本、傳送、停止與生成；取消測試同時確認記憶體狀態與實際磁碟內容 |
| infrastructure | [`ChatDiaryStore`](../../../lib/infrastructure/chat_diary/chat_diary_store.dart) 管理加密檔與生成提交；[`AiClient`](../../../lib/infrastructure/ai/ai_client.dart) 管理協定、遠端檔案與傳輸；[`圖片處理器`](../../../lib/infrastructure/ai/ai_image_preparer.dart) 驗證清理後仍可顯示與保留動畫 |
| presentation | [`ChatDiaryPage`](../../../lib/presentation/chat_diary/chat_diary_page.dart) 驗證隱藏區間、編輯備份、分支切換、長對話延遲建立、捲動與編輯器往返 |

自動測試集中於 `test/domain/chat_diary/`、`test/application/chat_diary/`、`test/infrastructure/ai/`、`test/infrastructure/chat_diary/` 與 `test/presentation/chat_diary/`。協定測試驗證請求與回應，不代表真實模型會遵守所有寫作規則。

### 模型與實機驗收

| 案例 | 檢查結果 |
|------|------|
| 簡短敘述、拒答或要求換題 | 跟隨使用者方向，不強迫補充、不連續逼問 |
| 使用者更正時間、人物或事件 | 生成採用最新更正，不把舊版本與新版本混成兩件事 |
| 未來計畫、假設及未說明情緒 | 不改寫成已發生事實，不自行添加感受或動機 |
| 私密區間與人物別名 | 傳送預覽只在應替換處出現代號，日記在手機還原；其他分支不帶入 |
| 多圖、方向、透明與動畫 | 各提供商能接收可顯示的副本；日記交接保留原圖，未選分支圖片不誤加入 |
| 附圖或生成期間按停止／離頁 | 晚到寫入不留下孤兒圖片，原人工草稿與附件不被取消結果覆蓋 |
| 長對話與串流 | 不一次建立所有泡泡；閱讀舊訊息時不強制拉到底部 |
| 背景、鎖定與重新開啟 | 停止請求、關閉敏感預覽，解鎖後能接續加密草稿 |

發布到 Google Play 的額外內容回報與審查存取要求集中在[上架文件](../google/Google-Play-上架.md#ai-生成內容的送審缺口)；服務商測試成功不代表這些條件已完成。

## 傳輸與協定

Custom 的 HTTPS 可使用指定主機。HTTP 只允許 loopback、IPv4 私有網段與 IPv6 ULA；主機名稱、link-local 及公網 HTTP 會被拒絕。`validateAiEndpoint` 在送憑證前驗證，連線不跟隨重新導向，也不略過 TLS 驗證。Android 網路設定與權限見[Android 權限與資料揭露](../google/Android-權限與資料揭露.md)。

Responses 會送出 `store: false`，不代表零留存。Custom 的資料使用與留存由該服務決定。

API 依據：[OpenAI 官方文件：圖片與檔案參照](https://developers.openai.com/api/docs/guides/images-vision)、[Responses](https://developers.openai.com/api/reference/resources/responses/methods/create)、[Claude Messages](https://platform.claude.com/docs/en/api/messages/create)、[Gemini](https://ai.google.dev/api/models)、[Ollama](https://docs.ollama.com/api)。

[← 返回開發文件導覽](../README.md)
