import 'package:flutter/material.dart';

import '../../domain/shared/vault_backup_policy.dart';
import '../session/session_timeout_policy.dart';
import 'legal_disclosures.dart';

class AboutTabCopy {
  const AboutTabCopy({
    required this.label,
    required this.heroIcon,
    required this.heroTitle,
    required this.heroBody,
    required this.chips,
    required this.sections,
  });

  final String label;
  final IconData heroIcon;
  final String heroTitle;
  final String heroBody;
  final List<String> chips;
  final List<AboutSectionCopy> sections;
}

class AboutSectionCopy {
  const AboutSectionCopy({
    required this.title,
    required this.subtitle,
    required this.items,
  });

  final String title;
  final String subtitle;
  final List<AboutItemCopy> items;
}

class AboutItemCopy {
  const AboutItemCopy({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

/// 設定「介紹」子頁文案（單一來源）。
abstract final class SettingsAboutCopy {
  static const String pageTitle = '介紹';

  static List<AboutTabCopy> get tabs => <AboutTabCopy>[
    AboutTabCopy(
      label: '簡介',
      heroIcon: Icons.menu_book_rounded,
      heroTitle: 'Quill Diary',
      heroBody:
          '專為私人日記設計的離線加密 App。從建立日記庫、解鎖、撰寫、搜尋到備份，都以本機加密為前提，內容預設留在你的裝置上。',
      chips: <String>[
        '僅 Android',
        '離線優先',
        '本機加密',
        '全文搜尋',
        '完整備份',
      ],
      sections: <AboutSectionCopy>[
        AboutSectionCopy(
          title: '核心特色',
          subtitle: '先掌握產品定位，其餘分頁再說明各模組細節。',
          items: <AboutItemCopy>[
            AboutItemCopy(
              icon: Icons.lock_outline_rounded,
              title: '本機加密保存',
              body: '日記與附件不以明文留在日記庫中。除非你主動備份或匯出，內容不會自動離開裝置。',
            ),
            AboutItemCopy(
              icon: Icons.health_and_safety_outlined,
              title: '可信裝置與復原金鑰',
              body: '日常可用可信裝置快速解鎖；換機、還原或可信狀態失效時，則需輸入復原金鑰。',
            ),
            AboutItemCopy(
              icon: Icons.search_rounded,
              title: '解鎖後全文搜尋',
              body: '可搜尋標題、標籤與內文。搜尋索引只在解鎖期間開啟，鎖定後會關閉。',
            ),
          ],
        ),
        AboutSectionCopy(
          title: '主畫面導覽',
          subtitle: '解鎖後的主畫面有四個分頁，各自對應不同的瀏覽方式。',
          items: <AboutItemCopy>[
            AboutItemCopy(
              icon: Icons.view_list_rounded,
              title: '日記列表',
              body: '依時間瀏覽日記，可搜尋標題、內文或標籤，也能選取多篇後匯出 HTML 或刪除。',
            ),
            AboutItemCopy(
              icon: Icons.calendar_month_outlined,
              title: '日曆',
              body: '以月曆查看撰寫紀錄，點選日期即可篩選當天的日記。',
            ),
            AboutItemCopy(
              icon: Icons.sell_outlined,
              title: '標籤',
              body: '管理標籤樣式與清單，點選標籤可預覽套用該標籤的日記摘要。',
            ),
            AboutItemCopy(
              icon: Icons.insights_outlined,
              title: '總覽',
              body: '查看撰寫統計、熱門標籤與範圍篩選，並可匯出年度、月份或全部回顧。',
            ),
          ],
        ),
        AboutSectionCopy(
          title: '日常使用體驗',
          subtitle: '除了保護資料，也盡量讓常用操作順手。',
          items: <AboutItemCopy>[
            AboutItemCopy(
              icon: Icons.edit_note_rounded,
              title: '日記編輯器',
              body: '支援 Markdown、標籤、圖片與一般附件。既有日記先檢視再編輯，新建日記直接進入編輯模式。',
            ),
            AboutItemCopy(
              icon: Icons.save_as_outlined,
              title: '草稿接續',
              body: '編輯中的內容會自動保存成加密草稿。再次開啟時，可選擇還原上次進度。',
            ),
            AboutItemCopy(
              icon: Icons.swap_horiz_rounded,
              title: '備份與可攜式匯出',
              body: '完整備份保存整個加密日記庫；Markdown / HTML 匯出則用來閱讀、整理或再匯入。',
            ),
          ],
        ),
        AboutSectionCopy(
          title: '你可以怎麼理解它',
          subtitle: '核心不是雲端同步，而是讓你掌握自己的私人資料。',
          items: <AboutItemCopy>[
            AboutItemCopy(
              icon: Icons.auto_stories_outlined,
              title: '私人日記工具',
              body: '優先服務個人日記、回顧與保護，而非團隊協作或公開分享。',
            ),
            AboutItemCopy(
              icon: Icons.storage_rounded,
              title: '加密資料庫',
              body: '也可視為一個能搜尋、備份、還原與匯出的本機加密日記資料庫。',
            ),
            AboutItemCopy(
              icon: Icons.phonelink_lock_outlined,
              title: '安全與日常平衡',
              body: '可信裝置讓重新進入不必每次都走最重的流程，復原金鑰則是最終保障。',
            ),
          ],
        ),
        AboutSectionCopy(
          title: '開源與品牌',
          subtitle: '原始碼公開建立信任；品牌名稱另受保護。',
          items: <AboutItemCopy>[
            AboutItemCopy(
              icon: Icons.code_rounded,
              title: 'AGPL-3.0 開源',
              body: '原始碼以 GNU Affero General Public License v3.0 發布。若修改並發布，須以相同授權公開對應的完整原始碼。',
            ),
            AboutItemCopy(
              icon: Icons.verified_outlined,
              title: 'Quill Diary 品牌',
              body: LegalDisclosures.brandDisclaimer,
            ),
          ],
        ),
      ],
    ),
    AboutTabCopy(
      label: '解鎖與會話',
      heroIcon: Icons.lock_person_rounded,
      heroTitle: '解鎖後會維持一段可用期間',
      heroBody:
          'App 解鎖後會維持一段可讀寫日記庫的期間。這一頁說明何時算已解鎖、背景多久會鎖定，以及回到 App 時要如何重新驗證。',
      chips: <String>[
        '解鎖方式',
        '可信裝置',
        '復原金鑰',
        '背景逾時',
      ],
      sections: <AboutSectionCopy>[
        AboutSectionCopy(
          title: '三種解鎖方式',
          subtitle: '可在設定頁切換；決定鎖定後回到 App 時，要用哪種方式重新驗證。',
          items: <AboutItemCopy>[
            AboutItemCopy(
              icon: Icons.no_encryption_gmailerrorred_outlined,
              title: '無',
              body: '鎖定後不額外驗證，直接解鎖。適合尚未設定螢幕鎖的裝置，安全性較低。',
            ),
            AboutItemCopy(
              icon: Icons.lock_outline,
              title: '裝置螢幕鎖',
              body: '鎖定後以螢幕鎖（PIN、圖案或密碼）驗證。請先在裝置設定中建立螢幕鎖。',
            ),
            AboutItemCopy(
              icon: Icons.fingerprint_rounded,
              title: '生物驗證',
              body: '鎖定後以指紋或臉部驗證；取消或失敗時可改以螢幕鎖，不必輸入復原金鑰。',
            ),
            AboutItemCopy(
              icon: Icons.info_outline_rounded,
              title: '共同前提',
              body: '螢幕鎖與生物驗證都要求裝置已設定螢幕鎖；切換至生物驗證時，另須已登錄生物辨識。',
            ),
          ],
        ),
        AboutSectionCopy(
          title: '解鎖期間如何運作',
          subtitle: '解鎖期間才能讀寫正式日記、草稿與搜尋索引。',
          items: <AboutItemCopy>[
            AboutItemCopy(
              icon: Icons.lock_open_rounded,
              title: '解鎖中',
              body: '解鎖後，日記庫、草稿與搜尋索引都能正常使用。',
            ),
            AboutItemCopy(
              icon: Icons.lock_clock_outlined,
              title: '背景逾時',
              body:
                  '背景超過 ${sessionBackgroundTimeoutLabel()} 未使用會鎖定，短時間切換 App 不會。'
                  '備份、還原或匯入匯出進行中則暫不鎖定。鎖定後回到 App 時，請依解鎖方式重新驗證。',
            ),
            AboutItemCopy(
              icon: Icons.sync_rounded,
              title: '回到 App 時',
              body: '「無」模式逾時後直接恢復；「螢幕鎖」與「生物驗證」則會跳出系統驗證對話框，完成後才能繼續。',
            ),
          ],
        ),
        AboutSectionCopy(
          title: '什麼時候需要復原金鑰',
          subtitle: '可信裝置是便利路徑，復原金鑰才是換機與還原的最終依據。',
          items: <AboutItemCopy>[
            AboutItemCopy(
              icon: Icons.warning_amber_rounded,
              title: '可信狀態失效',
              body: '裝置上的可信狀態失效，或與目前解鎖方式不一致時，就不能只靠可信裝置進入。',
            ),
            AboutItemCopy(
              icon: Icons.key_outlined,
              title: '還原後不匹配',
              body: '還原備份後，若可信狀態與日記庫不再對應，會要求輸入建立該備份時保存的復原金鑰。',
            ),
            AboutItemCopy(
              icon: Icons.key_outlined,
              title: '復原金鑰的地位',
              body: '復原金鑰不是附加功能，而是換機、還原與可信裝置失效時的必要憑證。',
            ),
          ],
        ),
      ],
    ),
    AboutTabCopy(
      label: '加密與解密',
      heroIcon: Icons.enhanced_encryption_outlined,
      heroTitle: '資料先加密，再寫進日記庫',
      heroBody:
          'Quill Diary 目前使用 LDJ2 格式保護日記、附件與其他敏感內容。這一頁關心的是加密檔案長什麼樣、如何打開，以及復原金鑰在其中扮演什麼角色。',
      chips: <String>[
        'LDJ2',
        'AES-256-GCM',
        'Argon2id',
        'Vault 金鑰',
      ],
      sections: <AboutSectionCopy>[
        AboutSectionCopy(
          title: 'LDJ2 在做什麼',
          subtitle: '它不是單純把內容鎖起來，而是把檔案金鑰和解鎖路徑一起定義好。',
          items: <AboutItemCopy>[
            AboutItemCopy(
              icon: Icons.key_outlined,
              title: '每個檔案都有自己的 fileKey',
              body: '每個加密檔案都會先產生一把隨機 `fileKey`，不與其他檔案共用。',
            ),
            AboutItemCopy(
              icon: Icons.lock_rounded,
              title: '正文用 AES-256-GCM 加密',
              body: '日記正文與附件內容以 `AES-256-GCM` 加密，並帶完整性驗證，避免內容或 header 被悄悄竄改。',
            ),
            AboutItemCopy(
              icon: Icons.layers_outlined,
              title: '兩層金鑰架構',
              body: '檔案層的 `fileKey` 以 recovery slot 包在 header；可信裝置與復原金鑰則都透過 vault 層的 `recoveryWrapKey` 進入日記庫。',
            ),
          ],
        ),
        AboutSectionCopy(
          title: '解密路徑',
          subtitle: '打開內容分兩段：先進入 vault，再解開各檔。',
          items: <AboutItemCopy>[
            AboutItemCopy(
              icon: Icons.phonelink_lock_outlined,
              title: '可信裝置（Vault 層）',
              body: '可信裝置 session 會透過 Android Keystore unwrap vault 層 wrapped recovery key，取得 `recoveryWrapKey` 後才能讀寫日記庫。',
            ),
            AboutItemCopy(
              icon: Icons.key_outlined,
              title: 'Recovery Slot（檔案層）',
              body: '不論從可信裝置或復原金鑰進入，都用 `recoveryWrapKey` 從各檔 header 的 recovery slot 解出 `fileKey`，再解密正文。',
            ),
            AboutItemCopy(
              icon: Icons.error_outline_rounded,
              title: '失敗就整體失敗',
              body: '若 vault 金鑰錯誤、slot unwrap 失敗，或 header / 正文被破壞，整個解密都應該失敗，不會默默回傳可疑內容。',
            ),
          ],
        ),
        AboutSectionCopy(
          title: '復原金鑰與 manifest',
          subtitle: '復原金鑰不直接拿來解正文，而是先用來推導包裝金鑰。',
          items: <AboutItemCopy>[
            AboutItemCopy(
              icon: Icons.enhanced_encryption_outlined,
              title: 'Argon2id',
              body: '使用者輸入的復原金鑰會先經過 Argon2id，推導出 recovery wrapping key，而不是直接拿去解內容。',
            ),
            AboutItemCopy(
              icon: Icons.fact_check_outlined,
              title: 'Manifest 驗證',
              body: '`vault/manifest.json.enc` 是驗證復原金鑰時的首選目標，因為它穩定且固定存在。',
            ),
            AboutItemCopy(
              icon: Icons.verified_user_outlined,
              title: 'Vault 進入點',
              body: 'recovery wrapping key 是進入整個日記庫的關鍵：解開各檔 recovery slot、包裝可信裝置資料，並衍生搜尋索引金鑰。',
            ),
          ],
        ),
      ],
    ),
    AboutTabCopy(
      label: '索引與搜尋',
      heroIcon: Icons.manage_search_rounded,
      heroTitle: '搜尋靠的是加密索引，不是逐篇掃描日記',
      heroBody:
          '正式資料留在 `vault/`，搜尋則透過另一份加密 SQLite 索引完成。這份索引是衍生資料，可以重建，但在使用期間仍屬敏感內容。',
      chips: <String>[
        'SQLite',
        'SQLCipher',
        'HKDF',
        '可重建',
      ],
      sections: <AboutSectionCopy>[
        AboutSectionCopy(
          title: '索引資料庫的角色',
          subtitle: '它是搜尋層，不是正式日記資料本體。',
          items: <AboutItemCopy>[
            AboutItemCopy(
              icon: Icons.manage_search_outlined,
              title: '讓搜尋更快',
              body: '主畫面搜尋不逐篇掃描加密日記，而是對索引查詢標題、標籤與內文。',
            ),
            AboutItemCopy(
              icon: Icons.storage_rounded,
              title: '與正式資料分開',
              body: '正式日記仍以 `vault/` 為權威來源；索引只保留搜尋與顯示所需的衍生資料。',
            ),
            AboutItemCopy(
              icon: Icons.lock_outline_rounded,
              title: '索引本身也加密',
              body: '索引路徑雖然和日記庫分開，但 SQLCipher 金鑰會由 `recoveryWrapKey + vaultId` 經 HKDF-SHA256 衍生（`info: quill_diary:index:v1`），不以明文 SQLite 留在裝置上。',
            ),
          ],
        ),
        AboutSectionCopy(
          title: '生命週期',
          subtitle: '索引只在有效解鎖 session 期間存在可用狀態。',
          items: <AboutItemCopy>[
            AboutItemCopy(
              icon: Icons.lock_open_rounded,
              title: '解鎖後開啟',
              body: '解鎖成功後，`openForSession` 會綁定目前 `vaultId` 開啟加密索引；`ensureIndexReady` 再檢查 schema 版本，必要時才重建。',
            ),
            AboutItemCopy(
              icon: Icons.save_outlined,
              title: '正式寫入才同步',
              body: '草稿編輯中不更新索引；只有正式 `saveEntry()` 或匯入寫入日記庫後，索引才會同步。',
            ),
            AboutItemCopy(
              icon: Icons.lock_outline_rounded,
              title: '鎖定後關閉',
              body: '當 session 鎖定、timeout，或還原流程要求重建時，索引會關閉、刪除或重新生成。',
            ),
          ],
        ),
        AboutSectionCopy(
          title: '搜尋與重建',
          subtitle: '索引是可丟棄再生成的資料層。',
          items: <AboutItemCopy>[
            AboutItemCopy(
              icon: Icons.search_rounded,
              title: '命中欄位',
              body: '查詢會先正規化，再比對 `title_search_text`、`body_search_text`（Markdown 正文正規化後）與 `entry_tags.tag_normalized`；`preview_text` 只用於摘要顯示。',
            ),
            AboutItemCopy(
              icon: Icons.manage_search_outlined,
              title: '什麼時候重建',
              body: '索引格式不符、`search_schema_version` 落後、復原金鑰重新解鎖，或完整備份還原後，都可能觸發重建。',
            ),
            AboutItemCopy(
              icon: Icons.sell_outlined,
              title: '標籤樣式不是索引權威來源',
              body: '`vault/tag_styles.json` 才是標籤樣式權威來源，SQLite 的 `tag_styles` 表只是顏色快取。',
            ),
          ],
        ),
      ],
    ),
    AboutTabCopy(
      label: '日記編輯器',
      heroIcon: Icons.edit_note_rounded,
      heroTitle: '正式日記、草稿與附件暫存分開管理',
      heroBody:
          '日記編輯器不把「正在編輯中」和「已正式寫入」混在一起。它會先把變更寫成加密草稿，等你確認儲存後，再更新日記庫與搜尋索引。',
      chips: <String>[
        'Markdown',
        '草稿',
        '附件',
        '未儲存',
      ],
      sections: <AboutSectionCopy>[
        AboutSectionCopy(
          title: '這個編輯器能做什麼',
          subtitle: '目前實作已涵蓋日常日記撰寫需要的主要能力。',
          items: <AboutItemCopy>[
            AboutItemCopy(
              icon: Icons.edit_outlined,
              title: '新建與編輯既有日記',
              body: '新建日記直接進入編輯模式；既有日記預設先檢視，按編輯後才開始追蹤變更。',
            ),
            AboutItemCopy(
              icon: Icons.edit_note_rounded,
              title: 'Markdown、標題、日期、標籤',
              body: '內文以 Markdown 純文字編輯，並可同時調整標題、日期、時間與標籤。正式儲存時標題必填。',
            ),
            AboutItemCopy(
              icon: Icons.attach_file,
              title: '圖片與一般附件',
              body: '可加入多張圖片或一般檔案。圖片附件可重新排序，也可刪除既有或待儲存中的附件。',
            ),
          ],
        ),
        AboutSectionCopy(
          title: '草稿機制',
          subtitle: '草稿是編輯器的一部分，不是獨立資料庫。',
          items: <AboutItemCopy>[
            AboutItemCopy(
              icon: Icons.save_as_outlined,
              title: '即時保存',
              body: '編輯模式下，標題、日期、標籤、內文與附件一有變更，就會加密寫入 `drafts/{draftKey}/draft.json.enc`。',
            ),
            AboutItemCopy(
              icon: Icons.restore_page_outlined,
              title: '再次開啟時可還原',
              body: '重新開啟同一篇日記或未完成新建時，若本地仍有草稿，會先詢問是否還原。',
            ),
            AboutItemCopy(
              icon: Icons.auto_delete_outlined,
              title: '儲存或取消後清理',
              body: '正式儲存成功後會刪除草稿；若取消且相對已儲存內容沒有變更，也會靜默清掉草稿。',
            ),
          ],
        ),
        AboutSectionCopy(
          title: '和其他模組的邊界',
          subtitle: '編輯中的資料不會被誤認成正式內容。',
          items: <AboutItemCopy>[
            AboutItemCopy(
              icon: Icons.search_off_outlined,
              title: '草稿不進搜尋索引',
              body: '搜尋永遠只看正式寫入日記庫的內容，草稿不會出現在搜尋結果裡。',
            ),
            AboutItemCopy(
              icon: Icons.archive_outlined,
              title: '草稿不進完整備份',
              body: '`backup_*.zip` 只封裝正式 `vault/`，不包含 `drafts/`。完整備份還原也不會主動清掉既有草稿。',
            ),
            AboutItemCopy(
              icon: Icons.info_outline_rounded,
              title: '未儲存提示',
              body: '日記列表與檢視模式會顯示「未儲存」標記，提醒你這篇日記仍有本地草稿。',
            ),
          ],
        ),
      ],
    ),
    AboutTabCopy(
      label: '備份與還原',
      heroIcon: Icons.storage_rounded,
      heroTitle: '完整備份與可攜式匯出是兩條不同的路',
      heroBody:
          '完整備份是用來保存整個加密日記庫並供之後完整還原；Markdown / HTML 匯出則是把內容帶出去閱讀、整理或再匯入。這兩者不能混用。',
      chips: <String>[
        'backup_*.zip',
        'Markdown',
        'HTML',
        '完整還原',
      ],
      sections: <AboutSectionCopy>[
        AboutSectionCopy(
          title: '完整備份',
          subtitle: '備份保存的是整個正式日記庫，不是解密後的可讀文件。',
          items: <AboutItemCopy>[
            AboutItemCopy(
              icon: Icons.archive_outlined,
              title: '封裝內容',
              body: '`backup_*.zip` 會封裝 `vault/` 內的正式資料，包括日記、附件、復原設定與標籤目錄；不包含 `drafts/`。',
            ),
            AboutItemCopy(
              icon: Icons.fact_check_outlined,
              title: '建立前先檢查',
              body: '完整備份建立後會先經過 `inspectBackup` 檢查結構，未通過就不會交付到本機、外部資料夾或雲端。',
            ),
            AboutItemCopy(
              icon: Icons.history_rounded,
              title: '保留份數',
              body: '本機備份與 Google Drive 都保留最新 ${VaultBackupPolicy.retainCount} 份；外部資料夾匯出不自動輪替或刪舊檔。',
            ),
          ],
        ),
        AboutSectionCopy(
          title: '還原會做什麼',
          subtitle: '還原不是加回缺少的幾篇日記，而是直接用備份內容覆寫目前正式日記庫。',
          items: <AboutItemCopy>[
            AboutItemCopy(
              icon: Icons.warning_amber_rounded,
              title: '覆寫 `vault/`',
              body: '不論備份來源來自 App 內清單還是外部 zip，`restoreBackupZip` 都會覆寫目前 `vault/`。',
            ),
            AboutItemCopy(
              icon: Icons.manage_search_outlined,
              title: '刪除並重建索引',
              body: '還原時會刪除既有索引；session 啟動後才重建。同 vault 且可信狀態仍對應時，可沿用還原前 session 免再次驗證，否則會要求復原金鑰或重新解鎖。',
            ),
            AboutItemCopy(
              icon: Icons.key_outlined,
              title: '復原金鑰仍可能被要求',
              body: '若目前可信狀態無法直接對應到該備份，流程會要求輸入建立那份備份時保存的復原金鑰。',
            ),
          ],
        ),
        AboutSectionCopy(
          title: '可攜式匯入與匯出',
          subtitle: '這條路處理的是內容交換，不是完整日記庫覆寫。',
          items: <AboutItemCopy>[
            AboutItemCopy(
              icon: Icons.file_download_outlined,
              title: '匯入',
              body: '可從 zip、Markdown、HTML 或資料夾匯入。若是 zip，會先嘗試辨識 Easy Diary 完整備份，再回到 Markdown / HTML 流程。',
            ),
            AboutItemCopy(
              icon: Icons.file_upload_outlined,
              title: '匯出',
              body: '設定頁可匯出 `markdown_*.zip`；主畫面選取日記或總覽分頁「匯出回顧」可匯出 `html_*.html`，兩者都是可讀內容輸出。',
            ),
            AboutItemCopy(
              icon: Icons.swap_horiz_rounded,
              title: '本質差異',
              body: '完整備份走的是加密 `vault/` 封存與還原；可攜式流程則是逐篇寫入或輸出內容，不會直接覆寫整個日記庫。',
            ),
          ],
        ),
      ],
    ),
  ];
}
