# Moneyglot launch checklist

Steps marked **🧑 You** need your Apple Account, identity or payment details, so only you can do them. Steps marked **🤖 Claude** can be done for you in a Claude Code session.

## 1. Apple Developer Program (one time)

- [ ] **🧑 You** — Enroll at <https://developer.apple.com/programs/enroll/> ($99/year). Use the Apple Account you want to publish under. Individual enrollment shows your legal name as the seller; enrolling as an organization needs a D-U-N-S number.
- [ ] **🧑 You** — Wait for approval (usually 24–48 hours).
- [ ] **🧑 You** — In Xcode › Settings › Accounts, sign in with that Apple Account.
- [ ] **🧑 You** — App Store Connect › Business: accept the **Paid Apps Agreement** and add banking and tax info (required to sell subscriptions).
- [ ] **🧑 You** (recommended) — Apply for the **App Store Small Business Program** so Apple's commission is 15% instead of 30%. At $2.49/month you'd net about $2.12 per subscriber.

## 2. Project setup

- [ ] **🤖 Claude** — Set `DEVELOPMENT_TEAM` to your Team ID and confirm the bundle ID `com.moneyglot.app` (it can be changed until step 3).
- [x] **🤖 Claude** — Point the app's privacy and support links at `https://asfateh.github.io/moneyglot/`.
- [ ] **🤖 Claude** — Publish the GitHub repo `asfateh/moneyglot` and turn on GitHub Pages from the `/docs` folder.
- [ ] **🧑 You** — Open the privacy policy URL in a browser and check that it loads (App Review checks it).

## 3. App Store Connect

- [ ] **🧑 You** — My Apps › ＋ › New App: platform iOS, name **Moneyglot: Expense Tracker**, language English (U.S.), bundle ID `com.moneyglot.app`, SKU `MONEYGLOT-IOS-001`. If the name is taken, try "Moneyglot – Multi-Currency".
- [ ] **🧑 You / 🤖 Claude** — Monetization › Subscriptions: create the group **Moneyglot Pro** and the product `com.moneyglot.app.pro.monthly` using the values in `LISTING.md` (price, 1-week free trial, localization, review screenshot).
- [ ] **🧑 You / 🤖 Claude** — Fill in the App Store tab from `LISTING.md`: subtitle, description, keywords, promotional text, support and privacy URLs, category, age rating.
- [ ] **🧑 You** — App Privacy: "Data Not Collected".
- [ ] **🧑 You / 🤖 Claude** — Upload the screenshots from `AppStore/screenshots/`.

## 4. Build and upload

- [ ] **🤖 Claude** — Bump `CURRENT_PROJECT_VERSION` for every upload.
- [ ] **🧑 You** — In Xcode: choose *Any iOS Device*, then **Product › Archive** › **Distribute App** › **App Store Connect** › Upload. (Once your account is signed in to Xcode, Claude can also run this with `xcodebuild archive` and `-exportArchive`.)
- [ ] **🧑 You** — TestFlight: install on your own iPhone and test a sandbox subscription purchase, restore and cancel.

## 5. Submit

- [ ] **🧑 You** — Attach the build and the subscription to version 1.0, paste the review notes from `LISTING.md` and click **Submit for Review**. First reviews usually take 1–3 days.

## Common rejection reasons to avoid

- Privacy policy or support URL doesn't load → finish step 2 before submitting.
- Subscription not submitted together with the first app version → attach it on the version page.
- Paywall missing price, period, Terms or Privacy links → the built-in `SubscriptionStoreView` already shows all of these.
- Debug-only features visible → the Developer section and sample data only exist in Debug builds; Archive uses Release.
