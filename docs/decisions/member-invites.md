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
- The More row, the switcher section and the onboarding link are always shown (with "No pending invitations" when empty) so the screen is reachable before any invite exists; only the Home banner needs count > 0.
- Organization details screen (`OrganizationDetailsView`, route `.admin(.organizationDetails)`): read-only summary of the org doc, shop profile, plan, tax/receipts, payments, accounts, stores and team (member cards with the role as a badge, then pending invites, shown inline instead of a separate members screen). Reached from Admin home ("Organization details", owner) and from Profile, where every member sees it (no permission gate, decided by the owner of the repo).
- Accept: writes `members/{uid}`, appends to `assignedOrgs`, marks invite accepted. If the user has no current org it also selects it and writes the profile; otherwise it asks "Switch shop now?" (switching clears local cache, so never automatic). An existing user's legacy `role` is never overwritten. Decline sets status `declined`.
- Production-data check (docs/12 §9): `members` subcollection and `invites` are new/additive. Accept writes an existing profile only `assignedOrgs`, `assignedOrgIds`, `updatedAt`, `updatedTimestamp` (+ `selectedOrganization` if none); a full profile (incl. `createdAt`, `role`) only when no `users/{uid}` exists, so legacy string `createdAt`/`role` are never overwritten. Invite lists skip undecodable docs (old code-based invites). Still to verify: `assignedOrgs` is rewritten from decoded `OrganizationSnapshot`s, so unknown legacy keys inside those entries would be dropped; legacy users with no `members` doc aren't caught by the "already a member" check, and accepting gives them a member doc whose role overrides their legacy role.
- **No `members` collection (decided 2026-11-21):** legacy data only has `users`. `memberRepository` is now `UsersMemberRepository` (read-only adapter over `listUsers(orgId:)`, no local cache or sync); `AppUser.member(in:)` builds a `Member` from the profile plus the optional additive `users/{uid}.orgMembership.{orgId}` (`OrgMembership`: role, storeIds, phone, isActive, baseSalary, commissionPercent, joinedAt). Missing entry means legacy role, all stores, active unless `isDeleted`. `createShop` and invite accept no longer write member docs; accept writes the `orgMembership` entry instead. Consumers (PIN switch, People, POS, Bills, Insights, AppSession) are unchanged. Costs: members are fetched from Firestore on each read (SDK cache offline); legacy users without PINs now appear in the PIN switch list; saving a member through the repository throws (no screen does).
- Not built yet: Firestore rules (must also stop an invitee from self-assigning a different role in `orgMembership`) (read/update only where `email == request.auth.token.email` and `email_verified`; create only by org owner). Until rules exist, the invites collection must not be considered secure.

## Why
- No backend is needed for code sharing, but it is unfamiliar to the target users; email/phone add-by-identity is simpler for them.
- Left as is: `Member.status == "invited"` and `AppSession` check (still valid for the future add-by-email flow), `designs/` mockups, and `docs/08`, `10`, `12` wording about invites (stale, update when the new flow is designed).
- Not built or tested after the removal (per repo rule, build only on request).
