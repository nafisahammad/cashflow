# CashFlow MVP Blueprint

## Product Goal
Build a fast, simple personal finance tracker for general users in Bangladesh and similar markets.

## Primary Users
- Students
- Job holders
- Freelancers
- Small business owners
- Homemakers

## Product Principles
- Add expense in under 3 seconds.
- Minimize accounting terms.
- Show useful numbers first.
- Keep all primary actions reachable in one tap.

## MVP Scope (Phase 1)

### 1) Transactions
User can add:
- Amount
- Type: income or expense
- Category
- Account
- Date
- Optional note

### 2) Dashboard
Show:
- Total balance
- This month income
- This month expense
- Income vs expense mini chart
- Recent transactions (last 10)

### 3) Accounts
Built-in defaults:
- Cash
- Bank
- bKash
- Nagad

Custom account creation:
- Name
- Type (cash, bank, mobile wallet, savings, credit card)
- Opening balance

Per account:
- Current balance
- Transaction list

### 4) Reports
- Monthly totals (income, expense, savings)
- Category spending breakdown
- Income vs expense chart

## Out of Scope (Phase 2+)
- Budget alerts
- Recurring transactions
- Loan/EMI tracking
- Cloud sync
- PDF/Excel export
- AI insights

## Recommended Tech Stack
- Flutter (single codebase)
- Local-first database: `sqflite`
- State management: `riverpod`
- Charts: `fl_chart`
- Date/currency formatting: `intl`

## App Structure
- Home (dashboard)
- Add Transaction
- Accounts
- Reports
- Settings

Navigation recommendation:
- Bottom nav with 4 tabs: Home, Accounts, Reports, Settings
- Floating action button for Add Transaction

## Data Model (MVP)

### account
- id (string)
- name (string)
- type (string)
- openingBalance (double)
- createdAt (datetime)

### category
- id (string)
- name (string)
- type (income|expense)
- isDefault (bool)

### transaction
- id (string)
- amount (double)
- type (income|expense)
- categoryId (string)
- accountId (string)
- note (string?)
- date (datetime)
- createdAt (datetime)

### computed formulas
- accountBalance = openingBalance + sum(income) - sum(expense)
- totalBalance = sum(all account balances)
- monthSavings = monthIncome - monthExpense

## Default Categories

Expense:
- Food
- Transport
- Rent
- Utilities
- Shopping
- Health
- Education
- Entertainment

Income:
- Salary
- Business
- Freelance
- Gift
- Other

## UX Rules
- Amount field focused by default on Add Transaction.
- Last used account remembered.
- Date defaults to today.
- Type switch always visible.
- Validation must be lightweight and clear.
- Empty states should include action text, example: "No transactions yet. Tap + to add one."

## Visual Direction
- Clean and modern
- Rounded cards
- Strong typography for key balances
- Soft gradient header on dashboard
- Minimal but clear charts

Suggested color direction:
- Primary: teal/green family (financial positivity)
- Expense: warm red
- Income: cool green
- Neutral backgrounds with subtle elevation

## Security and Trust (MVP)
- Local-only data storage
- No account creation required
- Optional PIN lock (Phase 2)

## Delivery Plan

### Sprint 1
- Project architecture setup
- Local database setup and migrations
- Account/category seed data
- Add Transaction screen

### Sprint 2
- Dashboard with monthly summaries
- Recent transactions list
- Accounts list and account details

### Sprint 3
- Reports screen (monthly + category)
- Basic settings
- Empty/loading/error states
- QA and bug fixes

## Definition of Done (MVP)
- User can add/edit/delete transactions
- Balances update correctly across accounts
- Monthly dashboard values are accurate
- Reports match transaction data
- App works fully offline
- App state persists after restart

## Suggested App Names
- CashFlow
- Hishab
- TakaTrack
- Ledgerly

## Next Build Step
Implement Sprint 1 first with local storage only; postpone auth/cloud until post-MVP.
