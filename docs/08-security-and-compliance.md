# 08 — Security & Compliance

## 1. Authentication & authorization
- Firebase Auth (email/password or phone OTP). Session token refresh handled by SDK.
- Custom claims: `shopId`, `role` (owner, manager, cashier). Set by a Cloud Function on staff invite.
- Role checks happen in Firestore rules **and** in the app (UI hiding is not security).

## 2. Firestore security rules (outline)
- Read/write only if `request.auth.token.shopId == resource.data.shopId`.
- Cashier cannot delete bills or edit closed cashflow days.
- Writes must include `updatedAt == request.time` and valid `deviceId`.
- Rules tested with the Firebase emulator in CI.

## 3. Data protection
| Layer | Measure |
|-------|---------|
| In transit | TLS (Firestore, Auth) |
| At rest (cloud) | Google-managed encryption |
| At rest (device) | Device file protection; optional SQLCipher for the local DB |
| Secrets | Not in source; CI secrets + Keychain / Android Keystore for tokens |
| Logs | No PII in release logs |

## 4. Application security
- Certificate pinning: not in v1 (Firebase SDK handles TLS); revisit if threat model changes.
- Jailbreak/root detection: advisory only, log event, no hard block in v1.
- Input validation on phone, GSTIN format, amounts (no negatives unless return).
- Dependency scanning: Dependabot + SonarCloud.
- Secret scanning: gitleaks in lint workflow.

## 5. Privacy & compliance (India-focused, adapt as needed)
- **DPDP Act (India):** consent for customer data stored by the shop; provide deletion path; data processor terms with Google.
- **GST:** invoice number sequence per financial year, GSTIN on invoice, retain records 6–8 years (plan to export, not delete).
- **Privacy policy & data deletion URL** required by Play and App Store.
- **App Store:** App Privacy labels filled for analytics and crash data.

## 6. Account & data deletion
- Shop owner can request full deletion → soft delete, then purge after 30 days, except tax records kept per GST rule (anonymised).

## 7. Security review checklist (per release)
- [ ] Rules tests pass
- [ ] No secrets in diff (gitleaks)
- [ ] New PII fields listed in privacy doc
- [ ] Permissions requested are minimal (camera for barcode, Bluetooth for printer only when used)
