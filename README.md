# Perfect Timing

Order-ahead breakfast & coffee site built for easy prep (microwave / slow cooker / air fryer).

**Live domain:** perfecttiming.space
**Admin dashboard:** perfecttiming.space/admin (not linked publicly)

---

## Quick start

**🚨 Before going live, follow [SETUP.md](./SETUP.md)** — you need to set up Supabase and Formspree first. The site won't accept orders until those are configured.

---

## Files

```
perfect-timing-site/
├── index.html          ← Customer ordering page (step-by-step flow + sticky cart)
├── menu.html           ← Public view-only menu (no ordering)
├── admin/
│   └── index.html      ← Admin dashboard with schedule (login required)
├── robots.txt          ← Blocks /admin from search engines
├── vercel.json         ← Vercel config (clean URLs)
├── SETUP.md            ← 👉 READ THIS FIRST — full setup steps
└── README.md           ← You are here
```

---

## How it works

### Customer ordering (`index.html`)
- Hard Hat theme — industrial, blue-collar aesthetic
- **Step-by-step flow:** pick date → pick time slot → pick food → pick drink → submit
- Each step only unlocks when the previous is complete
- "How It Works" strip at the top tracks progress through the steps
- Sticky cart on the right (collapses to bottom on mobile)
- 30-min pickup slots, 5:00 AM – 10:00 AM
- Midnight cutoff enforced (earliest pickup = tomorrow)
- B.Y.O.C. (Bring Your Own Cup) $1.50 refill — info card in menu, checkbox on individual food items in cart
- Drinks optional (food-only orders allowed); food required only if customer wants B.Y.O.C.
- Weekly subscription opt-in (checkbox — billing not yet wired)
- On submit: saves to **Supabase database** AND triggers email via **Formspree**
- Prices are tax-inclusive (no tax line in cart)

### Menu page (`menu.html`)
- Static view-only menu
- Same Hard Hat theme
- No cart, no ordering — just browsable
- "Order Now" buttons link back to `/`

### Admin dashboard (`admin/index.html`)
- Password-protected login (Supabase Auth)
- **Schedule view** replacing the old order list:
  - **Day tab:** orders shown as colored blocks in their 30-min slot cells
  - **Week tab:** 7-day calendar showing order counts per day
  - **Month tab:** full month calendar showing order counts per day
- Click any date cell in week/month view → jumps to Day view for that date
- Click any order block → mini popup with name, phone, pickup, items, notes
- Status buttons (Pending / Prepping / Complete) change the block's color live
- Recipe panel at the bottom: searchable + filterable prep instructions for every menu item
- Not linked from customer site — admins bookmark the URL

---

## Menu

| Category | Items |
|----------|-------|
| **Drinks** | Hot Coffee ($3.25), Iced Coffee ($3.75), Hot Cocoa ($3.50) — each customizable with checkbox + counter (1–12 tbsp) for creamer, half & half, sugar, agave, honey, extra ice. Plus whipped cream on/off. |
| **Microwave** | Egg & Cheese Mug, Loaded Oatmeal Bowl, PB Banana Toast Melt |
| **Slow Cooker** | Overnight Steel-Cut Oats, Breakfast Casserole Cup, Cinnamon Roll Bake |
| **Air Fryer** | Bacon & Egg Bites, Breakfast Potatoes, French Toast Sticks |
| **Add-Ons** | B.Y.O.C. — $1.50 refill attached to individual food items via checkbox in the cart |

All items designed for single-person prep with home appliances. Full recipes live in the admin dashboard.

---

## Status colors in the schedule

| Status | Color | What it means |
|--------|-------|---------------|
| **Pending** | Yellow | Order placed, not yet started |
| **Prepping** | Blue | Currently being prepared |
| **Complete** | Green | Handed off to customer |

Click an order block → status buttons in the popup → tap to change. Updates live.

---

## Changing the menu

Menu data lives in JavaScript arrays near the bottom of `index.html` (`const drinks`, `const foods`, `const addons`).

**If you change items, you MUST also update:**
1. The matching arrays at the top of `admin/index.html` (where the recipe panel reads from)
2. The hardcoded items in `menu.html` (view-only page)

Each item needs:
```js
{ code: 'M-04', name: 'Display Name', category: 'microwave',
  desc: 'Short appetizing description for customers.',
  price: 5.50,
  recipe: 'Step-by-step prep instructions for staff.' }
```

`category` must be one of: `drink`, `microwave`, `slow-cooker`, `air-fryer`, `addon`.

---

## Tech stack (for the curious)

- **Static HTML/CSS/JS** — no build step, no framework, no npm
- **Supabase** — Postgres database + auth, free tier
- **Formspree** — email form handler, free tier (50 orders/month, upgrade if you exceed)
- **Vercel** — static hosting, free tier
- **GitHub** — source control

Total monthly cost: **$0** at expected volume. Formspree jumps to $10/mo if you exceed 50 orders/month; Supabase stays free up to 500MB database (~1 million orders on free tier).

---

## Placeholders still in the site

Search `index.html`, `menu.html`, and `admin/index.html` for `[` brackets and swap in real info before going live:

- `[TAGLINE]` — Footer tagline
- `[STREET ADDRESS]`, `[CITY, STATE ZIP]` — Location
- `[PHONE]` — Footer + social
- `[EMAIL]` — Footer contact
- `[WEEKEND HOURS]` — Saturday/Sunday hours
- `[INSTAGRAM URL]`, `[FACEBOOK URL]`, `[TIKTOK URL]` — Social links

---

## Known limits / what's not built yet

- **Subscription billing isn't wired.** The opt-in checkbox records the preference and flags the order, but there's no Stripe integration yet. You'll need to manually charge / arrange payment for subscribers for now. When you're ready for automated billing, we'll wire Stripe in.
- **No refund/cancel flow.** If a customer wants to cancel, they call you. You can mark the order as cancelled by setting its status manually in Supabase.
- **No SMS alerts.** Email + dashboard only for now. Adding Twilio SMS alongside Formspree is ~15 minutes of work if you want it later.
- **Menu duplicated** across `index.html`, `admin/index.html`, and `menu.html`. If this gets annoying, we can extract to a shared `menu-data.js` later.
