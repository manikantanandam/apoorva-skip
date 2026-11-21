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
- Not built yet: Firestore rules (read/update only where `email == request.auth.token.email` and `email_verified`; create only by org owner). Until rules exist, the invites collection must not be considered secure.

## Why
- No backend is needed for code sharing, but it is unfamiliar to the target users; email/phone add-by-identity is simpler for them.
- Left as is: `Member.status == "invited"` and `AppSession` check (still valid for the future add-by-email flow), `designs/` mockups, and `docs/08`, `10`, `12` wording about invites (stale, update when the new flow is designed).
- Not built or tested after the removal (per repo rule, build only on request).
