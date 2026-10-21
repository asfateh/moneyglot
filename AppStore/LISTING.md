# App Store listing — Moneyglot 1.0

Copy these into App Store Connect › your app › App Store tab. Character limits are Apple's.

| Field | Value | Limit |
|---|---|---|
| **Name** | Moneyglot: Expense Tracker | 30 |
| **Subtitle** | Track spending in any currency | 30 |
| **Category** | Primary: Finance · Secondary: Productivity | — |
| **Age rating** | 4+ (answer "None" to every content question) | — |
| **Price** | Free (with in-app subscription) | — |
| **Bundle ID** | com.moneyglot.app | — |
| **SKU** | MONEYGLOT-IOS-001 | — |

## Promotional text (170)

New: your private AI money coach. Moneyglot Pro studies your income, loans and spending in every currency and shows you exactly where to save.

## Keywords (100, comma-separated, no spaces)

```
budget,multi,converter,mortgage,loan,bills,travel,expat,savings,money,finance,exchange,fx,income,ai
```

## Description (4000)

```
Moneyglot speaks every currency.

Earn in one currency, pay your mortgage in another, and spend on holiday in a third? Moneyglot keeps every entry in the currency it really happened in — then shows your whole financial picture in the currency you choose.

TRACK EVERYTHING
• Income: salary, freelance, rental income, investments
• Loans & credit: mortgage, car loan, credit card payments
• Bills & insurance: utilities, phone & internet, insurance, subscriptions
• Everyday spending: groceries, dining, transport, shopping, travel and more

160+ CURRENCIES
• Enter any amount in any currency — USD, EUR, GBP, CAD, INR, AED, PKR, JPY and many more
• Exchange rates update automatically and work offline
• Pin "your currencies" for one-tap entry

SET IT AND FORGET IT
• Make mortgage, loan, insurance, bill or salary entries repeat weekly, monthly, quarterly or yearly
• Moneyglot records them for you on every due date
• See what's coming up in the next 30 days

CLEAR REPORTS
• Monthly, quarterly and yearly reports
• Switch the report currency in one tap
• Income vs. expenses, savings rate, spending by category
• See how much of your income goes to loans and fixed bills
• See which currencies you paid in
• Export any report to CSV

MONEYGLOT PRO — YOUR AI MONEY COACH
• A personal savings plan written for your real numbers
• Smart insights: spending spikes, debt load, housing costs, subscriptions and foreign card fees
• Powered by Apple Intelligence, on your iPhone — your data never leaves it

PRIVATE BY DESIGN
• No account, no ads, no tracking
• Your data stays on your iPhone

Moneyglot Pro is an optional auto-renewable monthly subscription. Payment is charged to your Apple Account at confirmation of purchase. The subscription renews automatically unless cancelled at least 24 hours before the end of the current period. Manage or cancel any time in your Apple Account settings.

The AI plan requires an iPhone that supports Apple Intelligence. Suggestions are for information only and are not financial advice.

Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy Policy: https://asfateh.github.io/moneyglot/privacy.html
```

## URLs

- **Support URL:** https://asfateh.github.io/moneyglot/
- **Privacy Policy URL:** https://asfateh.github.io/moneyglot/privacy.html
- **Marketing URL:** (optional) the GitHub repository

## App Privacy ("nutrition label")

Answer **"No, we do not collect data from this app."** The app has no accounts, analytics or ads; entries stay on device; the AI runs on device; the exchange-rate request contains no user data.

## In-app purchase: subscription

| Field | Value |
|---|---|
| Subscription group | Moneyglot Pro |
| Reference name | Pro Monthly |
| Product ID | `com.moneyglot.app.pro.monthly` (must match `StoreManager.proMonthlyID`) |
| Duration | 1 month |
| Price | US $2.49 tier (or $2.50 if offered — Apple sets the available price points) |
| Introductory offer (recommended) | 1-week free trial, new subscribers |
| Display name | Moneyglot Pro |
| Description | AI savings plan and smart insights |
| Review screenshot | Screenshot of the paywall (Insights tab › Start free trial) |

## Review notes (paste into "Notes" for App Review)

```
Moneyglot works without an account. To see the premium feature, tap the Insights tab and start the subscription (sandbox). The AI savings plan uses Apple's on-device Foundation Models framework and requires an Apple Intelligence-capable device with Apple Intelligence enabled; on other devices the app shows rule-based insights instead. To see insights quickly, add about 20 entries spanning a month (backdating the Date field works).
```

## Screenshots

Required: 6.9" iPhone (1320 × 2868 or 1290 × 2796). Generated screenshots are in `AppStore/screenshots/`.
