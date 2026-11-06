#!/usr/bin/env python3
"""Generate Apoorva design PNGs: each image shows one screen in light and dark, side by side.

Screens are one-line specs in SCREENS (DSL below). Requires Google Chrome + Pillow.
Run from anywhere:  python3 designs/_src/generate.py

DSL: components separated by ';'  ->  kind:entry~entry~entry, fields inside an entry split by '|'.
A '*' suffix marks the selected chip/segment/swatch.
"""
import html
import random
import pathlib
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor

from PIL import Image

OUT = pathlib.Path(__file__).resolve().parents[1]
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
W, H, SCALE = 860, 880, 1.5

LIGHT = dict(bg="#F6F7F9", sf="#FFFFFF", tx="#111827", mu="#6B7280", bd="#E7E9EE", on="#FFFFFF",
             ok="#15803D", er="#B91C1C", wn="#B45309")
DARK = dict(bg="#0E1013", sf="#171A1F", tx="#F3F4F6", mu="#9CA3AF", bd="#262A31", on="#0E1013",
            ok="#4ADE80", er="#F87171", wn="#FBBF24")

THEMES = {
    "brand":   dict(a=("#4F46E5", "#A5B4FC"), name="Apoorva · Indigo"),
    "kirana":  dict(a=("#0F766E", "#2DD4BF"), name="Kirana · Fresh Teal", light=dict(bg="#F4F8F7")),
    "fancy":   dict(a=("#C026D3", "#E879F9"), name="Fancy & Gifts · Orchid", light=dict(bg="#F9F6FB")),
    "jewel":   dict(a=("#A16207", "#E2B865"), name="One-gram Jewellery · Antique Gold",
                    light=dict(bg="#FAF7F1"), dark=dict(bg="#12100C", sf="#1C1913", bd="#2E2920")),
    "parlour": dict(a=("#BE185D", "#F9A8D4"), name="Beauty Parlour · Rose", light=dict(bg="#FBF6F8")),
}

TABS = [("⌂", "Home"), ("≡", "Bills"), ("+", "New bill"), ("◎", "Customers"), ("⋯", "More")]

# (slug, caption, theme, active tab or None, spec)
SCREENS = [
    # Onboarding
    ("onboarding-splash", "Brand splash", "brand", None,
     "logo:Apoorva|Billing, beautifully simple"),
    ("onboarding-login", "Sign-in hub: Google, phone OTP, email. Each method is on/off from app config", "brand", None,
     "ab:Welcome|Sign in or create your shop account;sp:4;gbtn:Continue with Google;txt:or use your phone;field:Phone number|+91 98480 12345;btn:Send OTP;btn2:Sign in with email;txt:New here? Create an account with email;note:Only the methods turned on by Apoorva are shown. Works offline after the first sign-in."),
    ("onboarding-vertical", "Choose shop type: drives billing style, catalog fields and default theme", "brand", None,
     "ab:What do you sell?|We tailor billing and theme to your shop;steps:1|4;pick:Kirana / General|Quick search, loose items by weight|#0F766E~Fancy & Gifts|Item grid, variants, barcode|#C026D3|*~One-gram Jewellery|Catalog, design codes, weight|#A16207~Beauty Parlour|Services, stylists, appointments|#BE185D~More coming|Handloom, stationery, pharmacy|#6B7280;btn:Continue"),
    ("onboarding-shop", "Shop profile & tax", "fancy", None,
     "ab:Your shop|Shown on bills and receipts;steps:2|4;field:Shop name|Glitz Gifts & Fancy;field:Shop phone|+91 98480 12345;field:Address|Ameerpet, Hyderabad;field:Bill number prefix|GG-;note:Tax / GST is optional. Turn it on later in Settings → Tax only if you need it.;btn:Continue"),
    ("onboarding-theme", "Pick a look; preview updates live", "fancy", None,
     "ab:Pick a look|Change anytime in Settings;steps:3|4;seg:Light,Dark,System*;swatch:Teal|#0F766E~Orchid|#C026D3|*~Gold|#A16207~Rose|#BE185D~Indigo|#4F46E5~Slate|#334155;sec:Preview;kpis:Today's sales|₹12,400|+8% vs yesterday~Bills|46;btn:Finish setup"),
    # Home per vertical
    ("home-kirana", "Kirana dashboard", "kirana", 0,
     "ab:Sri Lakshmi Stores|Thu, 6 Nov · Synced|⌕;kpis:Today's sales|₹12,400|+8% vs yesterday~Bills|46|avg ₹270~Cash in hand|₹8,250~Dues|₹3,120|6 customers;sec:Quick actions;chips:Collect due,Cash entry,Add item,Day close;sec:Recent bills|See all;rows:Ravi Kumar|#A-1046 · 10:42|₹640|Paid~Walk-in|#A-1045 · 10:31|₹185|Paid~Meena S|#A-1044 · 10:12|₹1,120|Due"),
    ("home-fancy", "Fancy store dashboard with low-stock nudges", "fancy", 0,
     "ab:Glitz Gifts|Thu, 6 Nov · Synced|⌕;kpis:Today's sales|₹18,960|+14% vs last Thu~Bills|72~Top item|Glass Bangles~Low stock|9 items;sec:Low stock|Restock;rows:Teddy 12in|3 left|₹499|Low~Gift Wrap Roll|5 left|₹30|Low;sec:Recent bills|See all;rows:Sneha P|#GG-311 · 11:05|₹1,177|Paid"),
    ("home-jewel", "Jewellery dashboard: designs and repeat buyers", "jewel", 0,
     "ab:Swarna One Gram|Thu, 6 Nov · Synced|⌕;kpis:Today's sales|₹42,300|+5% this week~Pieces sold|31~Top design|ER-204~Repeat buyers|64%;sec:Trending designs|Catalog;grid:Lakshmi Haram|NK-118~Jhumka Gold|ER-204~Kemp Bangles|BG-031;sec:Recent bills|See all;rows:Lavanya K|#SG-208 · 12:10|₹3,340|Paid"),
    ("home-parlour", "Parlour dashboard: today's appointments first", "parlour", 0,
     "ab:Glow Studio|Thu, 6 Nov · Synced|⌕;kpis:Today's revenue|₹9,800|+11% vs last Thu~Appointments|14|3 walk-ins~Stylists in|4 of 5~Packages due|2;sec:Up next|Calendar;slots:11:00|Gold Facial · Anjali R|Anu · 60 min~11:30|Hair Spa · Divya M|Kavya · 45 min~12:15||"),
    # Billing
    ("bill-kirana", "Kirana billing: search-first, loose items by weight", "kirana", 2,
     "ab:New bill|Counter 1 · Ravi Kumar|⌕;search:Search item or scan · “atta”;chips:Frequent*,Grains,Oil,Dairy,Snacks;rows:Aashirvaad Atta 5kg|₹265 · stock 18|+~Toor Dal (loose)|₹140/kg · 0.5 kg|₹70~Sunflower Oil 1L|₹155 × 2|₹310~Amul Butter 100g|₹58|+;cart:4 items · Ravi Kumar|₹603|Charge"),
    ("bill-fancy", "Fancy billing: tap tiles, badges show qty", "fancy", 2,
     "ab:New bill|Walk-in customer|⌕;search:Search or scan barcode;chips:All*,Bangles,Gifts,Toys,Cosmetics;grid:Glass Bangles|₹120|2~Photo Frame|₹349~Teddy 12in|₹499|1~Keychain|₹79~Hair Clip Set|₹99~Gift Wrap|₹30|3;cart:6 items|₹1,177|Charge"),
    ("bill-fancy-variant", "Variant picker (size / colour) as a bottom sheet", "fancy", None,
     "ab:Glass Bangles|₹120 · 42 in stock|✕;gridbig:Glass Bangles|Set of 12;sec:Size;seg:2.2,2.4*,2.6,2.8;sec:Colour;swatch:Ruby|#B91C1C|*~Emerald|#047857~Royal|#1D4ED8~Gold|#CA8A04~Pearl|#E5E7EB;field:Quantity|2;btn:Add to bill · ₹240"),
    ("bill-jewel", "Jewellery billing: catalog with design codes", "jewel", 2,
     "ab:Catalog|Swarna One Gram|⌕;search:Design code e.g. ER-204;chips:All*,Necklace,Earrings,Bangles,Haram;grid2:Lakshmi Haram|NK-118 · ₹2,450|1~Jhumka Gold|ER-204 · ₹890~Kemp Bangles|BG-031 · ₹1,250|1~Temple Choker|NK-142 · ₹1,980;cart:2 items|₹3,700|Charge"),
    ("bill-parlour", "Parlour billing: services + stylist assignment", "parlour", 2,
     "ab:New bill|Anjali R · 11:00 appointment;seg:Services*,Packages,Products;rows:Gold Facial|60 min · Stylist Anu|₹1,200~Threading (Eyebrows)|10 min · Stylist Kavya|₹60~Hair Spa|45 min · choose stylist|+~Pedicure|40 min|+;sec:Stylist for Hair Spa;chips:Anu,Kavya*,Divya,Any free;cart:2 services|₹1,260|Charge"),
    ("bill-checkout", "Checkout: customer, totals, payment mode", "kirana", None,
     "ab:Checkout|Bill #A-1047|✕;rows:Ravi Kumar|+91 98480 12345 · dues ₹420|Change;kv:Subtotal (4 items)|₹603~Discount|−₹20~Round off|₹0.00~Total|₹583;sec:Payment;chips:Cash*,UPI,Card,Credit,Split;btn:Collect ₹583;btn2:Hold bill"),
    ("bill-split", "Split payment across modes", "kirana", None,
     "ab:Split payment|Total ₹1,236|✕;split:Cash|50~UPI|40~Card|10;rows:Cash|Received|₹620|Paid~UPI|Ref 4412 · scanned|₹500|Paid~Card|Remaining|₹116|Pending;pad:;btn:Confirm ₹116 by card"),
    ("bill-receipt", "Success + share/print receipt", "kirana", None,
     "hero:₹583|Bill #A-1047 saved · Ravi Kumar|✓;kv:Items|4~Paid by|Cash~Change returned|₹17;sec:Send receipt;chips:WhatsApp*,PDF,Print,SMS;btn:New bill;btn2:Back to home"),
    ("bill-held", "Held bills: park and resume", "fancy", 1,
     "ab:Held bills|3 parked · auto-clears at day close;rows:Walk-in · counter 2|5 items · 10:58|₹860|Held~Sneha P|2 items · 10:40|₹420|Held~Priya G|7 items · 09:55|₹2,140|Held;note:Tap a bill to resume. Stock is reserved until it is billed or discarded."),
    ("bill-return", "Return / exchange from a past bill", "fancy", None,
     "ab:Return / exchange|Bill #GG-298 · 2 Nov|✕;tg:Glass Bangles × 2|₹240|on~Photo Frame|₹349|off~Gift Wrap × 1|₹30|off;field:Reason|Size mismatch;seg:Refund cash*,Store credit,Exchange;kv:Refund|₹240;btn:Process return"),
    ("bill-scan", "Camera barcode scan with continuous add", "fancy", None,
     "ab:Scan|Point the camera at a barcode|✕;scan:;sec:Scanned;rows:Hair Clip Set|8901234567012|₹99~Keychain|8901234567029|₹79;cart:2 items|₹178|Done"),
    # Bills / sales
    ("bills-list", "Bills list with quick filters", "kirana", 1,
     "ab:Bills|₹12,400 today · 46 bills|⌕;chips:Today*,Yesterday,This week,Unpaid,Cancelled;rows:Ravi Kumar|#A-1046 · 10:42 · Cash|₹640|Paid~Walk-in|#A-1045 · 10:31 · UPI|₹185|Paid~Meena S|#A-1044 · 10:12 · Credit|₹1,120|Due~Suresh B|#A-1043 · 09:58 · Split|₹930|Paid~Walk-in|#A-1042 · 09:40 · Cash|₹260|Cancelled"),
    ("bills-detail", "Bill detail: reprint, share, collect, cancel", "kirana", 1,
     "ab:#A-1044|Meena S · Thu 6 Nov, 10:12|⋯;rows:Basmati Rice 5kg|₹540 × 1|₹540~Toor Dal 1kg|₹140 × 2|₹280~Ghee 500ml|₹300 × 1|₹300;kv:Subtotal|₹1,120~Paid|₹0~Balance due|₹1,120;chips:Reprint,Share,Cancel bill;btn:Collect ₹1,120"),
    # Customers
    ("customers-list", "Customers with dues filter", "kirana", 3,
     "ab:Customers|212 customers · ₹3,120 due|⌕;search:Name or phone;chips:All*,With dues,Regulars,New this month;rows:Meena S|98480 11223 · last visit today|₹1,120|Due~Ravi Kumar|98480 12345 · 2 days ago|₹420|Due~Lakshmi T|90000 45678 · 1 week ago|—~Suresh B|99887 66554 · today|—"),
    ("customers-detail", "Customer ledger and lifetime value", "kirana", 3,
     "ab:Meena S|98480 11223 · since Mar 2025|⋯;kpis:Balance due|₹1,120|since 6 Nov~Lifetime|₹48,600~Visits|86~Avg bill|₹565;sec:Ledger|Statement;rows:Bill #A-1044|6 Nov · credit|+₹1,120|Due~Payment · UPI|1 Nov|−₹800|Paid~Bill #A-0987|28 Oct|+₹800|Paid;btn:Collect due"),
    ("customers-add", "Add customer (minimal fields)", "kirana", None,
     "ab:New customer||✕;field:Name|Anitha Rao;field:Phone|+91 97010 55443;field:Birthday (optional)|12 Aug;field:Notes|Prefers home delivery;tg:WhatsApp receipts|Send bills on WhatsApp|on~Allow credit|Limit ₹2,000|on;btn:Save customer"),
    ("customers-collect", "Collect due with keypad", "kirana", None,
     "ab:Collect due|Meena S · due ₹1,120|✕;hero:₹800|of ₹1,120 due;chips:Cash,UPI*,Card;pad:;btn:Record ₹800 payment"),
    # Parlour
    ("parlour-appointments", "Appointments day view", "parlour", 0,
     "ab:Appointments|14 today · 2 free slots|+;chips:Thu 6*,Fri 7,Sat 8,Sun 9,Mon 10;seg:All stylists*,Anu,Kavya,Divya;slots:10:00|Bridal Trial · Harika|Anu · 90 min~11:00|Gold Facial · Anjali R|Anu · 60 min~11:30|Hair Spa · Divya M|Kavya · 45 min~12:15||~13:00|Manicure · Sowmya|Divya · 30 min"),
    ("parlour-staff", "Stylist performance & commission", "parlour", 4,
     "ab:Stylists|This month|⌕;bars:Revenue by stylist~Anu|92~Kavya|74~Divya|58~Rekha|40;rows:Anu|62 services · 4.9 ★|₹18,400|10%~Kavya|51 services · 4.8 ★|₹14,800|10%~Divya|40 services · 4.7 ★|₹11,600|8%"),
    # Inventory
    ("inventory-list", "Inventory with stock status", "fancy", 4,
     "ab:Inventory|1,240 items · 9 low|+;search:Search items or scan;chips:All,Low stock*,Out of stock,Bangles,Gifts;rows:Teddy 12in|SKU TB-12 · Toys|3 left|Low~Gift Wrap Roll|SKU GW-01 · Gifts|5 left|Low~Hair Clip Set|SKU HC-07 · Cosmetics|0|Out~Kids Watch|SKU KW-02 · Gifts|4 left|Low"),
    ("inventory-item", "Item detail with variants and movement", "fancy", 4,
     "ab:Teddy 12in|TB-12 · Toys|⋯;gridbig:Teddy 12in|3 variants;kv:Price|₹499~Cost|₹310~Stock|3 (low at 5)~Barcode|8901234567036;bars:Sold last 7 days~M|30~T|45~W|20~T|60~F|80~S|100~S|70;btn:Adjust stock"),
    ("inventory-adjust", "Stock adjust with reason", "fancy", None,
     "ab:Adjust stock|Teddy 12in · now 3|✕;seg:Add*,Remove,Set exact;hero:+24|new stock 27;chips:Purchase*,Return,Damage,Count fix;pad:;btn:Save"),
    # Cashflow
    ("cashflow-day", "Daily cashflow by mode", "kirana", 4,
     "ab:Cashflow|Thu 6 Nov · open since 8:30|+;kpis:Expected closing|₹8,250~Opening|₹2,000~Cash in|₹7,450~Cash out|₹1,200;split:Cash|48~UPI|44~Card|8;sec:Entries|All;rows:Supplier payment|Out · 09:20 · Ramesh Traders|−₹1,000~Tea & snacks|Out · 11:00|−₹200~Bill sales (cash)|In · auto|+₹7,450"),
    ("cashflow-add", "Add cash entry", "kirana", None,
     "ab:Cash entry||✕;seg:Cash in,Cash out*;hero:₹1,000|Supplier payment;chips:Supplier*,Rent,Salary,Tea & snacks,Other;pad:;btn:Save entry"),
    ("cashflow-close", "Day close with counted cash", "kirana", None,
     "ab:Close day|Thu 6 Nov|✕;kv:Expected cash|₹8,250~Counted cash|₹8,200~Difference|−₹50;field:Note|₹50 given as change float;tg:Carry forward as opening|₹8,200 for Fri 7 Nov|on;note:Closing locks today's entries. Owners can reopen from Admin.;btn:Close day"),
    # Shop analytics
    ("analytics-overview", "Shop analytics overview", "jewel", 4,
     "ab:Insights|Swarna One Gram|⇩;seg:Today,Week*,Month,Custom;line:Sales this week|₹2,84,200|+12%~30,45,38,60,52,74,88;kpis:Bills|412~Avg bill|₹690~Margin|38%~New customers|57;split:UPI|56~Cash|34~Card|10"),
    ("analytics-items", "Top designs and slow movers", "jewel", 4,
     "ab:Items|This month|⇩;bars:Top categories~Haram|100~Earrings|82~Bangles|64~Choker|40~Rings|22;sec:Best sellers;rows:Jhumka Gold|ER-204 · 64 sold|₹56,960~Lakshmi Haram|NK-118 · 21 sold|₹51,450;sec:Slow movers;rows:Kemp Ring|RG-009 · 0 sold in 45 days|—|Low"),
    ("analytics-customers", "Customer insights and dues ageing", "kirana", 4,
     "ab:Customers|This month|⇩;kpis:Repeat rate|68%~New|31~Avg visits|3.4~Dues|₹3,120;bars:Dues ageing~0-7d|100~8-30d|60~31-60d|25~60d+|12;sec:Top customers;rows:Meena S|9 visits|₹6,420~Ravi Kumar|7 visits|₹4,880"),
    ("analytics-staff", "Staff sales leaderboard", "fancy", 4,
     "ab:Staff|This week|⇩;bars:Sales by staff~Kiran|100~Pooja|76~Rahul|54;rows:Kiran|Counter 1 · 142 bills|₹42,300~Pooja|Counter 2 · 108 bills|₹32,100~Rahul|Counter 3 · 77 bills|₹22,800;note:Discounts above 10% by staff: 4 this week."),
    # More / settings
    ("more-menu", "More: everything within one tap", "kirana", 4,
     "ab:More|Sri Lakshmi Stores · Owner;rows:Inventory|1,240 items|›~Cashflow|Day open|›~Insights|Sales, items, customers|›~Held bills|3 parked|›~Settings|Printer, tax, appearance|›~Admin|Stores, staff, themes, features|›~Help & feedback|Chat, guides|›"),
    ("settings-appearance", "Appearance: user theme, org lock respected", "parlour", 4,
     "ab:Appearance||;seg:Light,Dark,System*;sec:Accent colour;swatch:Rose|#BE185D|*~Teal|#0F766E~Orchid|#C026D3~Gold|#A16207~Indigo|#4F46E5;tg:Use organisation theme|Set by Glow Studio admin|lock~Larger text|Bigger amounts on billing|off~Compact lists|More rows per screen|off;note:Your admin has locked the theme. Light/Dark mode is still yours."),
    # Admin
    ("admin-home", "Admin home (Owner / Org admin only)", "brand", 4,
     "ab:Admin|Glow Studio Group · 3 stores;kpis:Stores|3~Staff|14~Features on|11 of 16~Last sync|1 min ago;rows:Stores|Branches, verticals, GST|›~Staff & roles|Invite, assign, deactivate|›~Permissions|What each role can do|›~Theme|Organisation look & lock|›~Features|On/off by org, store, role|›~Audit log|Who changed what|›"),
    ("admin-stores", "Stores and their verticals", "brand", 4,
     "ab:Stores|3 active|+;rows:Glow Studio · Ameerpet|Beauty Parlour · 6 staff|Active|Live~Glitz Gifts · Kukatpally|Fancy & Gifts · 5 staff|Active|Live~Swarna One Gram · Dilsukhnagar|Jewellery · 3 staff|Setup|Pending;btn:Add store"),
    ("admin-members", "Members across all stores", "brand", 4,
     "ab:Members|14 people · 3 stores|+;search:Name, phone or role;chips:All*,Ameerpet,Kukatpally,Dilsukhnagar,Inactive;rows:Anu R|Stylist · Ameerpet · active 5 min ago||Active=ok~Kiran M|Cashier · Kukatpally · today||Active=ok~Sravani K|Manager · Dilsukhnagar · 3 days ago||Active=ok~Rahul T|Cashier · invite sent 4 Nov||Invited=wn~Mahesh|Cashier · deactivated 1 Oct||Inactive=er"),
    ("admin-permissions", "Role permission matrix", "brand", 4,
     "ab:Permissions|Tap a cell to change;mx:Action|Owner|Mgr|Cashier|Stylist~Create bill|1|1|1|1~Discount > 10%|1|1|0|0~Cancel bill|1|1|0|0~Returns|1|1|1|0~Credit sales|1|1|0|0~View insights|1|1|0|0~Cash out|1|1|1|0~Edit inventory|1|1|0|0;btn:Save changes"),
    ("admin-theme", "Organisation theme with lock", "brand", 4,
     "ab:Theme|Applies to all staff devices;seg:Organisation*,Per store;swatch:Rose|#BE185D|*~Teal|#0F766E~Orchid|#C026D3~Gold|#A16207~Indigo|#4F46E5;tg:Lock theme for staff|Staff can't change accent|on~Allow dark mode|Staff choose light/dark|on~Show logo on receipts|Uses org logo|on;btn:Publish theme"),
    ("admin-features", "Feature flags at org / store / role level", "brand", 4,
     "ab:Features|Organisation level;seg:Organisation*,Store,Role;tg:Credit sales|Let customers pay later|on~Returns & exchange|Within 7 days|on~Appointments|Parlour stores|on~Bluetooth printing|Receipt printer|off~Loyalty points|Coming soon · set by Apoorva|lock;note:App-level switches from Apoorva always win. Then store, then role."),
    ("admin-audit", "Audit log", "brand", 4,
     "ab:Audit log|Last 7 days|⇩;chips:All*,Bills,Cash,Settings,Staff;rows:Pooja S cancelled #GG-302|Reason: duplicate · 10:12|Bills~Owner changed theme to Rose|All stores · yesterday|Settings~Kiran M cash out ₹500|Ameerpet · yesterday|Cash~Owner invited Rahul T|Cashier · 4 Nov|Staff"),
    ("admin-invite", "Invite staff with role and stores", "brand", None,
     "ab:Invite staff||✕;field:Name|Rahul T;field:Phone|+91 99000 11223;sec:Role;seg:Manager,Cashier*,Stylist;sec:Stores;chips:Ameerpet,Kukatpally*,Dilsukhnagar;note:Rahul gets an SMS link. Access follows the Cashier permissions.;btn:Send invite"),
    # Global
    ("global-search", "Universal search across customers, bills, items, actions", "kirana", None,
     "ab:Search||✕;search:ravi;sec:Customers;rows:Ravi Kumar|98480 12345 · dues ₹420|›;sec:Bills;rows:#A-1046 · Ravi Kumar|Today 10:42|₹640|Paid;sec:Items;rows:Ravi Masala 100g|₹45 · stock 22|+;sec:Actions;chips:New bill for Ravi,Collect due,Call"),
    ("global-sync", "Offline / sync status", "kirana", None,
     "ab:Sync|Offline since 10:02|✕;hero:3|changes waiting to sync|⟳;rows:Bill #A-1047|Saved on this phone|₹583|Pending~Cash out ₹200|Saved on this phone|—|Pending~New customer Anitha|Saved on this phone|—|Pending;note:Everything works offline. Changes upload automatically when you're back online.;btn:Retry now"),
]

TABS_TE = [("⌂", "హోమ్"), ("≡", "బిల్లులు"), ("+", "కొత్త బిల్లు"), ("◎", "కస్టమర్లు"), ("⋯", "మరిన్ని")]

# Added screens: (insert after slug, screen). A tab value >= 10 uses Telugu tab labels.
EXTRA = [
    ("onboarding-login", ("onboarding-otp", "Enter OTP (auto-read on Android)", "brand", None,
     "ab:Verify phone|Code sent to +91 98480 12345;sp:6;hero:4 8 2 _|Enter the 4-digit code;pad:;txt:Resend code in 0:24;btn:Verify")),
    ("onboarding-otp", ("onboarding-join", "Staff joins via invite: no shop setup needed", "brand", None,
     "ab:You're invited|Glow Studio Group;hero:Cashier|Kukatpally store · invited by Owner|✉;kv:Name|Rahul T~Phone|+91 99000 11223~Access|Billing, customers, cash;note:You will use the shop's theme and settings. Nothing to set up.;btn:Join shop;btn2:Not you? Use another number")),
    ("onboarding-theme", ("home-empty", "First run: guided steps instead of empty charts", "kirana", 0,
     "ab:Sri Lakshmi Stores|Let's get you billing|⌕;empty:✦|Welcome! 3 quick steps|Most shops finish this in 5 minutes.;rows:Add your first item|Or bill with custom amounts|+~Create your first bill|Takes about 20 seconds|+~Add a customer|For credit and reminders|+;btn:Create first bill;btn2:Import items from Excel / CSV")),
    ("home-kirana", ("home-kirana-te", "Telugu: text-length check on the same layout", "kirana", 10,
     "ab:శ్రీ లక్ష్మి స్టోర్స్|గురు, 6 నవం · సింక్ అయింది|⌕;kpis:ఈరోజు అమ్మకాలు|₹12,400|నిన్నటి కంటే +8%~బిల్లులు|46|సగటు ₹270~చేతిలో నగదు|₹8,250~బాకీలు|₹3,120|6 కస్టమర్లు;sec:త్వరిత చర్యలు;chips:బాకీ వసూలు,నగదు ఎంట్రీ,వస్తువు జోడించు,రోజు ముగింపు;sec:ఇటీవలి బిల్లులు|అన్నీ చూడండి;rows:రవి కుమార్|#A-1046 · 10:42|₹640|చెల్లింది=ok~వాక్-ఇన్|#A-1045 · 10:31|₹185|చెల్లింది=ok~మీనా ఎస్|#A-1044 · 10:12|₹1,120|బాకీ=er")),
    ("home-parlour", ("home-store-switch", "Store switcher for multi-store owners", "brand", None,
     "ab:Switch store|Glow Studio Group · 3 stores|✕;pick:Glow Studio · Ameerpet|Beauty Parlour · ₹9,800 today|#BE185D|*~Glitz Gifts · Kukatpally|Fancy & Gifts · ₹18,960 today|#C026D3~Swarna One Gram · Dilsukhnagar|Jewellery · ₹42,300 today|#A16207;sec:All stores today;kpis:Combined sales|₹71,060|+9% vs last Thu~Bills|132;btn:Switch")),
    ("bill-kirana", ("bill-weight", "Loose item by weight or by amount", "kirana", None,
     "ab:Toor Dal (loose)|₹140 per kg|✕;seg:By weight*,By amount;hero:0.500 kg|= ₹70.00;chips:250 g,500 g*,1 kg,2 kg,5 kg;pad:;btn:Add to bill · ₹70")),
    ("bill-weight", ("bill-custom", "Unlisted item: bill any amount in seconds", "kirana", None,
     "ab:Quick item|Not in your list? Bill it anyway|✕;hero:₹250|Miscellaneous;field:Name (optional)|Plastic covers;chips:Misc*,Groceries,Snacks,Service;tg:Save as new item|Add to inventory for next time|off;pad:;btn:Add ₹250 to bill")),
    ("bill-fancy-variant", ("bill-line-edit", "Edit a line: qty, price, item discount, remove", "fancy", None,
     "ab:Teddy 12in|₹499 · 3 in stock|✕;sec:Quantity;seg:−,1*,+;field:Price|₹499;sec:Item discount;seg:None,₹ off*,% off;field:Discount|₹50;kv:Line total|₹449;btn:Update line;btn2:Remove from bill")),
    ("bill-line-edit", ("bill-discount", "Bill discount with role limit + manager PIN", "fancy", None,
     "ab:Bill discount|Subtotal ₹1,177|✕;seg:₹ amount,%*;hero:10%|−₹118 · new total ₹1,059;chips:5%,10%*,15%,Round to ₹1,050;note:Cashiers can give up to 10%. Above that a manager approves on this phone with their PIN.;btn:Apply discount")),
    ("bill-jewel", ("bill-jewel-item", "Jewellery design detail with photos", "jewel", None,
     "ab:Jhumka Gold|ER-204 · Earrings|✕;gridbig:Jhumka Gold|4 photos · swipe;kv:Price|₹890~Weight|18 g~Finish|Matte gold, kemp stones~Stock|12 pairs;chips:Similar designs,Share photo;btn:Add to bill · ₹890")),
    ("bill-parlour", ("bill-parlour-package", "Packages & memberships with sessions left", "parlour", None,
     "ab:Packages|Anjali R|✕;rows:Bridal Glow (5 sessions)|2 of 5 used · valid till 30 Dec|₹6,500|Active=ok~Hair Spa × 4|4 of 4 used|₹2,400|Used up=wn;sec:Sell a new package;rows:Monthly Glow|Facial + spa · 30 days|₹2,999~Gold Membership|10% off all services · 1 year|₹1,999;btn:Use 1 session today")),
    ("bill-parlour-package", ("bill-customer", "Attach customer: search, recent or quick add", "kirana", None,
     "ab:Customer for this bill||✕;search:Name or phone · 98480;rows:Ravi Kumar|98480 12345 · dues ₹420|›~Ravindra P|98480 77881 · last visit 3 Nov|›;sec:Recent;chips:Meena S,Suresh B,Lakshmi T;sec:New customer;field:Phone|98480 55667;field:Name|Kiran;btn:Add & attach;btn2:Continue as walk-in")),
    ("bill-split", ("bill-upi", "UPI QR with amount", "kirana", None,
     "ab:Pay by UPI|Bill #A-1047|✕;qr:sri.lakshmi@okaxis;hero:₹583|Scan with any UPI app;chips:GPay,PhonePe,Paytm,BHIM;btn:Mark as received;btn2:Change mode")),
    ("bill-receipt", ("bill-receipt-preview", "Printed receipt (58 mm). Tax lines only when tax is on", "kirana", None,
     "ab:Receipt preview|58 mm thermal · Bluetooth|✕;receipt:SRI LAKSHMI STORES|Ameerpet · 98480 12345~Bill A-1047|06-11-2026 10:52~—|~Aashirvaad Atta 5kg|265.00~Toor Dal 0.5kg|70.00~Sunflower Oil 1L x2|310.00~Amul Butter 100g|58.00~—|~Discount|-20.00~TOTAL|Rs 583.00~Cash|600.00  change 17.00~—|~Thank you! Visit again|;btn:Print;btn2:Share PDF")),
    ("bills-detail", ("bills-cancel", "Cancel needs a reason. Stock and dues reverse", "kirana", None,
     "ab:Cancel bill #A-1044|₹1,120 · Meena S|✕;pick:Entered by mistake|Wrong items or amount|#6B7280|*~Customer changed mind||#6B7280~Duplicate bill||#6B7280~Other||#6B7280;field:Note|Billed twice at counter 1;note:Stock goes back and the due of ₹1,120 is removed. This is recorded in the audit log.;btn:Cancel bill")),
    ("bills-cancel", ("bills-filter", "Filter sheet", "kirana", None,
     "ab:Filter bills||✕;sec:Date;chips:Today,Yesterday,This week*,This month,Custom;sec:Payment;chips:Cash*,UPI*,Card,Credit,Split;sec:Status;seg:All*,Paid,Due,Cancelled;sec:Staff;chips:All*,Kiran,Pooja,Rahul;btn:Show 212 bills;btn2:Reset")),
    ("customers-collect", ("customers-reminder", "Due reminder on WhatsApp / SMS with UPI link", "kirana", None,
     "ab:Send reminder|Meena S · due ₹1,120|✕;seg:WhatsApp*,SMS;note:Namaste Meena garu, your balance at Sri Lakshmi Stores is ₹1,120. Pay by UPI: sri.lakshmi@okaxis. Thank you!;chips:English*,తెలుగు,हिंदी,தமிழ்,ಕನ್ನಡ;tg:Add UPI payment link|Customer pays in one tap|on~Remind again in 7 days|If still unpaid|on;btn:Send on WhatsApp")),
    ("customers-reminder", ("customers-statement", "Customer statement (PDF / image)", "kirana", None,
     "ab:Statement|Meena S|✕;chips:This month*,Last 3 months,This year,Custom;kv:Opening balance|₹800~Bills|+₹3,240~Payments|−₹2,920~Closing balance|₹1,120;seg:PDF*,Image;btn:Share on WhatsApp;btn2:Download")),
    ("parlour-appointments", ("parlour-book", "New appointment", "parlour", None,
     "ab:New appointment||✕;field:Customer|Anjali R · 98480 33221;sec:Services;chips:Gold Facial*,Hair Spa*,Threading,Manicure;sec:Stylist;chips:Anu*,Kavya,Divya,Any free;sec:Fri 7 Nov;chips:10:00,11:30*,13:00,15:30,17:00;tg:WhatsApp confirmation|Reminder 2 hours before|on;btn:Book · 105 min · ₹2,000")),
    ("inventory-list", ("inventory-add", "Add item: only name and price required", "fancy", None,
     "ab:New item||✕;gridbig:Add photo|Optional;field:Name|Kids Watch;field:Selling price|₹349;field:Category|Gifts;field:Stock|12;tg:Has variants|Size or colour|off~Track stock|Warn when low|on;btn2:More: barcode, cost price, tax rate;btn:Save item")),
    ("inventory-adjust", ("inventory-categories", "Categories: manage and reorder billing chips", "fancy", 4,
     "ab:Categories|Drag to reorder billing chips|+;rows:Bangles|312 items|⋮⋮~Gifts|248 items|⋮⋮~Toys|190 items|⋮⋮~Cosmetics|276 items|⋮⋮~Hair accessories|214 items|⋮⋮")),
    ("inventory-categories", ("inventory-import", "Bulk import from Excel / CSV", "fancy", None,
     "ab:Import items||✕;empty:⇪|items.csv · 1,240 rows|Columns matched automatically;kv:Name|Column A~Category|Column B~Price|Column C~Stock|Column D;rows:Ready to add|1,198 items||Ready=ok~Need attention|42 rows · missing price||Fix=wn;btn:Import 1,198 items;btn2:Download template")),
    ("cashflow-close", ("cashflow-history", "Previous days with cash differences", "kirana", 4,
     "ab:Cash history|November|⇩;rows:Wed 5 Nov|Closed by Owner · diff ₹0|₹7,980|Matched=ok~Tue 4 Nov|Closed by Kiran · diff −₹40|₹6,420|Short=wn~Mon 3 Nov|Closed by Owner · diff ₹0|₹8,110|Matched=ok~Sun 2 Nov|Shop closed|—")),
    ("analytics-staff", ("analytics-reports", "Reports & export", "jewel", 4,
     "ab:Reports|Download or share|⇩;chips:This month*,Last month,Custom;rows:Sales summary|Day-wise totals by payment mode|PDF~Item-wise sales|Quantity and value by item|Excel~Customer dues|Who owes what, ageing|PDF~Cash book|All cash in and out|PDF~Staff performance|Bills, sales, discounts|Excel~Tax summary|Only when tax is on|Excel")),
    ("settings-appearance", ("settings-tax", "Tax is optional: Off by default, same rate or per item", "kirana", 4,
     "ab:Tax|Optional · off for most small shops;seg:Off,Same for all*,Per item;field:Tax rate|5%;seg:Price includes tax*,Add tax on top;field:GSTIN (optional)|Add only if registered;tg:Show tax on receipts|Only when tax is on|on;note:Per item: set a rate on each item. Items without a rate use 0%.")),
    ("settings-tax", ("settings-receipt", "Receipt & bill numbering", "kirana", 4,
     "ab:Receipts|What customers see;field:Header|Sri Lakshmi Stores;field:Footer|Thank you! Visit again;field:Bill number|Prefix A- · next A-1048;tg:Show shop logo|On PDF receipts|on~Show UPI QR|Customers pay from the receipt|on~Auto-share on WhatsApp|When customer has a phone|off;seg:58 mm*,80 mm,A4 PDF")),
    ("settings-receipt", ("settings-printer", "Bluetooth printer pairing", "kirana", 4,
     "ab:Printer|Bluetooth thermal;empty:⎙|Searching nearby…|Turn on your printer and keep it close.;pick:RPP02N-5821|58 mm · strong signal|#15803D|*~MTP-II|58 mm · weak signal|#B45309;tg:Print automatically|After every bill|off~Open cash drawer|If connected|off;btn:Print test page")),
    ("settings-printer", ("settings-language", "Language: app and receipts set separately", "kirana", 4,
     "ab:Language|Changes instantly;rows:English|English|✓~తెలుగు|Telugu|~हिंदी|Hindi|~தமிழ்|Tamil|~ಕನ್ನಡ|Kannada|;sec:Receipt language;seg:Same as app*,English,తెలుగు")),
    ("settings-language", ("settings-backup", "Backup, restore and export your data", "kirana", 4,
     "ab:Backup & data|Your data is yours;kpis:Last cloud backup|2 min ago|automatic~On this phone|48 MB;rows:Export all data|Excel + PDF · sent to your email|›~Backup to Google Drive|Weekly · last Sunday|›~Restore from backup|Choose a date|›;note:Bills are saved on this phone first and copied to the cloud when online.")),
    ("settings-backup", ("settings-account", "Profile & account", "brand", 4,
     "ab:Account|Owner · Sri Lakshmi Stores;rows:Kumar Swamy|+91 98480 12345 · Owner|›~Security|App PIN, fingerprint|›~Devices|2 phones signed in|›~Notifications|Dues, low stock, day close|›;btn2:Sign out;txt:Delete account and shop data")),
    ("settings-account", ("settings-plan", "Plan & subscription: Free vs Pro", "brand", 4,
     "ab:Your plan|Free · 1 store;mx:Feature|Free|Pro~Billing & customers|1|1~Staff accounts|0|1~Multiple stores|0|1~Reports export|0|1~Packages & loyalty|0|1~Priority support|0|1;kpis:Pro|₹199/month|or ₹1,999/year~Free trial|14 days|no card needed;btn:Start free trial")),
    ("admin-members", ("admin-member-add", "Add member directly or invite by SMS", "brand", None,
     "ab:Add member||✕;seg:Invite by SMS,Add directly*;field:Name|Sravani K;field:Phone|+91 90000 33445;sec:Role;seg:Manager*,Cashier,Stylist;sec:Stores;chips:Ameerpet,Kukatpally,Dilsukhnagar*;field:4-digit login PIN|• • • •;btn:Add member")),
    ("admin-member-add", ("admin-member-detail", "Member detail: role, stores, deactivate", "brand", None,
     "ab:Kiran M|Cashier · since Jun 2025|⋯;kpis:Sales this month|₹1,42,300~Bills|612~Discounts|1.8%~Cash difference|−₹40;tg:Active|Can sign in and bill|on~Kukatpally|Store access|on~Ameerpet|Store access|off;rows:Role|Cashier|Change;btn2:Deactivate member;txt:Past bills stay in reports and the audit log")),
    ("admin-stores", ("admin-store-detail", "Store detail & edit", "brand", None,
     "ab:Glitz Gifts · Kukatpally|Fancy & Gifts · since Mar 2025|⋯;field:Store name|Glitz Gifts;field:Address|KPHB Colony, Kukatpally;field:Bill number prefix|GG-;rows:Shop type|Fancy & Gifts|›~Theme|Orchid · locked|›~Tax|Off|›~Printer|RPP02N · paired|›;btn:Save changes")),
    ("admin-invite", ("platform-home", "Apoorva Console: hidden, superAdmin accounts only", "brand", 4,
     "ab:Apoorva Console|Super admin · production;kpis:Active orgs|1,284|+42 this week~Bills today|61,920~Blocked orgs|7~Sync errors|0.4%;rows:Organisations|Search, suspend, block, plans|›~Platform analytics|Growth, usage, health|›~App flags|Kill switches, rollouts|›~Shop types|Verticals catalogue|›~Support|Tickets, read-only view|›")),
    ("platform-home", ("platform-orgs", "All organisations", "brand", 4,
     "ab:Organisations|1,284 total|⌕;search:Org name, owner phone or ID;chips:All*,Active,Suspended,Blocked,Pro,Trial;rows:Glow Studio Group|Parlour · 3 stores · Pro|₹4.2L/mo|Active=ok~Sri Lakshmi Stores|Kirana · 1 store · Free|₹3.1L/mo|Active=ok~Raj Fancy|Fancy · payment due|₹0.9L/mo|Suspended=wn~Fake Mart|Kirana · 12 spam reports|—|Blocked=er")),
    ("platform-orgs", ("platform-org-detail", "Organisation detail", "brand", None,
     "ab:Raj Fancy|Org 7F2A · since Jan 2026|⋯;kpis:Status|Suspended|payment due 12 days~Plan|Pro~Stores|2~Members|6;rows:Owner|Raj K · 98490 22113|Call~Last active|Today 11:20|—~Bills this month|1,204|—~App version|1.4.2 · Android|—;btn:Reactivate;btn2:Block organisation")),
    ("platform-org-detail", ("platform-org-block", "Suspend / block / delete with reason; owner notified", "brand", None,
     "ab:Block organisation|Raj Fancy|✕;seg:Suspend*,Block,Delete;pick:Payment overdue||#B45309|*~Fraud or abuse||#B91C1C~Terms violation||#B91C1C~Owner request||#6B7280;seg:7 days,30 days*,Until lifted;tg:Notify owner by SMS|With reason and how to fix|on~Allow data export|Owner can still download data|on;btn:Suspend for 30 days")),
    ("platform-org-block", ("platform-blocked", "What a suspended org's staff see", "brand", None,
     "sp:90;empty:⊘|Account paused|Glitz Gifts is paused because the subscription is overdue.;kv:Reason|Payment overdue~Since|6 Nov 2026~Your data|Safe · read-only;btn:Pay & reactivate;btn2:Export my data;txt:Need help? Call 1800 123 4567")),
    ("platform-blocked", ("platform-analytics", "Platform analytics (app level)", "brand", 4,
     "ab:Platform analytics|Last 30 days|⇩;line:Weekly active shops|9,840|+6%~60,64,70,72,78,85,88;kpis:New orgs|1,120~Activation|71%|first bill in 24 h~D30 retention|58%~Crash-free users|99.7%;bars:Active shops by type~Kirana|100~Fancy|62~Parlour|44~Jewellery|28;split:Android|78|Platform~iOS|22")),
    ("platform-analytics", ("platform-flags", "App-level flags & shop types", "brand", 4,
     "ab:App flags|Wins over every org setting;seg:Flags*,Shop types;tg:Loyalty points|Rollout 10% · Pro only|on~Reports export|100%|on~Bluetooth printing|Android 72%|on~Kill: sync writes|Emergency stop|off;rows:Handloom|Shop type · draft||Draft=wn~Stationery|Shop type · planned||Planned;note:Changes reach phones within an hour or on the next app open.")),
    ("global-sync", ("global-conflict", "Sync conflict: same bill edited on two phones", "kirana", None,
     "ab:Needs review|1 conflict · bill #A-1031|✕;note:This bill was changed on two phones while offline. Pick the correct version.;rows:This phone · Kiran|Edited 10:12 · 3 items|₹930|Pending~Counter 2 · Pooja|Edited 10:15 · 4 items|₹1,050|Pending;btn:Keep counter 2 version;btn2:Keep this phone's version")),
    ("global-conflict", ("global-notifications", "Notifications centre", "kirana", None,
     "ab:Notifications|3 new|✓;rows:Low stock · 4 items|Teddy, gift wrap and 2 more|10:30|New=wn~Day not closed|Yesterday's cash is still open|09:00|New=er~Meena S paid ₹800|UPI · auto-matched|Yesterday~Backup complete|All data safe in the cloud|Yesterday")),
    ("global-notifications", ("global-locked", "Feature not allowed for this role or plan", "fancy", None,
     "ab:Insights||✕;sp:40;empty:⚿|Ask your owner for access|Insights are available to owners and managers.;btn:Request access;btn2:Go back;note:For Pro features, owners see an Upgrade button here instead.")),
    ("global-locked", ("global-update", "Force update (min_app_version)", "brand", None,
     "sp:110;empty:↑|Update required|This version can no longer sync safely. Update to keep billing.;kv:Your version|1.2.0~Required|1.4.0;btn:Update now;txt:Unsynced bills are safe and upload after the update")),
    ("global-update", ("global-help", "Help & feedback", "kirana", 4,
     "ab:Help|We reply within 1 hour;search:Search help · e.g. printer;rows:How to bill loose items|2 min video|›~Connect a Bluetooth printer|Step by step|›~Collect dues on WhatsApp|Guide|›;chips:Chat on WhatsApp,Call us,Report a bug;note:Report a bug attaches app logs (no customer data) so we can fix it faster.")),
    ("onboarding-login", ("auth-email-login", "Email sign-in", "brand", None,
     "ab:Sign in with email||✕;field:Email|kumar.swamy@gmail.com;field:Password|••••••••••   👁;txt:Forgot password?;btn:Sign in;txt:or;gbtn:Continue with Google;txt:No account? Create one")),
    ("auth-email-login", ("auth-email-register", "Email registration", "brand", None,
     "ab:Create account|Free · no card needed|✕;field:Your name|Kumar Swamy;field:Email|kumar.swamy@gmail.com;field:Password|••••••••••   👁;txt:Strong password · 8+ characters with a number;tg:I agree to the Terms and Privacy Policy||on;btn:Create account;txt:or;gbtn:Sign up with Google")),
    ("auth-email-register", ("auth-email-verify", "Verify email (when required by app config)", "brand", None,
     "sp:60;empty:✉|Check your inbox|We sent a verification link to kumar.swamy@gmail.com;btn:Open mail app;btn2:Resend link in 0:45;txt:Wrong email? Change it;note:You can start setting up your shop now. Syncing to the cloud starts after you verify.")),
    ("auth-email-verify", ("auth-forgot-password", "Forgot password", "brand", None,
     "ab:Reset password|We'll email you a reset link|✕;field:Email|kumar.swamy@gmail.com;btn:Send reset link;note:Signed up with Google or phone? Use that method instead. There is no password to reset.;txt:Back to sign in")),
    ("auth-forgot-password", ("auth-google", "Google account chooser (system sheet)", "brand", None,
     "sp:40;gbtn:Choose an account;txt:to continue to Apoorva;rows:Kumar Swamy|kumar.swamy@gmail.com|›~Sri Lakshmi Stores|srilakshmi.stores@gmail.com|›~Use another account||›;note:Apoorva gets only your name, email and profile photo.")),
    ("auth-google", ("auth-link-accounts", "Same email already registered: link instead of duplicating", "brand", None,
     "ab:Link your accounts||✕;empty:⇄|Account already exists|kumar.swamy@gmail.com is registered with email and password.;field:Password|••••••••••;btn:Link Google & sign in;btn2:Use a different Google account;note:After linking you can sign in with either method. Your shop data stays the same.")),
    ("settings-account", ("settings-signin-methods", "Sign-in methods linked to this account", "brand", 4,
     "ab:Sign-in methods|At least one must stay linked;rows:Phone|+91 98480 12345|Linked=ok~Google|kumar.swamy@gmail.com|Linked=ok~Email & password|Not added|+;btn2:Change password;note:Methods turned off by Apoorva are hidden here. If your only method is turned off you will be asked to link another one.")),
    ("platform-flags", ("platform-auth-config", "App-level sign-in configuration", "brand", 4,
     "ab:Sign-in methods|App level · all organisations;tg:Phone OTP|India +91 · SMS cost ₹0.12 each|on~Email & password|Sign in and register|on~Google|Android + iOS|on~Apple|iOS · must be on before App Store release|off~Email verification required|Before cloud sync|on~New registrations|Turn off to pause sign-ups|on;note:At least one method must stay on. Changes apply on the next app open. Signed-in users stay signed in.")),
]


def ordered():
    out, pending = [], list(EXTRA)

    def add(s):
        out.append(s)
        for p in [p for p in pending if p[0] == s[0]]:
            pending.remove(p)
            add(p[1])

    for s in SCREENS:
        add(s)
    assert not pending, [p[0] for p in pending]
    return out


CSS = """
*{box-sizing:border-box;margin:0;padding:0}
body{width:%dpx;height:%dpx;background:#ECEEF2;font-family:-apple-system,'SF Pro Text',Inter,system-ui,sans-serif;-webkit-font-smoothing:antialiased}
.top{display:flex;align-items:center;gap:12px;padding:20px 34px 4px;color:#111827}
.top h1{font-size:19px;font-weight:700;letter-spacing:-.01em}.top span{font-size:13px;color:#6B7280;flex:1}
.top em{font-style:normal;font-size:11px;font-weight:600;padding:5px 10px;border-radius:99px;background:#fff;color:#374151;border:1px solid #E5E7EB}
.row{display:flex;gap:40px;justify-content:center;padding-top:10px}.col{display:flex;flex-direction:column;align-items:center;gap:8px}
.lb{font-size:10.5px;letter-spacing:.14em;text-transform:uppercase;color:#6B7280;font-weight:600}
.ph{width:360px;height:770px;border-radius:46px;border:7px solid #0B0B0D;background:var(--bg);color:var(--tx);position:relative;overflow:hidden;box-shadow:0 20px 44px rgba(17,24,39,.16);--soft:color-mix(in srgb,var(--a) 13%%,transparent)}
.sb{display:flex;justify-content:space-between;padding:12px 26px 6px;font-size:12px;font-weight:600}
.bd{padding:2px 16px 0;display:flex;flex-direction:column;gap:10px}
.ab{display:flex;justify-content:space-between;align-items:center;padding:2px 2px 2px}.ab h2{font-size:22px;font-weight:700;letter-spacing:-.02em}.ab small{display:block;font-size:12px;color:var(--mu);margin-top:1px}
.ic{width:34px;height:34px;border-radius:12px;background:var(--sf);border:1px solid var(--bd);display:grid;place-items:center;font-size:15px;color:var(--mu)}
.cd{background:var(--sf);border:1px solid var(--bd);border-radius:16px;overflow:hidden}
.r{display:flex;align-items:center;gap:10px;padding:10px 12px;border-top:1px solid var(--bd)}.r:first-child{border-top:0}
.av{width:34px;height:34px;border-radius:11px;background:var(--soft);color:var(--a);display:grid;place-items:center;font-weight:700;font-size:13px;flex:none}
.t{flex:1;min-width:0}.t b{display:block;font-size:13.5px;font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.t i{display:block;font-style:normal;font-size:11.5px;color:var(--mu);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.v{text-align:right;font-size:13.5px;font-weight:650;white-space:nowrap}.v small{display:block}
.bg{display:inline-block;font-size:10px;font-weight:600;padding:2px 7px;border-radius:99px;margin-top:3px;background:var(--soft);color:var(--a)}
.bg.ok{color:var(--ok);background:color-mix(in srgb,var(--ok) 13%%,transparent)}.bg.er{color:var(--er);background:color-mix(in srgb,var(--er) 13%%,transparent)}.bg.wn{color:var(--wn);background:color-mix(in srgb,var(--wn) 14%%,transparent)}
.plus{width:28px;height:28px;border-radius:9px;background:var(--a);color:var(--on);display:grid;place-items:center;font-weight:700}
.se{background:var(--sf);border:1px solid var(--bd);border-radius:14px;padding:11px 14px;font-size:13px;color:var(--mu)}
.chs{display:flex;gap:6px;overflow:hidden}.chs b{font-weight:550;font-size:12px;padding:7px 12px;border-radius:99px;background:var(--sf);border:1px solid var(--bd);white-space:nowrap}
.chs b.on,.sg b.on{background:var(--a);color:var(--on);border-color:var(--a)}
.sg{display:flex;background:var(--sf);border:1px solid var(--bd);border-radius:12px;padding:3px}.sg b{flex:1;text-align:center;font-size:12px;font-weight:550;padding:7px 4px;border-radius:9px;color:var(--mu);white-space:nowrap}
.kp{display:grid;grid-template-columns:1fr 1fr;gap:10px}.k{background:var(--sf);border:1px solid var(--bd);border-radius:16px;padding:12px 13px}
.k i{font-style:normal;font-size:11px;color:var(--mu)}.k b{display:block;font-size:19px;font-weight:700;margin-top:3px;letter-spacing:-.01em}.k em{font-style:normal;font-size:11px;color:var(--a);font-weight:550}
.k.h{background:var(--a);border-color:var(--a);color:var(--on)}.k.h i,.k.h em{color:var(--on);opacity:.85}
.sc{display:flex;justify-content:space-between;font-size:13px;font-weight:650;margin-top:2px}.sc a{color:var(--a);font-weight:550}
.gr{display:grid;grid-template-columns:repeat(3,1fr);gap:8px}.g2{grid-template-columns:1fr 1fr}
.tl{background:var(--sf);border:1px solid var(--bd);border-radius:14px;padding:7px;position:relative}
.im{height:58px;border-radius:10px;background:radial-gradient(circle at 70%% 30%%,color-mix(in srgb,var(--a) 38%%,transparent),var(--soft) 60%%);margin-bottom:6px}
.g2 .im{height:104px;background:radial-gradient(circle at 50%% 45%%,transparent 22%%,color-mix(in srgb,var(--a) 45%%,transparent) 23%%,color-mix(in srgb,var(--a) 45%%,transparent) 27%%,transparent 28%%),linear-gradient(160deg,var(--soft),color-mix(in srgb,var(--a) 22%%,transparent))}
.big .im{height:150px}
.tl b{font-size:11.5px;font-weight:600;display:block;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.tl i{font-style:normal;font-size:11px;color:var(--mu)}
.q{position:absolute;top:4px;right:4px;min-width:20px;height:20px;border-radius:10px;background:var(--a);color:var(--on);font-size:11px;font-weight:700;display:grid;place-items:center}
.bt{background:var(--a);color:var(--on);border-radius:14px;padding:13px;text-align:center;font-weight:650;font-size:14px}.bt.o{background:transparent;color:var(--tx);border:1px solid var(--bd)}
.fd{background:var(--sf);border:1px solid var(--bd);border-radius:12px;padding:8px 12px}.fd i{font-size:10.5px;color:var(--mu);font-style:normal;display:block}.fd b{font-size:14px;font-weight:550}
.sw{width:38px;height:22px;border-radius:99px;background:var(--bd);position:relative;flex:none}.sw::after{content:"";position:absolute;width:18px;height:18px;border-radius:50%%;background:#fff;top:2px;left:2px}.sw.on{background:var(--a)}.sw.on::after{left:18px}.sw.lk{opacity:.4}
.nt{background:var(--soft);border-radius:12px;padding:10px 12px;font-size:12px;line-height:1.45;display:flex;gap:8px}.nt::before{content:"i";flex:none;width:16px;height:16px;border-radius:50%%;background:var(--a);color:var(--on);font-size:10px;font-weight:700;display:grid;place-items:center;font-style:italic}
.tx{text-align:center;font-size:12px;color:var(--mu)}
.ch2{background:var(--sf);border:1px solid var(--bd);border-radius:16px;padding:12px}.ch2 h3{font-size:12px;color:var(--mu);font-weight:550}.ch2 h4{font-size:20px;font-weight:700;margin-top:2px}.ch2 h4 em{font-size:11px;color:var(--a);font-style:normal;margin-left:6px}
.bs{display:flex;align-items:flex-end;gap:8px;height:96px;margin-top:10px}.bs div{flex:1;display:flex;flex-direction:column;align-items:center;gap:4px;font-size:10px;color:var(--mu);justify-content:flex-end;height:100%%}.bs s{display:block;width:100%%;border-radius:6px;background:color-mix(in srgb,var(--a) 30%%,transparent)}.bs s.m{background:var(--a)}
.spl{display:flex;height:10px;border-radius:99px;overflow:hidden;gap:2px;margin:8px 0}.lg{display:flex;gap:14px;font-size:11px;color:var(--mu)}.lg b{color:var(--tx)}
.mx{display:grid;grid-template-columns:1.8fr repeat(4,1fr);font-size:11.5px}.mx>*{padding:8px 6px;border-top:1px solid var(--bd);text-align:center}.mx>.h{color:var(--mu);font-weight:600;border-top:0}.mx>.l{text-align:left;font-weight:550}.mx .y{color:var(--a);font-weight:800}.mx .n{color:var(--mu)}
.sl{display:flex;gap:10px}.tm{width:42px;font-size:11.5px;color:var(--mu);padding-top:10px;flex:none}.ev{flex:1;background:var(--soft);border-left:3px solid var(--a);border-radius:12px;padding:9px 11px}.ev b{font-size:13px;font-weight:600;display:block}.ev i{font-size:11.5px;color:var(--mu);font-style:normal}.ev.fr{background:transparent;border:1.5px dashed var(--bd);color:var(--mu);font-size:12px}
.hr{display:flex;flex-direction:column;align-items:center;gap:4px;padding:14px 0 6px}.hr b{font-size:38px;font-weight:750;letter-spacing:-.02em}.hr i{font-style:normal;font-size:12.5px;color:var(--mu)}
.hk{width:54px;height:54px;border-radius:50%%;background:var(--soft);color:var(--a);display:grid;place-items:center;font-size:24px;font-weight:700;margin-bottom:6px}
.pd{display:grid;grid-template-columns:repeat(3,1fr);gap:6px}.pd b{height:44px;border-radius:12px;background:var(--sf);border:1px solid var(--bd);display:grid;place-items:center;font-size:18px;font-weight:550}
.sn{height:220px;border-radius:20px;background:#0B0D10;position:relative;overflow:hidden}.sn .f{position:absolute;inset:46px 54px;border:2px solid var(--a);border-radius:16px;background:repeating-linear-gradient(90deg,rgba(255,255,255,.75) 0 2px,transparent 2px 5px,rgba(255,255,255,.75) 5px 6px,transparent 6px 10px);background-size:100%% 50%%;background-position:center;background-repeat:no-repeat;opacity:.9}.sn .ln{position:absolute;left:62px;right:62px;top:50%%;height:2px;background:var(--a);box-shadow:0 0 14px var(--a)}
.st{display:flex;gap:6px}.st s{flex:1;height:4px;border-radius:9px;background:var(--bd)}.st s.on{background:var(--a)}
.swr{display:flex;flex-wrap:wrap;gap:14px;padding:4px 2px}.swi{display:flex;flex-direction:column;align-items:center;gap:5px;font-size:10.5px;color:var(--mu)}.swi span{width:38px;height:38px;border-radius:50%%;display:block}.swi.on span{outline:2px solid var(--tx);outline-offset:3px}.swi.on{color:var(--tx);font-weight:600}
.dot{width:34px;height:34px;border-radius:11px;flex:none}.rd{width:18px;height:18px;border-radius:50%%;border:2px solid var(--bd);flex:none}.rd.on{border:6px solid var(--a)}
.lo{display:flex;flex-direction:column;align-items:center;gap:10px;margin-top:230px}.mk{width:78px;height:78px;border-radius:24px;background:linear-gradient(140deg,var(--a),color-mix(in srgb,var(--a) 55%%,#000));color:#fff;display:grid;place-items:center;font-size:36px;font-weight:800}
.lo h1{font-size:28px;font-weight:750;letter-spacing:-.02em}.lo p{color:var(--mu);font-size:13px}
.cb{position:absolute;left:12px;right:12px;bottom:20px;background:var(--tx);color:var(--bg);border-radius:18px;padding:10px 10px 10px 16px;display:flex;align-items:center;gap:10px;box-shadow:0 10px 24px rgba(0,0,0,.18)}
.ph.tb .cb{bottom:84px}.cb .t i{color:var(--bg);opacity:.7}.cb .t b{font-size:16px}.cb .go{background:var(--a);color:var(--on);border-radius:12px;padding:10px 18px;font-weight:700;font-size:13.5px}
.tabs{position:absolute;bottom:0;left:0;right:0;height:72px;background:var(--sf);border-top:1px solid var(--bd);display:flex;justify-content:space-around;align-items:flex-start;padding-top:9px}
.tabs div{display:flex;flex-direction:column;align-items:center;gap:3px;font-size:10px;color:var(--mu);width:60px}.tabs div b{font-size:18px;line-height:22px;font-weight:500}.tabs .on{color:var(--a);font-weight:600}
.tabs .nb b{width:42px;height:42px;margin-top:-4px;border-radius:14px;background:var(--a);color:var(--on);display:grid;place-items:center;font-size:24px;line-height:1}
.em{display:flex;flex-direction:column;align-items:center;gap:6px;text-align:center;padding:16px 10px}.em b{font-size:18px;font-weight:700}.em i{font-style:normal;font-size:12.5px;color:var(--mu);line-height:1.4}
.rcp{background:#fff;color:#111;font-family:Menlo,monospace;font-size:10.5px;line-height:1.55;padding:14px 16px;margin:0 22px;border-radius:4px;box-shadow:0 6px 18px rgba(0,0,0,.18)}.rcp h5{text-align:center;font-size:12.5px}.rcp p{text-align:center;color:#555}.rcp div{display:flex;justify-content:space-between}.rcp hr{border:0;border-top:1px dashed #999;margin:5px 0}
.qr{background:#fff;border-radius:18px;padding:14px;display:flex;flex-direction:column;align-items:center;gap:6px;margin:0 60px}.qr i{font-style:normal;font-size:11px;color:#555}
""" % (W, H)


def e(s):
    return html.escape(s)


def sel(items):
    return [(x.rstrip("*"), x.endswith("*")) for x in items.split(",")]


def badge(text):
    if "=" in text:
        text, cls = text.split("=")
        return f'<span class="bg {cls}">{e(text)}</span>'
    cls = {"Paid": "ok", "Live": "ok", "Due": "er", "Out": "er", "Cancelled": "er",
           "Low": "wn", "Pending": "wn", "Held": "wn"}.get(text, "")
    return f'<span class="bg {cls}">{e(text)}</span>' if text else ""


def row(lead, title, sub, right):
    return f'<div class="r">{lead}<div class="t"><b>{e(title)}</b><i>{e(sub)}</i></div>{right}</div>'


def comp(kind, arg):
    E = [x.split("|") + [""] * 4 for x in arg.split("~")] if arg else []
    f = E[0] if E else [""] * 4
    if kind == "ab":
        icon = f'<div class="ic">{e(f[2])}</div>' if f[2] else ""
        return f'<div class="ab"><div><h2>{e(f[0])}</h2><small>{e(f[1])}</small></div>{icon}</div>'
    if kind == "logo":
        return f'<div class="lo"><div class="mk">A</div><h1>{e(f[0])}</h1><p>{e(f[1])}</p></div>'
    if kind == "steps":
        n, of = int(f[0]), int(f[1])
        return '<div class="st">' + "".join(f'<s class="{"on" if i < n else ""}"></s>' for i in range(of)) + "</div>"
    if kind == "search":
        return f'<div class="se">⌕&nbsp; {e(arg)}</div>'
    if kind == "chips":
        return '<div class="chs">' + "".join(f'<b class="{"on" if o else ""}">{e(t)}</b>' for t, o in sel(arg)) + "</div>"
    if kind == "seg":
        return '<div class="sg">' + "".join(f'<b class="{"on" if o else ""}">{e(t)}</b>' for t, o in sel(arg)) + "</div>"
    if kind == "sec":
        return f'<div class="sc"><span>{e(f[0])}</span><a>{e(f[1])}</a></div>'
    if kind == "kpis":
        return '<div class="kp">' + "".join(
            f'<div class="k{" h" if i == 0 else ""}"><i>{e(x[0])}</i><b>{e(x[1])}</b><em>{e(x[2])}</em></div>'
            for i, x in enumerate(E)) + "</div>"
    if kind == "rows":
        out = []
        for t, s, v, b, *_ in E:
            if v == "+":
                right = '<div class="plus">+</div>'
            else:
                right = f'<div class="v">{e(v)}<small>{badge(b)}</small></div>'
            out.append(row(f'<div class="av">{e(t[:1])}</div>', t, s, right))
        return '<div class="cd">' + "".join(out) + "</div>"
    if kind == "pick":
        return '<div class="cd">' + "".join(
            row(f'<div class="dot" style="background:{x[2]}"></div>', x[0], x[1],
                f'<div class="rd{" on" if x[3] == "*" else ""}"></div>') for x in E) + "</div>"
    if kind == "tg":
        return '<div class="cd">' + "".join(
            row("", x[0], x[1] + (" · locked" if x[2] == "lock" else ""),
                f'<div class="sw{" on" if x[2] in ("on", "lock") else ""}{" lk" if x[2] == "lock" else ""}"></div>')
            for x in E) + "</div>"
    if kind in ("grid", "grid2", "gridbig"):
        cls = {"grid": "gr", "grid2": "gr g2", "gridbig": "gr g2 big"}[kind]
        style = ' style="grid-template-columns:1fr"' if kind == "gridbig" else ""
        tiles = "".join(
            f'<div class="tl"><div class="im"></div><b>{e(x[0])}</b><i>{e(x[1])}</i>'
            + (f'<span class="q">{e(x[2])}</span>' if x[2] else "") + "</div>" for x in E)
        return f'<div class="{cls}"{style}>{tiles}</div>'
    if kind == "kv":
        out = "".join(
            f'<div class="r" style="{"font-weight:700;font-size:16px" if i == len(E) - 1 and len(E) > 2 else "font-size:13px"}">'
            f'<div class="t" style="font-weight:inherit">{e(x[0])}</div><div class="v" style="font-size:inherit">{e(x[1])}</div></div>'
            for i, x in enumerate(E))
        return f'<div class="cd">{out}</div>'
    if kind == "gbtn":
        g = ('<b style="font-size:17px;font-weight:800;background:conic-gradient(#EA4335 0 25%,#FBBC05 0 50%,'
             '#34A853 0 75%,#4285F4 0);-webkit-background-clip:text;color:transparent">G</b>')
        return f'<div class="bt o" style="display:flex;gap:10px;justify-content:center;align-items:center">{g}{e(arg)}</div>'
    if kind in ("btn", "btn2"):
        return f'<div class="bt{" o" if kind == "btn2" else ""}">{e(arg)}</div>'
    if kind == "field":
        return f'<div class="fd"><i>{e(f[0])}</i><b>{e(f[1])}</b></div>'
    if kind == "note":
        return f'<div class="nt">{e(arg)}</div>'
    if kind == "txt":
        return f'<div class="tx">{e(arg)}</div>'
    if kind == "sp":
        return f'<div style="height:{int(arg)}px"></div>'
    if kind == "hero":
        icon = f'<div class="hk">{e(f[2])}</div>' if f[2] else ""
        return f'<div class="hr">{icon}<b>{e(f[0])}</b><i>{e(f[1])}</i></div>'
    if kind == "pad":
        return '<div class="pd">' + "".join(f"<b>{k}</b>" for k in "123456789·0⌫") + "</div>"
    if kind == "scan":
        return '<div class="sn"><div class="f"></div><div class="ln"></div></div>'
    if kind == "swatch":
        return '<div class="swr">' + "".join(
            f'<div class="swi{" on" if x[2] == "*" else ""}"><span style="background:{x[1]}"></span>{e(x[0])}</div>'
            for x in E) + "</div>"
    if kind == "bars":
        top = max(int(x[1]) for x in E[1:])
        bars = "".join(f'<div><s class="{"m" if int(x[1]) == top else ""}" style="height:{int(x[1]) * .8}%"></s>{e(x[0])}</div>'
                       for x in E[1:])
        return f'<div class="ch2"><h3>{e(f[0])}</h3><div class="bs">{bars}</div></div>'
    if kind == "line":
        vals = [float(v) for v in E[1][0].split(",")]
        lo, hi = min(vals), max(vals)
        pts = [(i * 296 / (len(vals) - 1), 76 - (v - lo) / (hi - lo) * 66) for i, v in enumerate(vals)]
        poly = " ".join(f"{x:.1f},{y:.1f}" for x, y in pts)
        svg = (f'<svg width="296" height="80" style="margin-top:8px;display:block">'
               f'<polygon points="0,80 {poly} 296,80" style="fill:var(--soft)"/>'
               f'<polyline points="{poly}" style="fill:none;stroke:var(--a);stroke-width:2.5;stroke-linejoin:round"/></svg>')
        return f'<div class="ch2"><h3>{e(f[0])}</h3><h4>{e(f[1])}<em>{e(f[2])}</em></h4>{svg}</div>'
    if kind == "split":
        ops = [1, .55, .28, .15]
        segs = "".join(f'<div style="flex:{x[1]};background:var(--a);opacity:{ops[i]}"></div>' for i, x in enumerate(E))
        leg = "".join(f'<span><b>{e(x[0])}</b> {e(x[1])}%</span>' for x in E)
        return f'<div class="ch2"><h3>{e(E[0][2] or "Payment modes")}</h3><div class="spl">{segs}</div><div class="lg">{leg}</div></div>'
    if kind == "mx":
        n = len([h for h in f if h])
        cells = "".join(f'<div class="h{" l" if i == 0 else ""}">{e(h)}</div>' for i, h in enumerate(f[:n]))
        for x in E[1:]:
            cells += f'<div class="l">{e(x[0])}</div>' + "".join(
                '<div class="y">✓</div>' if v == "1" else '<div class="n">—</div>' for v in x[1:n])
        cols = f"grid-template-columns:1.8fr repeat({n - 1},1fr)"
        return f'<div class="cd"><div class="mx" style="{cols}">{cells}</div></div>'
    if kind == "slots":
        out = ""
        for tm, t, s, *_ in E:
            ev = f'<div class="ev"><b>{e(t)}</b><i>{e(s)}</i></div>' if t else '<div class="ev fr">Free slot · tap to book</div>'
            out += f'<div class="sl"><div class="tm">{e(tm)}</div>{ev}</div>'
        return f'<div style="display:flex;flex-direction:column;gap:8px">{out}</div>'
    if kind == "cart":
        return (f'<div class="cb"><div class="t"><i>{e(f[0])}</i><b>{e(f[1])}</b></div>'
                f'<div class="go">{e(f[2])} →</div></div>')
    if kind == "empty":
        return f'<div class="em"><div class="hk">{e(f[0])}</div><b>{e(f[1])}</b><i>{e(f[2])}</i></div>'
    if kind == "receipt":
        out = ""
        for i, x in enumerate(E):
            if x[0] == "—":
                out += "<hr>"
            elif i == 0:
                out += f"<h5>{e(x[0])}</h5><p>{e(x[1])}</p>"
            elif not x[1]:
                out += f"<p>{e(x[0])}</p>"
            else:
                out += f"<div><span>{e(x[0])}</span><span>{e(x[1])}</span></div>"
        return f'<div class="rcp">{out}</div>'
    if kind == "qr":
        n, s = 25, 8
        rnd = random.Random(arg)
        finder = ((0, 0), (n - 7, 0), (0, n - 7))
        parts = [f'<rect x="{x * s}" y="{y * s}" width="{s}" height="{s}"/>' for y in range(n) for x in range(n)
                 if not any(fx - 1 <= x < fx + 8 and fy - 1 <= y < fy + 8 for fx, fy in finder) and rnd.random() < .5]
        for fx, fy in finder:
            parts.append(f'<rect x="{fx * s}" y="{fy * s}" width="{7 * s}" height="{7 * s}"/>'
                         f'<rect x="{(fx + 1) * s}" y="{(fy + 1) * s}" width="{5 * s}" height="{5 * s}" fill="#fff"/>'
                         f'<rect x="{(fx + 2) * s}" y="{(fy + 2) * s}" width="{3 * s}" height="{3 * s}"/>')
        return (f'<div class="qr"><svg viewBox="0 0 {n * s} {n * s}" width="168" height="168" fill="#111">'
                f'{"".join(parts)}</svg><i>{e(arg)}</i></div>')
    raise ValueError(f"unknown component {kind}")


def phone(spec, theme, mode, tab):
    t = THEMES[theme]
    v = {**(LIGHT if mode == "light" else DARK), **t.get(mode, {})}
    v["a"] = t["a"][0 if mode == "light" else 1]
    style = ";".join(f"--{k}:{val}" for k, val in v.items())
    body, overlay = "", ""
    for c in spec.split(";"):
        kind, _, arg = c.partition(":")
        h = comp(kind, arg)
        if kind == "cart":
            overlay += h
        else:
            body += h
    tabs = ""
    labels = TABS_TE if tab is not None and tab >= 10 else TABS
    if tab is not None:
        tab %= 10
        tabs = '<div class="tabs">' + "".join(
            f'<div class="{"nb " if i == 2 else ""}{"on" if i == tab else ""}"><b>{g}</b>{n}</div>'
            for i, (g, n) in enumerate(labels)) + "</div>"
    cls = "ph tb" if tabs else "ph"
    return (f'<div class="col"><div class="lb">{mode}</div><div class="{cls}" style="{style}">'
            f'<div class="sb"><span>9:41</span><span>● ● ▮</span></div><div class="bd">{body}</div>{overlay}{tabs}</div></div>')


def page(n, slug, caption, theme, tab, spec):
    return (f'<!doctype html><meta charset="utf-8"><style>{CSS}</style>'
            f'<div class="top"><h1>{n:02d} · {e(slug.replace("-", " ").title())}</h1><span>{e(caption)}</span>'
            f'<em>{e(THEMES[theme]["name"])}</em></div>'
            f'<div class="row">{phone(spec, theme, "light", tab)}{phone(spec, theme, "dark", tab)}</div>')


def render(job):
    n, (slug, caption, theme, tab, spec) = job
    out = OUT / f"{n:02d}-{slug}.png"
    with tempfile.TemporaryDirectory() as tmp:
        src = pathlib.Path(tmp) / "s.html"
        src.write_text(page(n, slug, caption, theme, tab, spec), encoding="utf-8")
        subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", f"--user-data-dir={tmp}/u",
                        f"--force-device-scale-factor={SCALE}", f"--window-size={W},{H}",
                        f"--screenshot={out}", src.as_uri()], check=True, capture_output=True, timeout=90)
    Image.open(out).convert("RGB").quantize(colors=128, dither=0).save(out, optimize=True)
    return out


def index():
    lines = ["# Apoorva — Designs", "",
             "Each image shows one screen in **light (left)** and **dark (right)**. Generated by",
             "`python3 designs/_src/generate.py` (edit the one-line specs in `SCREENS` and re-run).", "",
             "| # | Screen | Theme | Shows |", "|---|--------|-------|-------|"]
    for n, (slug, caption, theme, _, _) in enumerate(ordered(), 1):
        lines.append(f"| {n:02d} | [{slug}]({n:02d}-{slug}.png) | {THEMES[theme]['name']} | {caption} |")
    (OUT / "README.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    only = set(sys.argv[1:])
    jobs = [(n, s) for n, s in enumerate(ordered(), 1) if not only or s[0] in only]
    if not only:
        for old in OUT.glob("[0-9][0-9]-*.png"):
            old.unlink()
    with ThreadPoolExecutor(6) as pool:
        files = list(pool.map(render, jobs))
    index()
    total = sum(p.stat().st_size for p in files)
    print(f"{len(files)} PNGs, {total / 1024:.0f} KB total, max {max(p.stat().st_size for p in files) / 1024:.0f} KB")
