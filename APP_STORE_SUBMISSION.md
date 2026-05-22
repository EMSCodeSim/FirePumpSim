# FirePumpSim App Store Submission Notes

## App information

**Name:** FirePumpSim  
**Subtitle:** Pump operator practice scenarios  
**Category:** Education  
**Age rating:** 4+ is appropriate unless App Store Connect flags user-generated content or web access later.  
**Price:** Free for this build.

## Promotional text

Practice pump pressure, friction loss, relay, standpipe, master stream, and daily driver/operator questions with visual fireground scenarios.

## Description

FirePumpSim is a visual pump operator practice app built for firefighters, engineers, instructors, and driver/operator students.

Use short fireground scenarios to practice the hydraulic decisions you make at the pump panel:

• Practice pump-pressure and friction-loss problems
• Work through visual hose layouts and fireground setups
• Answer a daily pump challenge and build consistency
• Review common formulas for PDP, friction loss, elevation, relay pumping, nozzle reaction, smooth bore flow, hydrant pressure drop, and more
• Use quick calculator and pump-card reference tools during practice
• Generate printable scenario worksheets for drills and classroom review

FirePumpSim is designed as a training and study reference. It helps students slow down, identify the setup, calculate the correct values, and review the explanation after each answer.

Included training areas:

• Attack lines
• Wye operations
• Standpipe / FDC support
• Portable master streams
• Relay pumping
• Hydrant supply
• Nozzle reaction
• Smooth bore flow
• Tender and water-supply practice

Important: FirePumpSim is a training reference only. Always follow your department SOPs, instructor direction, local training standards, and manufacturer pump/nozzle data before operational use.

## Keywords

fire,pump,operator,engineer,driver,hydraulics,friction,standpipe,relay,nozzle,firefighter

## What’s New

This version prepares FirePumpSim for public release with cleaner app naming, iPhone-focused orientation, improved safety/privacy wording, scenario validation support, and a smaller app bundle by removing unused duplicate artwork.

## Review notes

FirePumpSim does not require login. No demo account is needed.

The app is a firefighter training/reference tool. It stores user progress such as daily challenge history locally on the device using shared preferences. It does not require a network connection for core practice content and does not collect personal information in this build.

Scenario packs marked as future/coming-soon are informational only. There are no active paid unlock buttons or in-app purchase flows in this build.

## Privacy answers for this build

- Account creation: No
- User tracking: No
- Third-party ads: No
- Data linked to user: No
- Data used for tracking: No
- Data collected: None, assuming no analytics, ads, crash reporting SDK, or external service is added before submission.

## Screenshot checklist

Use real screenshots from the running app, not mockups. Recommended first five screenshots:

1. Home screen with FirePumpSim banner and main training cards
2. Practice Scenarios list showing the Free Starter Pack
3. Scenario Player showing image, question, and answer input
4. Daily Challenge screen showing timer/streak/question
5. Formulas or Pump Card reference screen

For the current iPhone-only build, upload iPhone screenshots. If iPad support is turned back on later, App Store Connect will require iPad screenshots too.

## Final local checks before upload

```bash
python3 tool/validate_scenarios.py
flutter clean
flutter pub get
flutter analyze
flutter build ipa --release --build-name=1.0.5 --build-number=5
```

Then upload the generated IPA/archive through Xcode Organizer, Transporter, Codemagic, or Dreamflow’s App Store pipeline.
