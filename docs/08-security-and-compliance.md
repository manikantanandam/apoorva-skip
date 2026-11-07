# 08 — Security & Compliance

## 1. Authentication & authorization
- Firebase Auth providers: **Google**, **Phone OTP**, **Email/password** (with registration, email verification and password reset). **Apple** is ready for iOS (App Store guideline 4.8 requires it when Google sign-in is offered). The SDK handles session token refresh.
- Each provider is switched on or off by app-level `auth.*` flags (see 05). Orgs cannot change them. At least one must stay on. Signed-in users stay signed in when a method is turned off and are asked to link another method.
- Account linking: one user per verified email. Signing in with Google for an email that is already registered prompts to link it (password once), never a duplicate account.
- Password policy: 8+ characters with a number, rate-limited attempts, reset via emailed link only.
- Staff added with a PIN sign in with phone + PIN on shared shop devices. The PIN is scoped to the org and stored hashed.
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
- Input validation on phone, GSTIN format (only when entered), amounts (no negatives unless return).
- Dependency scanning: Dependabot + SonarCloud.
- Secret scanning: gitleaks in lint workflow.

## 5. Privacy & compliance (India-focused, adapt as needed)
- **DPDP Act (India):** consent for customer data stored by the shop; provide deletion path; data processor terms with Google.
- **Tax (only if the shop turns it on):** GSTIN on receipts, invoice sequence per financial year, keep records 6–8 years (export, never delete). Shops with tax off have no GST obligations in the app.
- **Privacy policy & data deletion URL** required by Play and App Store.
- **App Store:** App Privacy labels filled for analytics and crash data.

## 6. Account & data deletion
- Shop owner can request full deletion → soft delete, then purge after 30 days, except tax records of tax-enabled shops (kept anonymised).

## 7. Security review checklist (per release)
- [ ] Rules tests pass
- [ ] No secrets in diff (gitleaks)
- [ ] New PII fields listed in privacy doc
- [ ] Permissions are requested only when first needed: camera (barcode, bill photos), Bluetooth (printer), contacts (import), notifications (dues, low stock, summary), photos (item/bill images), biometrics (PIN switch)
- [ ] Privacy labels cover Google / Apple sign-in data (name, email, photo) and UPI ID
- [ ] UPI ID is verified with a ₹1 test before it appears on QR codes and receipts
- [ ] Remote sign-out revokes tokens; support sessions are read-only, time-boxed and audited
- [ ] Developer settings are absent in release unless the `developer` claim is present; Debug never writes to Production; per-environment DB files
- [ ] Free-plan bill count is verified server-side (Cloud Function counter); offline grace is a local counter reconciled on sync, so limits cannot be bypassed by staying offline
