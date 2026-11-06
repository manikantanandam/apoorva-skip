# 01 — Product Vision & Features

## Vision
One app that lets any small shop bill a customer in seconds on a phone, then manage customers, bills, stock, staff and daily cashflow. It keeps working offline, and it looks and bills the way that kind of shop works.

## Personas
- **Owner / Org admin**: runs one or more stores. Wants daily totals, cashflow, dues, staff performance, and control over themes and features.
- **Store manager**: runs one store. Approves discounts, returns and day close.
- **Cashier**: bills fast, takes cash/UPI/card, prints or shares receipts.
- **Stylist (parlour)**: sees own appointments, services done and commission.
- **Apoorva super admin (us)**: app-level flags, vertical catalogue, support.

## One app, many shop types (verticals)
The shop type is chosen at onboarding. A **Vertical Profile** sets the billing style, catalog fields, default theme and default feature flags. A new vertical (handloom, stationery, pharmacy…) is a new profile, not a new app.

| Vertical | Billing style | Catalog fields | Default theme | Extra modules |
|----------|---------------|----------------|---------------|---------------|
| Kirana / General | Search-first list, loose items by weight, frequent items | Unit, weight/qty, MRP, barcode | Fresh Teal | Credit ledger (khata) |
| Fancy & Gifts | Tap tile grid with qty badges, variant sheet | Category, variants (size/colour), barcode | Orchid | Gift wrap add-on, low-stock nudges |
| One-gram Jewellery | Image catalog, design-code search | Design code, category, weight, images | Antique Gold | Trending designs, repeat buyers |
| Beauty Parlour | Services + stylist assignment, packages | Service duration, price, stylist, package | Rose | Appointments, stylist commission |
| Handloom (future) | Catalog + length/metre billing | Fabric, length, weave, colour | Indigo (TBD) | Tailoring orders |

## Modules (all in one app)

| Module | Key features |
|--------|--------------|
| **Billing (POS)** | Vertical-specific item picker, universal search, barcode scan, quick/custom-amount item, weight entry, line and bill discounts (manager PIN above limit), optional tax, UPI QR, split payment (cash/UPI/card/credit), hold & resume, returns/exchange, receipt print (Bluetooth) or share (WhatsApp/PDF/SMS) |
| **Bills & Sales** | List with quick filters, detail, reprint, share, collect, cancel with reason |
| **Customers** | Phone lookup, credit ledger and dues, lifetime value, add with minimal fields |
| **Inventory** | Items, variants, stock adjust with reason, low/out of stock |
| **Appointments** (parlour) | Day view by stylist, free slots, walk-ins, link to bill |
| **Daily Cashflow** | Opening, cash in/out, mode split, day close with counted cash |
| **Shop analytics (Insights)** | Sales trend, items, customers/dues ageing, staff leaderboard, export |
| **Settings** | Appearance (theme), printer, tax, invoice prefix, backup |
| **Admin** (owner/org admin) | Stores, staff & roles, permission matrix, org theme with lock, feature flags by org/store/role, audit log, invites. See [10](10-admin-and-multi-tenancy.md) |

| **Platform console** (Apoorva team only) | Org list, org detail, suspend/block/delete with reason, platform analytics, app-level flags, shop-type catalogue |

## Tax (optional, not a focus)
- Registration never asks about GST or tax rates. Tax is **Off** by default.
- Org setting under Settings → Tax: **Off** · **Same rate for all items** · **Per item** (rate set on each item; default 0%). Prices can include tax or add it on top.
- GSTIN is an optional field in Settings. Tax lines appear on receipts and reports only when tax is on.

## Plans
- **Free**: 1 store, owner only, billing, customers, cashflow, inventory, insights.
- **Pro** (₹199/month or ₹1,999/year, 14-day trial): staff accounts, multiple stores, reports export, packages & loyalty, priority support.
- Plan gating uses feature flags (see 05). A locked feature shows an upgrade or ask-owner screen, never a dead button.

## Languages
English, Telugu, Hindi, Tamil, Kannada for both app and receipts. Each can be set separately.

## Roles (summary; full matrix in 10)

| Role | Can |
|------|-----|
| Owner / Org admin | Everything, including Admin |
| Store manager | Billing, discounts > limit, cancel, returns, insights, day close for own store |
| Cashier | Billing, customers (create/read), cash entries, returns if allowed |
| Stylist | Own appointments, bill services, own performance |

## UX principles (hassle-free journey)
- **≤ 2 taps to start a bill** from anywhere: centre "New bill" tab plus universal search.
- **Every feature within one tap of a tab**: Home, Bills, New bill, Customers, More.
- **Role-aware UI**: hidden features never show as dead buttons. Locked ones show why.
- **Offline is normal**: there are no blocking spinners. A sync chip shows status.

## MVP (first release)
1. Onboarding with vertical choice, shop setup and theme
2. Billing for all 4 verticals, checkout, split payment, receipt share
3. Bills, customers with dues, cashflow with day close
4. Inventory basics, insights overview
5. Admin: staff & roles, theme lock, org/role feature flags
6. Offline-first sync to Firestore

## Later
Multi-store analytics roll-up, loyalty points, GSTR-1 export, supplier purchases, web admin console, handloom vertical.

## Success metrics
- Bill completion < 20 s for a 5-item cart
- 0 data loss after offline periods
- Weekly active shops, bills/day per shop, sync lag p95 < 30 s
