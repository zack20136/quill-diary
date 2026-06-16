import 'package:flutter/material.dart';

import '../../domain/shared/vault_backup_policy.dart';
import '../../l10n/l10n.dart';
import 'settings_copy.dart';
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
  static String pageTitle(BuildContext context) =>
      context.l10n.localeName.startsWith('en') ? 'About' : '介紹';

  static List<AboutTabCopy> tabs(Duration sessionTimeout) => <AboutTabCopy>[
    AboutTabCopy(
      label: '簡介',
      heroIcon: Icons.menu_book_rounded,
      heroTitle: '把私人日記留在自己手上',
      heroBody:
          'Quill Diary 是為個人記錄設計的本機加密日記 App。你可以安心寫、快速找、隨時回顧，也能在需要時建立完整備份或匯出可閱讀內容；除非你主動操作，資料預設留在裝置上。',
      chips: <String>[
        '資料留在裝置',
        '可匯出 Markdown',
        '全文搜尋',
        '完整加密備份',
        '可攜式匯出',
      ],
      sections: <AboutSectionCopy>[
        AboutSectionCopy(
          title: '為什麼適合拿來寫日記',
          subtitle: '它不是把雲端筆記換個名字，而是把私人資料保護和日常使用一起考慮。',
          items: <AboutItemCopy>[
            AboutItemCopy(
              icon: Icons.lock_outline_rounded,
              title: '本機加密保存',
              body: '正式日記、附件、草稿與搜尋索引都以加密或受 session 保護的方式留在裝置上。除非你主動備份或匯出，內容不會自動離開手機。',
            ),
            AboutItemCopy(
              icon: Icons.cloud_off_rounded,
              title: '不用註冊就能開始',
              body: '日常寫作不依賴帳號系統或遠端伺服器。你不需要先建立帳號，才能使用本機日記、搜尋與回顧功能。',
            ),
            AboutItemCopy(
              icon: Icons.shield_outlined,
              title: '少收集、少干擾',
              body: 'App 不內嵌廣告或追蹤 SDK，也不會把日記明文上傳到開發者控制的伺服器。你可以把它當成以隱私為前提的私人寫作空間。',
            ),
          ],
        ),
        AboutSectionCopy(
          title: '你可以怎麼使用它',
          subtitle: '從當下記錄，到之後回顧整理，常用功能都圍繞個人日記情境設計。',
          items: <AboutItemCopy>[
            AboutItemCopy(
              icon: Icons.edit_note_rounded,
              title: '寫下每天想記住的內容',
              body: '支援標題、日期、標籤、圖片與一般附件。新建日記可直接開始寫，既有日記也能先看再編輯；需要時也能把內容匯出成 Markdown 或 HTML。',
            ),
            AboutItemCopy(
              icon: Icons.calendar_month_outlined,
              title: '用不同角度看自己的紀錄',
              body: '主畫面提供列表、日曆、標籤與總覽四種入口。你可以依時間瀏覽、按日期回看，或從標籤和統計整理自己的生活軌跡。',
            ),
            AboutItemCopy(
              icon: Icons.search_rounded,
              title: '找回以前寫過的內容',
              body: '解鎖後可搜尋標題、標籤與內文，適合回頭找某段經歷、某個關鍵字，或快速整理某段時間的紀錄。',
            ),
            AboutItemCopy(
              icon: Icons.file_upload_outlined,
              title: '把回顧整理成可分享的形式',
              body: '你可以建立完整備份保存整個加密日記庫，也能匯出 Markdown 或 HTML，方便自己閱讀、整理或搬移內容。',
            ),
          ],
        ),
        AboutSectionCopy(
          title: '資料掌控權在你手上',
          subtitle: '備份、匯出與解鎖方式各自扮演不同角色，目的是讓你能保留資料，也能理解風險邊界。',
          items: <AboutItemCopy>[
            AboutItemCopy(
              icon: Icons.key_outlined,
              title: '可信裝置與復原金鑰',
              body: '日常可用螢幕鎖或生物辨識快速回到 App；換機、還原或可信狀態失效時，復原金鑰才是重新取得存取權的關鍵。',
            ),
            AboutItemCopy(
              icon: Icons.archive_outlined,
              title: '完整備份保存的是加密日記庫',
              body: '完整備份保留的是整個加密 vault，適合之後完整還原，不是直接打開就能閱讀的文件。',
            ),
            AboutItemCopy(
              icon: Icons.lock_open_rounded,
              title: '匯出內容後要自行保護',
              body: 'Markdown 與 HTML 匯出適合閱讀、整理與轉移內容，但它們屬於可讀文件，不再等同於 App 內的加密保存狀態。',
            ),
          ],
        ),
        AboutSectionCopy(
          title: '開源與品牌',
          subtitle: '你可以查看原始碼與授權條件，也能清楚知道品牌使用界線。',
          items: <AboutItemCopy>[
            AboutItemCopy(
              icon: Icons.code_rounded,
              title: 'AGPL-3.0 開源',
              body: '原始碼以 GNU Affero General Public License v3.0 發布，讓產品行為與實作方式能被公開檢視，增加透明度與可驗證性。',
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
      heroTitle: '在方便解鎖和保護資料之間取得平衡',
      heroBody:
          'Quill Diary 不會要求你每次切出再回來都重新做最重的驗證，但也不會讓已解鎖狀態無限延長。這一頁說明不同解鎖方式、自動鎖定，以及什麼情況下會需要復原金鑰。',
      chips: <String>[
        '生物辨識',
        '螢幕鎖',
        '自動鎖定',
        '復原金鑰',
      ],
      sections: <AboutSectionCopy>[
        AboutSectionCopy(
          title: '解鎖方式怎麼選',
          subtitle: '你可以依裝置習慣與想要的保護程度，在設定頁切換不同模式。',
          items: <AboutItemCopy>[
            AboutItemCopy(
              icon: Icons.no_encryption_gmailerrorred_outlined,
              title: '無',
              body: '鎖定後不額外驗證，回到 App 會直接恢復。適合尚未設定裝置螢幕鎖的情況，但保護力最低。',
            ),
            AboutItemCopy(
              icon: Icons.lock_outline,
              title: '裝置螢幕鎖',
              body: '回到 App 時用 PIN、圖案或密碼重新驗證。適合想保留系統層保護，又不一定使用生物辨識的人。',
            ),
            AboutItemCopy(
              icon: Icons.fingerprint_rounded,
              title: '生物驗證',
              body: '優先使用指紋或臉部驗證，失敗或取消時可改走螢幕鎖。這通常是日常使用最方便的方式。',
            ),
            AboutItemCopy(
              icon: Icons.info_outline_rounded,
              title: '共同前提',
              body: '螢幕鎖與生物驗證模式都要求裝置先設定好螢幕鎖；要使用生物辨識，也必須先在系統中完成登錄。',
            ),
          ],
        ),
        AboutSectionCopy(
          title: '什麼時候會重新驗證',
          subtitle: '只有在有效解鎖期間內，正式日記、草稿與搜尋索引才會保持可用。',
          items: <AboutItemCopy>[
            AboutItemCopy(
              icon: Icons.lock_open_rounded,
              title: '解鎖中',
              body: '解鎖後，你可以正常讀寫日記、編輯草稿、附加檔案，並使用全文搜尋。',
            ),
            AboutItemCopy(
              icon: Icons.lock_clock_outlined,
              title: '背景逾時',
              body: SettingsSessionTimeoutCopy.aboutBackgroundTimeoutBody(sessionTimeout),
            ),
            AboutItemCopy(
              icon: Icons.sync_rounded,
              title: '回到 App 時',
              body: '如果只是短暫切出去再回來，通常不會立刻要求重驗。若放在背景超過時間後才回來，就會依你選擇的模式決定是否直接恢復或跳出系統驗證。',
            ),
            AboutItemCopy(
              icon: Icons.error_outline_rounded,
              title: '驗證取消或失敗後',
              body: '如果這次驗證取消或沒有通過，App 會維持鎖定，不會一直反覆跳窗。你可以在方便時再手動重試。',
            ),
          ],
        ),
        AboutSectionCopy(
          title: '為什麼還需要復原金鑰',
          subtitle: '可信裝置提供的是便利路徑，真正能跨裝置、跨狀態重新進入日記庫的依據仍然是復原金鑰。',
          items: <AboutItemCopy>[
            AboutItemCopy(
              icon: Icons.phone_android_rounded,
              title: '換機或重設後',
              body: '當你換手機、清除 App 資料，或要在另一台裝置上恢復日記庫時，可信裝置狀態通常不會跟著過去，這時就需要復原金鑰。',
            ),
            AboutItemCopy(
              icon: Icons.warning_amber_rounded,
              title: '可信狀態失效',
              body: '如果裝置上的可信狀態失效，或與目前的日記庫狀態不再對應，就不能只靠本機快速進入。',
            ),
            AboutItemCopy(
              icon: Icons.key_outlined,
              title: '最終存取權',
              body: '復原金鑰不是可有可無的備用功能，而是換機、還原與可信裝置失效時的必要憑證，請務必妥善保存。',
            ),
          ],
        ),
      ],
    ),
    AboutTabCopy(
      label: '加密與解密',
      heroIcon: Icons.enhanced_encryption_outlined,
      heroTitle: '資料預設以加密形式保存',
      heroBody:
          'Quill Diary 會先保護內容，再把它寫進日記庫。正式日記、附件與其他敏感資料會使用 LDJ2 格式封裝，內容以 AES-256-GCM 加密，並透過可信裝置或復原金鑰的正確路徑才能打開。',
      chips: <String>[
        '本機加密',
        'LDJ2',
        'AES-256-GCM',
        'Argon2id',
        '可信裝置',
        'Android Keystore',
      ],
      sections: <AboutSectionCopy>[
        AboutSectionCopy(
          title: '這套保護機制在幫你做什麼',
          subtitle: '重點不是堆術語，而是讓你知道正式資料在存放與讀取時，都有清楚而一致的保護流程。',
          items: <AboutItemCopy>[
            AboutItemCopy(
              icon: Icons.lock_rounded,
              title: 'LDJ2 + AES-256-GCM 保護內容',
              body: '正式日記與附件會先用 LDJ2 格式封裝，再以 AES-256-GCM 加密正文。即使看到檔案本身，也不是直接就能讀懂的內容。',
            ),
            AboutItemCopy(
              icon: Icons.verified_user_outlined,
              title: '被竄改時應該直接失敗',
              body: '正式資料不只加密，也帶有完整性驗證。若內容或檔案 header 被動過手腳，解密應該直接失敗，而不是悄悄回傳可疑內容。',
            ),
            AboutItemCopy(
              icon: Icons.layers_outlined,
              title: '每個檔案都有獨立金鑰',
              body: '每個加密檔案都會先產生自己的隨機 file key，再由 vault 層的保護機制包裝。這讓不同內容不會共用同一把檔案金鑰。',
            ),
          ],
        ),
        AboutSectionCopy(
          title: '你可以怎麼打開自己的資料',
          subtitle: '日常與緊急情況走的是不同入口，但最後都會回到同一套解密流程。',
          items: <AboutItemCopy>[
            AboutItemCopy(
              icon: Icons.phonelink_lock_outlined,
              title: '可信裝置',
              body: '在同一台已建立可信狀態的裝置上，日常通常可透過螢幕鎖或生物辨識重新進入。這條路徑會由 Android Keystore 保護 vault 層的重要金鑰。',
            ),
            AboutItemCopy(
              icon: Icons.key_outlined,
              title: '復原金鑰',
              body: '當你換機、還原備份或本機可信狀態失效時，可以用復原金鑰重新取得進入整個日記庫的能力。復原金鑰會先經過 Argon2id 推導，再進入後續解密流程。',
            ),
            AboutItemCopy(
              icon: Icons.fact_check_outlined,
              title: '先確認 vault，再解開各檔',
              body: '流程會先確認目前的存取狀態能否正確進入 vault，之後才解開各個檔案。這能避免用錯憑證時，把問題誤判成資料毀損。',
            ),
          ],
        ),
        AboutSectionCopy(
          title: '使用前要知道的邊界',
          subtitle: '加密能保護日記庫本身，但不代表所有情境都自動安全。',
          items: <AboutItemCopy>[
            AboutItemCopy(
              icon: Icons.file_upload_outlined,
              title: '匯出後不再是同一層保護',
              body: '只要你把內容匯出成 Markdown 或 HTML，可讀文件之後的存放與分享風險，就不再由 App 內的加密機制接手。',
            ),
            AboutItemCopy(
              icon: Icons.password_rounded,
              title: '復原金鑰要自己保管',
              body: '復原金鑰是重新進入日記庫的重要依據。若它外洩、遺失，或你沒有妥善保存，之後可能影響資料安全或可恢復性。',
            ),
            AboutItemCopy(
              icon: Icons.security_outlined,
              title: '它保護的是靜態資料',
              body: '這套設計主要保護的是存放在裝置上的加密資料；若裝置本身遭到入侵、已解鎖狀態被他人取得，風險就不只取決於檔案格式本身。',
            ),
          ],
        ),
      ],
    ),
    AboutTabCopy(
      label: '索引與搜尋',
      heroIcon: Icons.manage_search_rounded,
      heroTitle: '解鎖後，你可以快速找回以前寫過的內容',
      heroBody:
          '搜尋不是每次都把所有日記重新讀一遍，而是透過一份加密索引來加快查找。這份索引只在解鎖期間打開，讓搜尋體驗和資料保護可以兼顧。',
      chips: <String>[
        '標題/內文搜尋',
        '加密索引',
        '解鎖期間可用',
        '可重建',
      ],
      sections: <AboutSectionCopy>[
        AboutSectionCopy(
          title: '搜尋能幫你找什麼',
          subtitle: '適合在回顧、整理或想找某段經歷時，快速縮小範圍。',
          items: <AboutItemCopy>[
            AboutItemCopy(
              icon: Icons.search_rounded,
              title: '搜尋標題、標籤與內文',
              body: '你可以直接查找標題、內文與標籤中的關鍵字，不需要一篇篇翻找過去寫過什麼。',
            ),
            AboutItemCopy(
              icon: Icons.view_list_rounded,
              title: '結果來自正式已儲存內容',
              body: '搜尋看到的是已正式寫入日記庫的內容，而不是暫時停在編輯器中的草稿。',
            ),
            AboutItemCopy(
              icon: Icons.lock_outline_rounded,
              title: '索引本身也受保護',
              body: '搜尋不是建立一份明文資料庫放在旁邊，而是使用另一份加密索引來支撐查找速度。',
            ),
          ],
        ),
        AboutSectionCopy(
          title: '為什麼搜尋不會拖慢日常使用',
          subtitle: '它把查找工作交給索引層，而不是每次都逐篇掃描正式日記。',
          items: <AboutItemCopy>[
            AboutItemCopy(
              icon: Icons.manage_search_outlined,
              title: '以索引換速度',
              body: '當你輸入關鍵字時，系統會查詢索引，而不是臨時解密整個日記庫後逐篇比對。',
            ),
            AboutItemCopy(
              icon: Icons.save_outlined,
              title: '正式儲存後才更新',
              body: '只有正式儲存成功或匯入完成後，索引才會同步更新；這樣搜尋結果才不會混入尚未確定的草稿內容。',
            ),
            AboutItemCopy(
              icon: Icons.auto_delete_outlined,
              title: '必要時可重建',
              body: '索引屬於衍生資料。如果格式更新、還原備份，或目前狀態不適合沿用，系統會刪除並重新生成。',
            ),
          ],
        ),
        AboutSectionCopy(
          title: '它和安全性的關係',
          subtitle: '搜尋好用，不代表要放棄保護邊界。',
          items: <AboutItemCopy>[
            AboutItemCopy(
              icon: Icons.lock_open_rounded,
              title: '只在解鎖期間可用',
              body: '搜尋索引只會在有效解鎖 session 期間打開；App 鎖定後，索引也會跟著關閉。',
            ),
            AboutItemCopy(
              icon: Icons.search_off_outlined,
              title: '草稿不進搜尋',
              body: '編輯中的草稿不會出現在搜尋結果裡，避免把未完成內容誤當成正式紀錄。',
            ),
            AboutItemCopy(
              icon: Icons.storage_rounded,
              title: '正式資料仍以日記庫為準',
              body: '搜尋索引的工作是幫你更快找到內容，不是取代正式日記資料本體；真正的權威來源仍然是加密日記庫。',
            ),
          ],
        ),
      ],
    ),
    AboutTabCopy(
      label: '日記編輯器',
      heroIcon: Icons.edit_note_rounded,
      heroTitle: '寫作、暫存與正式保存各走自己的路',
      heroBody:
          '編輯器不會把「還在寫」和「已正式保存」混在一起。它會先把變更寫成加密草稿，等你確認儲存後，再更新正式日記與搜尋索引，讓寫作過程比較安心，也更容易接續。',
      chips: <String>[
        '可匯出 Markdown',
        '圖片附件',
        '自動草稿',
        '未儲存提醒',
      ],
      sections: <AboutSectionCopy>[
        AboutSectionCopy(
          title: '日常寫作功能',
          subtitle: '以個人記錄為核心，把常用的整理方式都放進同一個編輯流程。',
          items: <AboutItemCopy>[
            AboutItemCopy(
              icon: Icons.edit_outlined,
              title: '新建或修改既有日記',
              body: '新建日記會直接進入編輯模式；既有日記則可先閱讀，確定要改時再切換到編輯狀態。',
            ),
            AboutItemCopy(
              icon: Icons.edit_note_rounded,
              title: '內容、標題、日期與標籤',
              body: '你可以編輯日記內容，同時整理標題、日期、時間與標籤。正式儲存時會檢查必要欄位，避免留下不完整紀錄；需要時也能把內容匯出成 Markdown。',
            ),
            AboutItemCopy(
              icon: Icons.attach_file,
              title: '圖片與一般附件',
              body: '可加入多張圖片或一般檔案，並調整圖片順序。這讓日記不只是一段文字，也能保留當下的素材與脈絡。',
            ),
          ],
        ),
        AboutSectionCopy(
          title: '草稿機制',
          subtitle: '草稿不是額外的小功能，而是整個寫作體驗的重要保護層。',
          items: <AboutItemCopy>[
            AboutItemCopy(
              icon: Icons.save_as_outlined,
              title: '變更會自動保存',
              body: '進入編輯後，只要標題、日期、標籤、內文或附件有變動，就會自動寫成加密草稿，降低中斷時遺失內容的風險。',
            ),
            AboutItemCopy(
              icon: Icons.restore_page_outlined,
              title: '再次開啟時可還原',
              body: '重新打開同一篇日記或未完成的新建內容時，如果本地仍保留草稿，App 會先詢問你要不要接著上次進度寫。',
            ),
            AboutItemCopy(
              icon: Icons.auto_delete_outlined,
              title: '正式儲存後自動清理',
              body: '當內容成功正式寫入日記庫，草稿就會被清掉；如果你取消編輯且沒有留下新變更，也不會一直堆積舊草稿。',
            ),
          ],
        ),
        AboutSectionCopy(
          title: '和其他資料的關係',
          subtitle: '編輯中的內容與正式保存的內容有清楚界線，避免把兩者混為一談。',
          items: <AboutItemCopy>[
            AboutItemCopy(
              icon: Icons.search_off_outlined,
              title: '草稿不進搜尋結果',
              body: '搜尋只看正式寫入日記庫的內容，草稿不會出現在結果中，避免未完成內容被誤認為正式紀錄。',
            ),
            AboutItemCopy(
              icon: Icons.archive_outlined,
              title: '草稿不進完整備份',
              body: '完整備份只封裝正式日記庫，不包含 `drafts/`。這代表備份與還原的重點是正式資料，而不是尚未定稿的編輯狀態。',
            ),
            AboutItemCopy(
              icon: Icons.info_outline_rounded,
              title: '未儲存提示',
              body: '如果某篇日記仍留有本地草稿，列表與檢視模式會顯示「未儲存」標記，提醒你還有內容尚未正式保存。',
            ),
          ],
        ),
      ],
    ),
    AboutTabCopy(
      label: '備份與還原',
      heroIcon: Icons.storage_rounded,
      heroTitle: '保留整個日記庫，或帶出可閱讀內容',
      heroBody:
          '備份與匯出看起來都像「把資料帶出去」，但用途完全不同。完整備份用來保留整個加密日記庫，Markdown / HTML 則是把內容變成可閱讀、可整理、可再匯入的形式。這兩條流程不能混用。',
      chips: <String>[
        '完整加密備份',
        'Google Drive',
        'Markdown',
        'HTML',
      ],
      sections: <AboutSectionCopy>[
        AboutSectionCopy(
          title: '完整備份適合什麼情境',
          subtitle: '如果你想保留整個正式日記庫，之後能原樣恢復，走的就是完整備份。',
          items: <AboutItemCopy>[
            AboutItemCopy(
              icon: Icons.archive_outlined,
              title: '保存整個加密日記庫',
              body: '`backup_*.zip` 封裝的是 `vault/` 內的正式資料，包括日記、附件、復原設定與標籤目錄；內容仍保持加密，不是明文文件。',
            ),
            AboutItemCopy(
              icon: Icons.fact_check_outlined,
              title: '建立後會先檢查',
              body: '完整備份會先經過結構檢查，確認內容可用後，才交付到本機、外部資料夾或 Google Drive。',
            ),
            AboutItemCopy(
              icon: Icons.history_rounded,
              title: '保留份數',
              body: '本機備份與 Google Drive 都保留最新 ${VaultBackupPolicy.retainCount} 份；若你匯出到外部資料夾，則不會自動輪替或刪除舊檔。',
            ),
          ],
        ),
        AboutSectionCopy(
          title: '還原時會發生什麼',
          subtitle: '還原不是補回少掉的幾篇內容，而是把目前正式日記庫換成備份中的那一份。',
          items: <AboutItemCopy>[
            AboutItemCopy(
              icon: Icons.warning_amber_rounded,
              title: '正式日記庫會被覆寫',
              body: '不論備份來源是 App 內清單還是外部 zip，還原流程都會用備份內容覆寫目前的 `vault/`。',
            ),
            AboutItemCopy(
              icon: Icons.manage_search_outlined,
              title: '搜尋索引會重建',
              body: '還原時現有索引會被刪除，之後再依新的正式資料重建。若目前可信狀態無法直接沿用，也可能需要重新驗證。',
            ),
            AboutItemCopy(
              icon: Icons.key_outlined,
              title: '可能會要求復原金鑰',
              body: '如果目前裝置上的可信狀態不能直接對應到那份備份，流程就會要求輸入建立該備份時保存的復原金鑰。',
            ),
          ],
        ),
        AboutSectionCopy(
          title: '匯入與匯出適合什麼用途',
          subtitle: '這條流程處理的是內容交換與閱讀，不是拿來完整覆寫整個日記庫。',
          items: <AboutItemCopy>[
            AboutItemCopy(
              icon: Icons.file_download_outlined,
              title: '匯入',
              body: '可從 zip、Markdown、HTML 或資料夾匯入內容。若是 zip，系統會先判斷是否為支援的備份格式，再決定後續處理方式。',
            ),
            AboutItemCopy(
              icon: Icons.file_upload_outlined,
              title: '匯出',
              body: '你可以在設定頁匯出 `markdown_*.zip`，也能從主畫面選取日記或在總覽匯出 `html_*.html`，把內容整理成可閱讀格式。',
            ),
            AboutItemCopy(
              icon: Icons.swap_horiz_rounded,
              title: '它不是同步服務',
              body: 'Google Drive 在這裡扮演的是可選的加密備份目的地，而不是跨裝置即時同步日記的服務。',
            ),
          ],
        ),
        AboutSectionCopy(
          title: '使用前要知道的事',
          subtitle: '備份與匯出都很重要，但它們保護的對象與責任邊界並不相同。',
          items: <AboutItemCopy>[
            AboutItemCopy(
              icon: Icons.drafts_outlined,
              title: '完整備份不包含草稿',
              body: '完整備份只處理正式日記庫，不包含 `drafts/`。如果你還在編輯中的內容尚未正式儲存，它不會被一起封裝進去。',
            ),
            AboutItemCopy(
              icon: Icons.file_open_outlined,
              title: '可讀匯出要自己保管',
              body: 'Markdown 與 HTML 匯出是為了閱讀、整理與轉移內容，但它們不再是 App 內的加密格式，後續保存方式要由你自己決定。',
            ),
            AboutItemCopy(
              icon: Icons.folder_zip_outlined,
              title: '別把兩條流程混用',
              body: '如果你要的是之後完整恢復整個日記庫，請使用完整備份；如果你要的是把內容帶出去看或整理，才使用 Markdown / HTML 匯出。',
            ),
          ],
        ),
      ],
    ),
  ];
}
