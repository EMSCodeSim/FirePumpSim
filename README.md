# FirePumpSim

FirePumpSim is a fire pump operator practice app with visual scenarios, daily challenge questions, formula references, calculator tools, pump-card references, and printable pump practice worksheets.

## Current content

- Free Starter Pack scenarios are included in Practice Scenarios.
- Digital paid scenario packs are marked as **Coming Soon** until content is created.
- Printable paid packs are marked as **Coming Soon** until content is created.

## Scenario validation

Run this before publishing new scenario content:

```bash
python3 tool/validate_scenarios.py
```

The script checks for invalid JSON, duplicate scenario/problem IDs, missing images, and missing answer keys.
