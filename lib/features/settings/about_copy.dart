import 'package:flutter/material.dart';

import '../../domain/shared/vault_backup_policy.dart';
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

  static const List<AboutTabCopy> tabs = <AboutTabCopy>[
    AboutTabCopy(
      label: '首頁',
      heroIcon: Icons.menu_book_rounded,
      heroTitle: 'Quill Diary',
      heroBody:
          '為私人日記而設計的離線加密日記。這不是把加密黏在筆記工具外面的附加功能，而是從建立、解鎖、搜尋、編輯到備份，都圍繞同一套本機保護邏輯設計。',
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
          subtitle: '先理解這個 App 的定位，再看後面的細節。',
          items: <AboutItemCopy>[
            AboutItemCopy(
              icon: Icons.lock_outline_rounded,
              title: '本機加密保存',
              body: '日記與附件不以明文形式留在日記庫中。除非你主動備份或匯出，內容不會自動離開裝置。',
            ),
            AboutItemCopy(
              icon: Icons.health_and_safety_outlined,
              title: '可信裝置與復原金鑰',
              body: '日常使用可走可信裝置解鎖，真的需要救援或換機時則回到復原金鑰路徑。',
            ),
            AboutItemCopy(
              icon: Icons.search_rounded,
              title: '解鎖後全文搜尋',
              body: '標題、標籤與內文都能找。搜尋索引只在有效 session 期間開啟，鎖定後關閉。',
            ),
          ],
        ),
        AboutSectionCopy(
          title: '日常使用體驗',
          subtitle: '它不只是在保護資料，也盡量把常用操作做順。',
          items: <AboutItemCopy>[
            AboutItemCopy(
              icon: Icons.edit_note_rounded,
              title: '日記編輯器',
              body: '支援 Markdown、標籤、圖片與一般附件。既有日記先檢視再編輯，新建日記直接進入編輯模式。',
            ),
            AboutItemCopy(
              icon: Icons.save_as_outlined,
              title: '草稿接續',
              body: '編輯中的內容會自動保存成加密草稿。中斷後再次開啟，可選擇還原上次進度。',
            ),
            AboutItemCopy(
              icon: Icons.swap_horiz_rounded,
              title: '備份與可攜式匯出',
              body: '完整備份用來保存整個加密日記庫；Markdown / HTML 匯出則用來整理、攜出或再匯入。',
            ),
          ],
        ),
        AboutSectionCopy(
          title: '你可以怎麼理解它',
          subtitle: '這個專案的核心不是雲端同步，而是私人資料掌控。',
          items: <AboutItemCopy>[
            AboutItemCopy(
              icon: Icons.auto_stories_outlined,
              title: '私人日記工具',
              body: '它優先考慮的是個人日記、回顧與保護，而不是團隊協作或公開分享。',
            ),
            AboutItemCopy(
              icon: Icons.storage_rounded,
              title: '加密資料庫',
              body: '你也可以把它理解成一個能搜尋、備份、還原、匯出的本機加密日記資料庫。',
            ),
            AboutItemCopy(
              icon: Icons.phonelink_lock_outlined,
              title: '安全與日常平衡',
              body: '可信裝置讓日常重新進入不必每次都走最重的流程，但最終仍以復原金鑰作為底線。',
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
      heroTitle: '解鎖不是一次動作，而是一段 session',
      heroBody:
          'Quill Diary 會維持一段目前可讀寫日記庫的有效 session。這一頁只講什麼時候算已解鎖、何時要重新驗證，以及可信裝置如何影響重新進入體驗。',
      chips: <String>[
        'Session',
        '可信裝置',
        '復原金鑰',
        '背景逾時',
      ],
      sections: <AboutSectionCopy>[
        AboutSectionCopy(
          title: '三種解鎖模式',
          subtitle: '解鎖模式決定回到前景時，系統要用哪種方式重新驗證。',
          items: <AboutItemCopy>[
            AboutItemCopy(
              icon: Icons.no_encryption_gmailerrorred_outlined,
              title: '無驗證',
              body: '回前景時不額外驗證，逾時後走 `autoTrusted` 直接恢復可信 session。適合尚未設定螢幕鎖的裝置，但安全性較低。',
            ),
            AboutItemCopy(
              icon: Icons.lock_outline,
              title: '裝置螢幕鎖',
              body: '使用 `deviceLock` 路徑，回前景時跳出系統螢幕鎖驗證，對應 `deviceCredential` Keystore 槽。',
            ),
            AboutItemCopy(
              icon: Icons.fingerprint_rounded,
              title: '生物驗證',
              body: '使用 `biometric` 路徑，回前景時走系統指紋或臉部驗證，對應 `biometric` Keystore 槽。',
            ),
            AboutItemCopy(
              icon: Icons.info_outline_rounded,
              title: '共同前提',
              body: '螢幕鎖與生物驗證模式都要求裝置本身已設定螢幕鎖；生物驗證模式 ideally 還要求至少有一種生物辨識已登錄。',
            ),
          ],
        ),
        AboutSectionCopy(
          title: 'Session 如何運作',
          subtitle: '只要 session 有效，App 才能讀寫正式日記、草稿與搜尋索引。',
          items: <AboutItemCopy>[
            AboutItemCopy(
              icon: Icons.lock_open_rounded,
              title: '有效 session',
              body: '有效 session 存在時，日記庫、草稿與索引都能正常使用。',
            ),
            AboutItemCopy(
              icon: Icons.lock_clock_outlined,
              title: '背景逾時',
              body: '預設 5 分鐘後 session 失效。App 回到前景時，必須重新完成系統驗證才能恢復可信 session。',
            ),
            AboutItemCopy(
              icon: Icons.sync_rounded,
              title: 'Resume 行為',
              body: '逾時後依模式分支：`none` 走 `autoTrusted` 直接恢復；`deviceLock` / `biometric` 則走 `keystoreUnlock`，要求 UI 重新觸發 `unlock()` 並跳出系統驗證對話框。',
            ),
          ],
        ),
        AboutSectionCopy(
          title: '什麼時候會退回復原金鑰',
          subtitle: '可信裝置只是便利路徑，不是最終的資料所有權依據。',
          items: <AboutItemCopy>[
            AboutItemCopy(
              icon: Icons.warning_amber_rounded,
              title: '可信狀態失效',
              body: '當裝置上的可信狀態失效，或 Keystore 狀態與目前模式不一致時，就不能只靠可信裝置繼續進入。',
            ),
            AboutItemCopy(
              icon: Icons.key_outlined,
              title: '還原後不匹配',
              body: '若還原後偵測到目前可信狀態與日記庫不再匹配，流程會退回 `recoveryRequired`，要求輸入復原金鑰。',
            ),
            AboutItemCopy(
              icon: Icons.key_outlined,
              title: '復原金鑰的地位',
              body: '復原金鑰不是可選附加功能，而是換機、還原與可信裝置失效時的最後依據。',
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
              body: '首頁搜尋不直接逐篇掃描加密日記，而是對索引查詢標題、標籤與內文。',
            ),
            AboutItemCopy(
              icon: Icons.storage_rounded,
              title: '與正式資料分開',
              body: '正式日記仍以 `vault/` 為權威來源；索引只保留搜尋與顯示所需的衍生資料。',
            ),
            AboutItemCopy(
              icon: Icons.lock_outline_rounded,
              title: '索引本身也加密',
              body: '索引路徑雖然和日記庫分開，但 SQLCipher 金鑰會由 `recoveryWrapKey + vaultId` 經 HKDF 衍生，不以明文 SQLite 留在裝置上。',
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
              body: '解鎖成功後，`openForSession` 會綁定目前 `vaultId` 開啟索引。若格式不符，直接刪掉再重建。',
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
              body: '目前搜尋命中 `title_search_text`、`body_search_text` 與 `entry_tags.tag_normalized`；`preview_text` 只用於摘要顯示。',
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
              body: '首頁列表與檢視模式會顯示「未儲存」標記，提醒你這篇日記仍有本地草稿存在。',
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
              body: '還原後既有搜尋索引會刪除，接著從新的正式日記庫重新建立。App 會回到重新啟動與重新解鎖狀態。',
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
              body: '設定頁可匯出 `markdown_*.zip`；首頁選取日記後可匯出 `html_*.html`，兩者都屬於可讀內容輸出。',
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
