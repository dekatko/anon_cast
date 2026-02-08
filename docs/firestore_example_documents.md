# AnonCast Firestore – Example Documents

Example document structures for each collection. Use these for local emulator data or reference.

---

## 1. `organizations`

Stores schools/institutions. Admins and access codes are scoped by `organizationId`.

```json
{
  "name": "Riverside High School",
  "createdAt": "<Timestamp>",
  "updatedAt": "<Timestamp>",
  "settings": {
    "allowAnonymous": true,
    "defaultCodeExpiryDays": 7
  }
}
```

| Field       | Type     | Required | Description                |
|------------|----------|----------|----------------------------|
| name       | string   | yes      | Display name               |
| createdAt  | timestamp| yes      | Creation time              |
| updatedAt  | timestamp| no       | Last update                |
| settings   | map      | no       | Org-specific config        |

**Document ID:** e.g. `org_riverside_001` (your chosen ID).

---

## 2. `users` (admin accounts)

One document per admin/counselor (Firebase Auth UID as document ID). Links to an organization.

```json
{
  "email": "counselor@school.edu",
  "organizationId": "org_riverside_001",
  "displayName": "Jane Smith",
  "role": "counselor",
  "createdAt": "<Timestamp>",
  "updatedAt": "<Timestamp>"
}
```

| Field          | Type     | Required | Description                    |
|----------------|----------|----------|--------------------------------|
| email          | string   | yes      | Login email                    |
| organizationId | string   | yes      | Reference to organization      |
| displayName    | string   | no       | Display name                   |
| role           | string   | no       | e.g. admin, counselor          |
| createdAt      | timestamp| yes      | Account creation               |
| updatedAt      | timestamp| no       | Last profile update            |

**Document ID:** Firebase Auth `uid` of the admin.

---

## 3. `access_codes`

Codes for anonymous access. Optional `organizationId` for org-scoped rules.

```json
{
  "code": "ABC123",
  "status": "active",
  "createdAt": "<Timestamp>",
  "expiresAt": "<Timestamp>",
  "singleUse": true,
  "createdByAdminId": "<admin_uid>",
  "organizationId": "org_riverside_001",
  "usedAt": null,
  "usedByUserId": null,
  "revokedAt": null
}
```

| Field            | Type     | Required | Description                    |
|------------------|----------|----------|--------------------------------|
| code             | string   | yes      | 6-char code (e.g. ABC123)      |
| status           | string   | yes      | active, used, expired, revoked |
| createdAt        | timestamp| yes      | When code was created          |
| expiresAt        | timestamp| yes      | Expiry time                    |
| singleUse        | boolean  | yes      | If true, invalid after one use |
| createdByAdminId | string   | no       | Admin UID who created it       |
| organizationId   | string   | no       | For org-scoped rules           |
| usedAt           | timestamp| no       | Set when code is used          |
| usedByUserId     | string   | no       | Anonymous UID that used it     |
| revokedAt        | timestamp| no       | When code was revoked          |

**Document ID:** Auto-generated (e.g. Firestore `doc().id`).

---

## 4. `conversations`

One document per thread between one anonymous user and one admin.

```json
{
  "organizationId": "org_riverside_001",
  "adminId": "<admin_uid>",
  "anonymousUserId": "<anonymous_firebase_uid>",
  "createdAt": "<Timestamp>",
  "updatedAt": "<Timestamp>",
  "lastMessageAt": "<Timestamp>",
  "typingAdmin": false,
  "typingAnonymous": false
}
```

| Field           | Type     | Required | Description                 |
|-----------------|----------|----------|-----------------------------|
| organizationId  | string   | yes      | Owning organization         |
| adminId         | string   | yes      | Admin/counselor UID         |
| anonymousUserId| string   | yes      | Anonymous Firebase UID      |
| createdAt       | timestamp| yes      | Thread start                |
| updatedAt       | timestamp| no       | Last metadata update        |
| lastMessageAt   | timestamp| no       | For sorting by activity     |
| typingAdmin     | boolean  | no       | Admin typing indicator      |
| typingAnonymous | boolean | no       | Anonymous typing indicator  |

**Document ID:** Auto-generated or UUID.

---

## 5. `messages`

One document per message. Ordered by `timestamp` within a conversation (query by `conversationId`).

```json
{
  "conversationId": "<conversation_doc_id>",
  "senderId": "<firebase_uid>",
  "encryptedContent": "<base64_or_encrypted_payload>",
  "timestamp": "<Timestamp>",
  "status": "unread",
  "iv": [0, 1, 2],
  "preview": "First 50 chars...",
  "senderType": "anonymous"
}
```

| Field           | Type     | Required | Description                    |
|-----------------|----------|----------|--------------------------------|
| conversationId  | string   | yes      | Parent conversation doc ID      |
| senderId        | string   | yes      | Firebase UID of sender         |
| encryptedContent| string   | yes      | Encrypted or plain content     |
| timestamp       | timestamp| yes      | Send time (validated in rules)  |
| status          | string   | yes      | unread, read, resolved         |
| iv              | array    | no       | Initialization vector (bytes)  |
| preview         | string   | no       | Short preview for list UI      |
| senderType      | string   | no       | "admin" or "anonymous"         |

**Document ID:** Auto-generated (e.g. Firestore `doc().id`).

---

## Indexes

Deploy with:

```bash
firebase deploy --only firestore:indexes
```

Required composite indexes are defined in `firestore.indexes.json` for:

- `access_codes`: by `createdAt` desc; by `code` + `status`; by `organizationId` + `createdAt`; by `createdByAdminId` + `createdAt`
- `messages`: by `conversationId` + `timestamp` (asc/desc); by `timestamp` desc
- `conversations`: by `organizationId` + `lastMessageAt`; by `adminId` + `lastMessageAt`; by `anonymousUserId` + `createdAt`
- `users`: by `organizationId` + `email`

---

## Security rules

Deploy with:

```bash
firebase deploy --only firestore:rules
```

Summary:

- **Organizations:** Read only for admins in that org; no client write.
- **Users:** Admins read own doc and same-org users; create/update own doc only.
- **Access codes:** Admins read/write codes for their org or created by them; anonymous code verification should use a Cloud Function in production.
- **Conversations:** Read/write only for participants (`adminId` or `anonymousUserId` == `request.auth.uid`).
- **Messages:** Read only for conversation participants; create only as sender with valid `timestamp` and only for conversations where the user is a participant.
