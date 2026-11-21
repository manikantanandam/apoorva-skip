# Member invites

**Date:** 2026-11-21
**Context:** How should owners add members to an organization? Small-shop owners don't know code sharing.

## Exploration
- Only the joiner side existed: `StaffJoinView` (enter 8-char code), `OrganizationSetupService.fetchInvite/createInvite/acceptInvite`, `Invite` model, `apoorva://join/<code>` deep link. No owner UI ever called `createInvite`.

## Decision
- Removed the whole code-based invite concept: `Invite` model, the three service methods, `StaffJoin` VM/view/route, "Have an invite code" button, deep-link handling (`onOpenURL`, `pendingInviteCode`, `apoorva` URL scheme in `Info.plist`), admin `.invite` route, and their tests.
- Owner tells the member to install the app for now. Planned next: owner adds a member by email (pending record keyed by email, matched on sign-in with a verified email, protected by Firestore rules). Phone matching is an open question.

## Owner side built (2026-11-21)
- `MemberInvite` (top-level `invites/{orgId}_{email}`, email lowercased, status pending/accepted/revoked, **no expiry**, roles manager/cashier only), `MemberInviteService` (send/pendingInvites/revoke), `AddMemberViewModel`/`AddMemberView`.
- Members screen: "Add member" button (only when `session.can(.admin)`, i.e. owner) + "Pending invites" section with tap-to-revoke. Route `.admin(.memberAdd)`.
- Invitee side built: one shared `InvitationsViewModel` (`ModulesContainer.invitationsViewModel`), refreshed in `AppCoordinator.syncAll` and on each screen's `.task`. Only a **verified** email is matched. Entry points: Home banner, More "Invitations (n)" row, "Invitations" section in `OrganizationListView`, banner on onboarding `ChooseVerticalView` (new users with no org). All open `InvitationsView`/`InvitationCard` (Accept / Decline).
- Accept: writes `members/{uid}`, appends to `assignedOrgs`, marks invite accepted. If the user has no current org it also selects it and writes the profile; otherwise it asks "Switch shop now?" (switching clears local cache, so never automatic). An existing user's legacy `role` is never overwritten. Decline sets status `declined`.
- Production-data check (docs/12 §9): `members` subcollection and `invites` are new/additive. Accept writes an existing profile only `assignedOrgs`, `assignedOrgIds`, `updatedAt`, `updatedTimestamp` (+ `selectedOrganization` if none); a full profile (incl. `createdAt`, `role`) only when no `users/{uid}` exists, so legacy string `createdAt`/`role` are never overwritten. Invite lists skip undecodable docs (old code-based invites). Still to verify: `assignedOrgs` is rewritten from decoded `OrganizationSnapshot`s, so unknown legacy keys inside those entries would be dropped; legacy users with no `members` doc aren't caught by the "already a member" check, and accepting gives them a member doc whose role overrides their legacy role.
- Not built yet: Firestore rules (read/update only where `email == request.auth.token.email` and `email_verified`; create only by org owner). Until rules exist, the invites collection must not be considered secure.

## Why
- No backend is needed for code sharing, but it is unfamiliar to the target users; email/phone add-by-identity is simpler for them.
- Left as is: `Member.status == "invited"` and `AppSession` check (still valid for the future add-by-email flow), `designs/` mockups, and `docs/08`, `10`, `12` wording about invites (stale, update when the new flow is designed).
- Not built or tested after the removal (per repo rule, build only on request).
