# Inpenso — Production Launch Checklist

Use this as the source of truth to ship. Check items off in order when possible; blockers are marked **BLOCKER**.

---

## 0. Current code status (baseline)

Already in the app:
- [x] Tide Ledger redesign + Quick Add + widgets
- [x] Pro paywall UI (monthly / yearly / 60% special)
- [x] Free-tier gates (OCR 5/mo, 2 category budgets, 3 recurring)
- [x] Face ID lock, reminders, receipt OCR, recurring, goals, accounts, etc.
- [x] StoreKit 2 purchase/restore scaffolding
- [x] Product IDs wired in code:
  - `com.dragomir.Inpenso.pro.monthly`
  - `com.dragomir.Inpenso.pro.yearly`
  - `com.dragomir.Inpenso.pro.yearly.special`
- [x] Camera / Photos / Face ID / Live Activities Info.plist keys
- [x] App Group for widgets

Not production-ready yet without the work below.

---

## 1. App Store Connect — account & app **BLOCKER**

- [ ] Confirm Apple Developer Program membership is active
- [ ] Confirm bundle ID `com.dragomir.Inpenso` exists and matches Xcode
- [ ] Create/verify App record in App Store Connect (name, primary language, category: Finance)
- [ ] Confirm team ID / signing (`DEVELOPMENT_TEAM`) matches the shipping account
- [ ] Create widget extension App ID: `com.dragomir.Inpenso.iExpenseWidgetExtension`
- [ ] Enable capabilities on App IDs:
  - [ ] App Groups (`group.com.vintuss.Inpenso`) — confirm group ID is final
  - [ ] iCloud (Key-value storage at minimum; CloudKit if you upgrade sync later)
  - [ ] Push Notifications (only if you add remote push; local reminders don’t need this)
- [ ] Register devices for TestFlight internal testing
- [ ] Decide final marketing version (currently `1.0.7` — bump to `1.1.0` or `2.0.0` for redesign release)

---

## 2. Subscriptions (StoreKit / ASC) **BLOCKER**

### 2.1 Agreements & tax
- [ ] Complete **Paid Applications Agreement** in App Store Connect
- [ ] Complete banking + tax forms (no paid subs without this)
- [ ] Confirm account can sell auto-renewable subscriptions in target countries

### 2.2 Subscription group
- [ ] Create subscription group, e.g. **Inpenso Pro**
- [ ] Create auto-renewable products (exact IDs must match code):

| Product ID | Type | Suggested price | Notes |
|---|---|---|---|
| `com.dragomir.Inpenso.pro.monthly` | 1 month | **$2.99** | Standard monthly |
| `com.dragomir.Inpenso.pro.yearly` | 1 year | **$14.99** | Show ~~$29.99~~ in UI as marketing |
| `com.dragomir.Inpenso.pro.yearly.special` | 1 year | **$11.99** | 60% offer SKU (or use offer codes / intro offer instead — decide) |

- [ ] Decide special-offer strategy (pick one):
  - [ ] **A.** Separate SKU `…yearly.special` at $11.99 (current code path)
  - [ ] **B.** Single yearly SKU + App Store promotional / win-back / offer codes (cleaner long-term)
- [ ] Set subscription duration, free trial (optional: 7-day trial on yearly)
- [ ] Localization: display names + descriptions for all locales you ship
- [ ] Review screenshot / review notes for subscription value proposition
- [ ] Submit subscription products for Apple review (with first binary that includes them)

### 2.3 StoreKit hardening in code **BLOCKER**
- [ ] Remove or strictly gate `#if DEBUG` “purchase unlocks Pro without StoreKit” path for Release
- [ ] Remove Settings **Debug: remove Pro** from shipping builds
- [ ] Prefer StoreKit `Product.displayPrice` over hardcoded `$` strings when products load
- [ ] Handle `.pending` (Ask to Buy) with clear UI
- [ ] Verify restore purchases on a real device with a Sandbox Apple ID
- [ ] Verify entitlement after renew / expire / refund (Sandbox interrupted purchases)
- [ ] Add StoreKit Configuration file for local Xcode testing (`.storekit`)
- [ ] Optional: App Store Server Notifications v2 endpoint for expire/refund (recommended for Pro gates)

### 2.4 Legal copy for subscriptions **BLOCKER**
- [ ] Paywall must show (already partially there — verify Apple’s checklist):
  - [ ] Title/length of subscription
  - [ ] Price and price per period
  - [ ] Auto-renew disclosure
  - [ ] Link to **Terms of Use (EULA)**
  - [ ] Link to **Privacy Policy**
  - [ ] “Cancel anytime in Apple ID settings”
- [ ] Add tappable Terms + Privacy links on paywall (currently legal text only — **add URLs**)
- [ ] If using custom EULA, host it publicly; else use Apple Standard EULA + link in ASC

---

## 3. Legal, privacy, compliance **BLOCKER**

- [ ] Host Privacy Policy on a public HTTPS URL (GitHub Pages / site)
- [ ] Host Terms of Use on a public HTTPS URL
- [ ] Update `PRIVACY.md` date + subscription section (billing via Apple, restore, no ads)
- [ ] Add Privacy Policy URL in App Store Connect
- [ ] Complete App Privacy “nutrition label” in ASC:
  - [ ] Financial Info (on-device)
  - [ ] Photos / Camera (optional, user-provided)
  - [ ] Purchases
  - [ ] Declare **no tracking** if true (recommended)
- [ ] Export compliance: set encryption answers (standard HTTPS / iOS crypto usually “exempt”)
- [ ] Age rating questionnaire (finance apps — answer accurately)
- [ ] Content rights / trademarks for name “Inpenso”
- [ ] If iCloud sync ships: disclose sync in privacy policy clearly

---

## 4. Entitlements, signing, capabilities

- [ ] Confirm Release entitlements match App ID capabilities
- [ ] App Group ID final and identical in app + widget
- [ ] iCloud KVS entitlement enabled for Pro sync (already in entitlements — verify ASC capability)
- [ ] Live Activities: capability / Info.plist `NSSupportsLiveActivities` (present) — test on physical device
- [ ] Alternate app icons: add real `AppIconTide` / `AppIconCopper` / `AppIconInk` assets **or** hide icon picker until assets exist
- [ ] Archive with Release configuration; no development-only flags

---

## 5. Product QA — functional (device + TestFlight)

### Core
- [ ] Add / edit / delete expense & income
- [ ] Categories (custom, hide, reorder)
- [ ] Home Today / Week / Month totals correct
- [ ] Analytics / budget / insights
- [ ] Quick Add + templates
- [ ] Widgets small/medium/large + Add spend intent
- [ ] Siri / Shortcuts add expense (if kept)

### Pro gates
- [ ] Free: OCR limited to 5 / month (counter resets monthly)
- [ ] Free: max 2 category budgets, max 3 recurring
- [ ] Pro unlocks unlimited OCR / budgets / recurring calendar
- [ ] Paywall purchase (Sandbox) → `isPro == true` immediately
- [ ] Restore on second device / reinstall
- [ ] Special offer appears only for non-Pro, respects cooldown
- [ ] Home Upgrade CTA hidden when Pro

### Premium features
- [ ] Goals & envelopes CRUD
- [ ] Accounts / net worth math (credit cards as liabilities)
- [ ] Merchant rules auto-categorize on Quick Add
- [ ] Household invite code copy / members / shared categories
- [ ] Themes switch (Pro packs locked)
- [ ] CSV + OFX export open share sheet with valid files
- [ ] iCloud sync: enable on device A, appear on device B (same Apple ID)
- [ ] Face ID lock on launch + return from background
- [ ] Reminder frequencies schedule correctly (check Notification Center pending)
- [ ] Live Activity / Dynamic Island “spent today” on Pro (physical device)

### UX / polish
- [ ] No overlapping FAB vs tab bar on common devices (SE / 15 / Pro Max)
- [ ] Dynamic Type / large text doesn’t break paywall / home
- [ ] Dark / light / system theme
- [ ] Empty states and error alerts readable
- [ ] No debug menus in Release

### Performance / stability
- [ ] Cold launch &lt; ~2s on mid device
- [ ] No main-thread hangs on large expense lists (1k+ items smoke test)
- [ ] Memory: receipt OCR doesn’t crash on large photos
- [ ] Crash-free on TestFlight for 48h before submit

---

## 6. Store listing assets **BLOCKER**

- [ ] App name + subtitle (≤30 chars subtitle)
- [ ] Promotional text
- [ ] Description (mention Pro features + no ads + on-device privacy)
- [ ] Keywords
- [ ] Support URL + Marketing URL
- [ ] App icon (1024×1024) matching Tide Ledger brand
- [ ] Screenshots for 6.7" and 6.1" (minimum):
  - [ ] Home (brand-first)
  - [ ] Quick Add
  - [ ] Insights / budgets
  - [ ] Receipt scan
  - [ ] Pro paywall (optional but helps review)
- [ ] Optional: iPad if you expand device family later (currently iPhone-only)
- [ ] App Review notes:
  - [ ] Sandbox test account
  - [ ] How to find paywall
  - [ ] Explain OCR is on-device
  - [ ] Explain free limits vs Pro

---

## 7. Release engineering

- [ ] Create `Release` / `Prod` checklist run before archive
- [ ] Bump `MARKETING_VERSION` + `CURRENT_PROJECT_VERSION` (build number)
- [ ] Tag git release (`v1.1.0`)
- [ ] Archive → Upload → TestFlight (Internal)
- [ ] Internal dogfood ≥ 3 days
- [ ] External TestFlight (optional) with 10–50 users
- [ ] Submit for App Review
- [ ] Prepare phased release (recommended) or manual release
- [ ] Post-release: monitor crashes (Xcode Organizer) + StoreKit issues

---

## 8. Known gaps to decide before / right after launch

Ship-without-these is possible if messaging is honest; don’t overclaim.

| Item | Risk if shipped as-is | Recommendation |
|---|---|---|
| iCloud sync = KVS only | Large datasets / conflicts / not true multi-user | Market as “basic sync” or upgrade to CloudKit before calling it multi-device Pro |
| Household ledger | Local invite code, not real sharing | Label “coming soon / on-device household setup” or finish CloudKit sharing |
| Alternate icons | Names referenced, assets may be missing | Add assets or hide until ready |
| DEBUG Pro unlock | Accidental Release leak | Must strip for prod |
| Yearly “~~$29.99~~” | Marketing reference price | Ensure ASC price + UI don’t confuse reviewers; keep disclosure clear |
| No analytics | Blind to funnels | Optional privacy-friendly analytics (TelemetryDeck / etc.) — no ads/trackers |
| No crash reporting | Hard to debug prod | Add privacy-respecting crash tool or rely on Xcode |
| Server notifications | Refunds may leave Pro active until refresh | Add ASSN v2 when backend exists |

---

## 9. Minimum “go live” path (fastest safe launch)

Do these in order:

1. [ ] ASC Paid Apps + tax/banking  
2. [ ] Create subscription group + 2–3 products matching IDs  
3. [ ] Strip DEBUG unlocks; paywall Terms/Privacy links  
4. [ ] Host Privacy + Terms URLs; ASC privacy questionnaire  
5. [ ] TestFlight Sandbox purchase + restore  
6. [ ] Screenshots + listing copy  
7. [ ] Submit binary + subscriptions together  
8. [ ] Soft-launch / phased release  

Optional but strongly recommended before calling Pro “complete”:
9. [ ] CloudKit sync (replace KVS)  
10. [ ] Real household sharing  
11. [ ] Alternate icon assets  
12. [ ] App Store Server Notifications  

---

## 10. Post-launch backlog (week 1–4)

- [ ] Track conversion: paywall view → purchase (even manual counts from ASC)
- [ ] Fix first App Review rejection items within 24–48h
- [ ] Tune special-offer frequency (too aggressive = annoyance / review risk)
- [ ] Localize paywall + onboarding (start with EN + top markets)
- [ ] Support email / FAQ for “how to cancel / restore”
- [ ] Plan 1.1: weekly review ritual + bill radar (premium retention)

---

## Owner cheat sheet — product IDs & prices

```
Monthly:  com.dragomir.Inpenso.pro.monthly          → $2.99 / month
Yearly:   com.dragomir.Inpenso.pro.yearly           → $14.99 / year  (UI shows was $29.99)
Special:  com.dragomir.Inpenso.pro.yearly.special   → $11.99 / year  (60% offer)
Bundle:   com.dragomir.Inpenso
Group:    group.com.vintuss.Inpenso
```

Update this file when IDs, prices, or sync architecture change.
