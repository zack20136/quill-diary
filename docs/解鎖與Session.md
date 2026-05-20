# 解鎖與 Session

啟動、背景逾時、trusted device 還原，以及三種解鎖模式與 `ResumeUnlockAction` 行為。

## 三種解鎖模式

| 模式 | storage | 逾時回前景 | Keystore 主槽 | 備援 |
|------|---------|------------|---------------|------|
| **無**（預設） | `none` | 自動 plain unwrap | `plain` | 無 |
| **裝置螢幕鎖** | `deviceLock` | 系統螢幕鎖對話框 | `deviceCredential` | 無 |
| **生物驗證** | `biometric` | 系統指紋／臉部 | `biometric` | 指紋取消或失敗 → **裝置螢幕鎖**（credential 槽） |

`deviceLock` 與 `biometric` 皆須裝置已設定螢幕鎖（`canUseDeviceCredential()`）。生物模式另須至少一種生物辨識已登錄。

## Keystore 三槽

Android `DeviceKeyManager` 對應三種 alias：

| `KeystoreAuthKind` | 用途 |
|--------------------|------|
| `plain` | 無額外驗證；`none` 模式 trusted unwrap |
| `deviceCredential` | 系統螢幕鎖；`deviceLock` 模式與生物模式**備援** |
| `biometric` | 系統生物辨識；`biometric` 模式主路徑 |

生物模式會在啟用後維護 **credential 備份 wrap**（`wrapped_recovery_key_credential_backup`），供指紋失敗時以螢幕鎖 unwrap，無需 App 內 PIN。

## 架構邊界

| 元件 | 職責 |
|------|------|
| **`AppSessionController`** | session 狀態、`resumeAction`、呼叫 `VaultRepository.openTrustedSession` |
| **`SessionUnlockCoordinator`** | 監聽 `resumeAction`，自動 `unlock()` 或觸發裝置螢幕鎖備援 |
| **`AppLockService`** | 僅持久化解鎖模式、查詢 `canUseDeviceCredential()` |
| **`DeviceKeyManager`** | Keystore wrap/unwrap、credential 備份紀錄 |
| **`VaultRepository`** | trusted session、`syncDeviceCredentialBackupWrapIfNeeded`、`ensureKeystoreMatchesUnlockMode` |

## `ResumeUnlockAction`

背景逾時或啟動解鎖失敗後，UI 與 coordinator 依此欄位決定下一步：

| 值 | 觸發條件 | 行為 |
|----|----------|------|
| `autoTrusted` | `none` 模式 | 立即 `unlock()`（plain） |
| `keystoreUnlock` | `deviceLock` / `biometric` 主路徑 | `unlock()` → 系統驗證對話框 |
| `deviceCredentialFallback` | 生物模式且使用者取消／失敗，且可螢幕鎖 | `unlock(deviceCredentialFallback: true)` |

## Session 逾時

- 門檻預設 5 分鐘（`SessionTimeoutPolicy`）。
- **`none`**：`resumeAction = autoTrusted`。
- **`deviceLock` / `biometric`**：`resumeAction = keystoreUnlock`。
- **生物驗證取消且已設螢幕鎖**：`resumeAction = deviceCredentialFallback`，訊息為「可改用裝置螢幕鎖解鎖」。

## 切換解鎖模式（設定）

1. 須已建立復原金鑰。
2. 選 `deviceLock` 或 `biometric` 前檢查 `canUseDeviceCredential()`。
3. 切到 `biometric` 後執行 `syncDeviceCredentialBackupWrapIfNeeded`，確保 credential 備份存在。

## 與復原金鑰的關係

- 解鎖模式只影響 **trusted device** 的 Keystore 體驗，不取代復原金鑰。
- trusted 失效、還原後 vault 不符、或 legacy slot → `recoveryRequired`，須輸入復原金鑰。
