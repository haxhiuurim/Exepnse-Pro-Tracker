# Inpenso

<p align="center">
  <kbd>
    <img src=".github/assets/inpenso-logo.png" alt="Inpenso Logo" width="150" height="150"/>
  </kbd>
</p>

**Inpenso** is a private, on-device expense tracker for iOS — redesigned around the *Tide Ledger* look: deep teal ink, mist atmosphere, and copper actions.

## Features

- **Quick Add** — amount-first sheet, floating +, and saved spend shortcuts
- **Period widgets** — Today / Week / Month spending on the Home Screen with one-tap add
- **Receipt scan** — photograph a receipt; Vision OCR fills items, prices, and category on-device
- **Smart Insights** — category pulse, trends, budgets, and spending insights
- **Daily reminders** — gentle nudge to log spending before the day ends
- **Siri Shortcuts** — add expenses by voice
- **Privacy-first** — data stays on your device (App Group shared only with widgets)

## Requirements

- iOS 18.0+
- Xcode 16.0+
- Swift 5.9+

## Installation

1. Clone the repository:
```bash
git clone https://github.com/haxhiuurim/exepnse-pro-tracker.git
```

2. Open `Inpenso.xcodeproj` in Xcode.

3. Build and run on an iOS device or simulator.

## Architecture

Inpenso follows MVVM:

- **Models** — expenses, categories, periods, quick-spend templates
- **Views** — SwiftUI screens + Tide Ledger design system
- **ViewModels** — cashflow, analytics, settings
- **Services** — App Group storage, receipt OCR (Vision), reminders

## License

MIT — see [LICENSE](LICENSE).
