# 01 — Product Vision & Features

## Vision
A **spot sales and spot services** billing app. It lets any small shop bill a walk-in customer in seconds on a phone, then manage customers, bills, stock, staff and daily cashflow. It keeps working offline, and it looks and bills the way that kind of shop works.

## Personas
- **Owner / Org admin**: runs one or more stores. Wants daily totals, cashflow, dues, staff performance, and control over themes and features.
- **Store manager**: runs one store. Approves discounts, returns and day close.
- **Cashier**: bills fast, takes cash/UPI/card, prints or shares receipts.
- **Apoorva super admin (us)**: app-level flags, vertical catalogue, support.

## One app, many shop types (verticals)
The shop type is chosen at onboarding. A **Vertical Profile** sets the billing style, catalog fields, default theme and default feature flags. A new vertical (handloom, stationery, pharmacy…) is a new profile, not a new app.

| Vertical | Billing style | Catalog fields | Default theme | Extra modules |
|----------|---------------|----------------|---------------|---------------|
| Kirana / General | Search-first list, loose items by weight, frequent items | Unit, weight/qty, MRP, barcode | Sage | Credit ledger (khata) |
| Fancy & Gifts | Tap tile grid with qty badges, variant sheet | Category, variants (size/colour), barcode | Plum | Gift wrap add-on, low-stock nudges |
| One-gram Jewellery | Image catalog, design-code search | Design code, category, weight, images | Brass | Trending designs, repeat buyers |
| Beauty Parlour | Spot service billing (walk-ins), optional "done by" staff, packages | Service, price, package sessions | Rose | Packages & memberships, staff commission |
| Handloom (future) | Catalog + length/metre billing | Fabric, length, weave, colour | Indigo (TBD) | Tailoring orders |

## Modules (all in one app)

| Module | Key features |
|--------|--------------|
| **Billing (POS)** | Vertical-specific item picker, universal search, barcode scan, quick/custom-amount item, weight entry, line and bill discounts (manager PIN above limit), optional tax, UPI QR, split payment (cash/UPI/card/credit), hold & resume, returns/exchange, receipt print (Bluetooth) or share (WhatsApp/PDF/SMS) |
| **Bills & Sales** | List with quick filters, detail, reprint, share, collect, cancel with reason |
| **Customers** | Phone lookup, credit ledger and dues, lifetime value, add with minimal fields |
| **Inventory** | Items, variants, stock adjust with reason, low/out of stock |
| **Daily Cashflow** | Opening, cash in/out, mode split, day close with counted cash |
| **Shop analytics (Insights)** | Sales trend, items, customers/dues ageing, staff leaderboard, export |
| **Settings** | Appearance (theme), printer, tax, invoice prefix, backup |
| **Admin** (owner/org admin) | Stores, staff & roles, permission matrix, org theme with lock, feature flags by org/store/role, audit log, invites. See [10](10-admin-and-multi-tenancy.md) |

| **Payments setup** | Shop UPI ID with ₹1 verification, payment modes (Cash, UPI, Card, Credit, Cheque), printable UPI QR standee |
| **Opening balances** | First-run entry of existing customer dues, supplier dues and cash (type, CSV or skip) |
| **Devices** | Signed-in phones, sign out one or all (lost phone) |
| **Platform console** (Apoorva team only) | Org list, org detail, suspend/block/delete with reason, platform analytics, app-level flags, shop-type catalogue |

## Tax (optional, not a focus)
- Registration never asks about GST or tax rates. Tax is **Off** by default.
- Org setting under Settings → Tax: **Off** · **Same rate for all items** · **Per item** (rate set on each item; default 0%). Prices can include tax or add it on top.
- GSTIN is an optional field in Settings. Tax lines appear on receipts and reports only when tax is on.

## Plans: try everything, then choose
- **30-day full trial**: every feature and unlimited bills from day one, so the shop gets used to the app and sees its value. No card needed.
- **Day 27**: a trial recap shows the value delivered (amount billed, bills, customers, dues collected, time saved), then the owner chooses Pro or Free.
- **Free** (after trial): 1 store, owner only, **100 bills per month** (resets on the 1st). Includes billing (all styles), customers & dues, cashflow & day close, basic inventory, today's insights.
- **Pro** (₹199/month or ₹1,999/year): unlimited bills and everything else. That covers staff accounts & PIN switch, multiple stores, suppliers & purchases, orders & advances, expenses & profit, reports & export, warranty, offers & catalog share, attendance & salary, and priority support.
- **Limits never block a customer**:
  - from 80% a usage meter appears on Home
  - at 100 bills a soft stop offers **10 grace bills**, then new bills pause until upgrade or the monthly reset
  - existing data is always viewable and exportable
- Limits are configurable at app level (`plan.trial_days`, `plan.free_bill_limit`, `plan.grace_bills`, see 05). Plan gating reuses feature flags. A locked feature shows Upgrade (owner) or Ask owner (staff), never a dead button.

## Languages
English, Telugu, Hindi, Tamil, Kannada for both app and receipts. Each can be set separately.

## Roles (summary; full matrix in 10)

| Role | Can |
|------|-----|
| Owner / Org admin | Everything, including Admin |
| Accountant (read-only) | View bills, insights and reports; export. No edits, no billing |
| Store manager | Billing, discounts > limit, cancel, returns, insights, day close for own store |
| Cashier | Billing, customers (create/read), cash entries, returns if allowed |

## UX principles (hassle-free journey)
- **≤ 2 taps to start a bill** from anywhere: centre "New bill" tab plus universal search.
- **Every feature within one tap of a tab**: Home, Bills, New bill, Customers, More.
- **Role-aware UI**: hidden features never show as dead buttons. Locked ones show why.
- **Offline is normal**: there are no blocking spinners. A sync chip shows status.

## Small-shop essentials (added after the day-in-the-life audit)
The audit walked a shop's whole day (open → sell → customers → stock → money → staff → close → month-end) for every shop type.

| Area | Feature | Why it matters for a small shop |
|------|---------|--------------------------------|
| Ease | **Easy mode (calculator billing)** | Bill by typing amounts. There is no item list to set up. Switch in Settings → Billing style |
| Ease | **Quick staff switch** | Shared counter phone: tap your name, enter a 4-digit PIN or use fingerprint |
| Ease | **Demo shop + one-time tips** | Try before signing up. A short tip on first use of each screen |
| Ease | **Home-screen widget & shortcuts** | New bill and today's sales without opening the app |
| Selling | **Undo bill (5 min) + edit bill** | Mistakes are fixed in one tap. Edits need a reason and are audited |
| Selling | **Retail / wholesale price** | Many kirana and fancy shops also sell to small retailers. The price tier is remembered per customer |
| Selling | **Units & packs** | Buy a box of 12, sell by piece. Kg and metre for loose goods and cloth |
| Selling | **Warranty (opt-in per item)** | Item has a warranty toggle with a period in days, months or years. The bill and receipt show "warranty till" a date. Warranty lookup by phone or bill. Claim as replace, repair or refund |
| Selling | **Bill as image** | WhatsApp image receipt as well as PDF and print |
| Customers | **Import from contacts** | Add regulars in seconds |
| Customers | **Birthdays & offers** | Free WhatsApp wishes and offer messages to a segment |
| Orders | **Orders with advance** | Custom jewellery, repairs, home delivery. Advance first, balance billed on delivery |
| Orders | **Catalog share** | Send design photos and prices on WhatsApp |
| Stock | **Suppliers & purchases** | Record purchases (items or total, with bill photo), supplier dues, pay supplier. Stock and cash update automatically |
| Stock | **Reorder list** | Low-stock items become a list sent to the supplier on WhatsApp |
| Money | **Expenses** | Rent, salary, electricity, with monthly repeat |
| Money | **Profit** | Sales − cost of goods − expenses. A default cost estimate is used when the cost price is missing |
| Money | **Daily summary** | End-of-day card. Can be sent to the owner's WhatsApp automatically |
| Staff | **Attendance & salary** | One-tap attendance, advances, commission. Salary paid goes to expenses |

## Release phases (all designs ship in v1, delivered in 3 phases; see 09)
| Phase | Scope |
|-------|-------|
| **R1 Core** | Sign-in (Google, phone, email), onboarding + opening balances, billing for all 4 verticals + Easy mode, checkout, payments setup & UPI, receipts, bills, customers & dues, cashflow & day close, inventory basics, offline sync, Clean theme |
| **R2 Business** | Suppliers & purchases (incl. returns), reorder, orders & advances, expenses & profit, warranty, wholesale price & units, insights & reports, daily summary, staff PIN switch, devices |
| **R3 Growth & control** | Admin (stores, members, roles incl. Accountant, permissions, theme, font, flags, audit), plans (Free/Pro), attendance & salary, offers & wishes, catalog share, widget, demo shop, platform console & support |

## v2 backlog (no v1 designs)
Multi-store analytics roll-up beyond the store switcher, loyalty points, GSTR-1 export, web admin console, handloom vertical, jewellery rental, barcode label printing, offers & combos, voice entry, expiry/batch, parlour consumables, web bill link with pay, referral program, bulk price update, import from Khatabook/Vyapar files, shop timings & holidays.

## Success metrics
- Bill completion < 20 s for a 5-item cart
- 0 data loss after offline periods
- Weekly active shops, bills/day per shop, sync lag p95 < 30 s
