# L10n Delta (EN vs DE) and Gaps Report

## 1. Delta: English vs German

### Summary

**There is no delta between English and German.** Both locales define the **same set of 147 keys** in `lib/l10n/app_localizations.dart`. Every key present in `'en'` has a corresponding entry in `'de'`.

- **English (`en`)**: 147 keys (from `adminDashboardTitle` through `auth_error_unknown`).
- **German (`de`)**: 147 keys, same keys, same order.
- **Missing in German**: **0**
- **Extra in German**: **0**

So for any current getter on `AppLocalizations`, German users get a translated string; nothing falls back to English due to a missing key.

### Optional quality check

You may still want a translator to review German strings for tone, consistency (e.g. “Berater:in” vs “Counselor”), and placeholder usage (`%s`, `{days}`) to ensure they fit the UI.

---

## 2. Text not in the l10n system

The following **user-facing** strings are still hardcoded and do **not** go through `AppLocalizations`. They should be moved into `app_localizations.dart` and wired to `l10n` for full EN/DE support.

### By file

#### `lib/screens/admin_dashboard_screen.dart`

| Location | Hardcoded string | Suggestion |
|----------|------------------|------------|
| ~255 | `'Security check failed'` | Use `l10n.securityCheckFailed` (key already exists). |
| ~195–196 | SnackBar when share not available | Uses `l10n.codeCopied` and `l10n.shareLabel`; only “manually” is hardcoded — consider adding e.g. `shareManually` if you want it localized. |

#### `lib/screens/admin_dashboard_screen.dart` (root: Administrator Dashboard with bottom nav)

| Location | Hardcoded string | Suggestion |
|----------|------------------|------------|
| ~38 | `'Administrator Dashboard'` | Add e.g. `administratorDashboardTitle`. |
| ~64 | `'Messages'` (bottom nav) | Use `l10n.conversationsLabel` or add `navMessages`. |
| ~68 | `'Users'` | Add e.g. `navUsers`. |
| ~72 | `'Rotation'` | Add e.g. `navRotation`. |
| ~76 | `'Settings'` | Use `l10n.settingsLabel`. |

#### `lib/screens/admin_rotation_status_screen.dart`

| Location | Hardcoded string | Suggestion |
|----------|------------------|------------|
| ~200 | `'Key Rotation'` | Add e.g. `keyRotationTitle`. |
| ~285 | `'No conversations yet.'` | Add e.g. `noConversationsYet`. |
| ~367 | `'Check & rotate E2E keys now'` | Add e.g. `checkAndRotateE2ENow`. |
| ~406, ~446 | `'Rotate'` | Add e.g. `rotateButton`. |

#### `lib/screens/admin_system_settings_screen.dart`

| Location | Hardcoded string | Suggestion |
|----------|------------------|------------|
| ~31 | `'Export keys: enter password in dialog (coming soon)'` | Add key or use existing export + “coming soon” key. |
| ~39 | `'Import keys: upload file and enter password (coming soon)'` | Same as above for import. |
| ~66 | `'Audit failed: $e'` | Use `l10n.securityCheckFailed` + error, or add `auditFailed`. |
| ~76 | `'System Settings'` | Add e.g. `systemSettingsTitle`. |
| ~90 | `'Wi-Fi Direct'` | Add if user-facing. |
| ~98 | `'External Server'` | Add if user-facing. |
| ~106 | `'Local Server'` | Add if user-facing. |
| ~121 | `'Run security audit'` | Use `l10n.runSecurityAudit` or keep consistent with settings. |
| ~149 | `'Run audit'` (tooltip) | Add e.g. `runAuditTooltip`. |
| ~166 | `'View last report'` | Add e.g. `viewLastReport`. |
| ~178 | `'Export conversation keys'` | Use `l10n.exportEncryptionKeys` or align with settings. |
| ~179 | `'Save encrypted keys to a file for use on another device'` | Use `l10n.exportEncryptionKeysSubtitle`. |
| ~184 | `'Import conversation keys'` | Use `l10n.importEncryptionKeys`. |
| ~185 | `'Restore keys from a file (e.g. after switching device)'` | Use `l10n.importEncryptionKeysSubtitle` or add similar. |

#### `lib/screens/admin/admin_security_audit_screen.dart`

| Location | Hardcoded string | Suggestion |
|----------|------------------|------------|
| ~22 | `'Security Audit'` | Add e.g. `securityAuditTitle`. |
| ~27 | `'Run again'` | Add e.g. `runAgain`. |

#### `lib/widgets/offline_banner.dart`

| Location | Hardcoded string | Suggestion |
|----------|------------------|------------|
| ~76 | `'Retry'` | Use `l10n.retry` (need to pass `BuildContext` or `AppLocalizations` into the widget). |

#### `lib/screens/chat_screen.dart`

| Location | Hardcoded string | Suggestion |
|----------|------------------|------------|
| ~56 | `'Chat Room'` | Add e.g. `chatRoomTitle`. |
| ~90 | `'Enter message'` | Use `l10n.typeMessageHint` or add. |
| ~102 | `'Error loading session'` | Add e.g. `errorLoadingSession`. |

#### `lib/screens/admin/admin_dashboard.dart`

| Location | Hardcoded string | Suggestion |
|----------|------------------|------------|
| ~214 | `'Today'` | Add e.g. `filterToday`. |
| ~218 | `'Yesterday'` | Add e.g. `filterYesterday`. |
| ~222 | `'This week'` | Add e.g. `filterThisWeek`. |
| ~226 | `'Clear'` | Add e.g. `filterClear`. |

#### `lib/screens/admin/admin_message_detail_screen.dart`

| Location | Hardcoded string | Suggestion |
|----------|------------------|------------|
| ~129 | `'No conversation ID'` | Add e.g. `noConversationId`. |

#### `lib/screens/admin/user_management_screen.dart`

| Location | Hardcoded string | Suggestion |
|----------|------------------|------------|
| ~367 | `DataColumn(label: Text(''))` | Empty header; can stay as-is or use a space/accessible label if needed. |

#### `lib/screens/auth/admin_register_screen.dart`

| Location | Hardcoded string | Suggestion |
|----------|------------------|------------|
| ~63 | `labelText: 'Name'` | Add e.g. `nameLabel`. |

#### `lib/screens/auth/login_screen.dart`

| Location | Hardcoded string | Suggestion |
|----------|------------------|------------|
| ~408 | `hintText: 'XXXXXX'` | Placeholder for code; add e.g. `accessCodeHint` (“e.g. XXXXXX”) if you want it localized. |

#### `lib/screens/auth/anonymous_home_screen.dart`

| Location | Hardcoded string | Suggestion |
|----------|------------------|------------|
| ~81 | `hintText: 'XXXXXX'` | Same as login — optional `accessCodeHint`. |

#### `lib/screens/admin_selection_screen.dart`

| Location | Hardcoded string | Suggestion |
|----------|------------------|------------|
| ~19 | `'Admin Selection'` | Add e.g. `adminSelectionTitle`. |

#### `lib/screens/admin_chat_dashboard_screen.dart`

| Location | Hardcoded string | Suggestion |
|----------|------------------|------------|
| ~21 | `'Active Chats'` | Add e.g. `activeChatsTitle`. |
| ~31 | `'No Active Chats'` | Add e.g. `noActiveChats`. |
| ~42 | `'Chat with ${chatSession.studentId}'` | Add pattern e.g. `chatWithStudent` with placeholder. |
| ~43 | `'$truncatedMessage...'` | Dynamic; only “...” might need a key if shown as literal. |

### Not included (internal / logging)

- **`lib/services/security_validator.dart`**: `'Skipped (no conversations to sample)'`, `'Skipped (no messages to sample)'` — audit result messages; could be localized if shown in UI.
- **`lib/services/key_rotation_service.dart`**: `'Key rotation started'`, `'No session found'`, etc. — progress/log messages; localize if they appear in the UI.

---

## 3. Recommended next steps

1. **Fix the one existing key that’s not used**  
   In `admin_dashboard_screen.dart` (admin folder), replace `const Text('Security check failed')` with `Text(l10n.securityCheckFailed)`.

2. **Add missing keys to `app_localizations.dart`**  
   Add the suggested keys for both `'en'` and `'de'` (see table above), then replace hardcoded strings with `l10n.xxx` (and pass `context`/`l10n` where needed, e.g. `OfflineBanner`).

3. **Reuse existing keys where possible**  
   - Bottom nav “Settings” → `l10n.settingsLabel`.  
   - System settings export/import titles and subtitles → reuse `exportEncryptionKeys`, `importEncryptionKeys`, and their subtitles from settings.

4. **Optional**  
   - Add `shareManually` (or similar) if you want the share fallback message fully localized.  
   - Add `accessCodeHint` for the “XXXXXX” placeholders.  
   - Localize security audit “Skipped…” and key-rotation progress messages if they are visible to users.

---

*Generated from codebase scan. Key count and file locations are approximate (line numbers may shift with edits).*
