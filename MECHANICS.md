# Gloss mechanics

Every number that shapes how Gloss behaves. "request" means the person's build request gave it;
"estimated" means I chose it because the request did not say.

## Spaced repetition

| Value | Number | Source |
|---|---|---|
| Leitner boxes | 5 | request |
| Box 1 interval | 10 min | request |
| Box 2 interval | 1 day | request |
| Box 3 interval | 3 days | request |
| Box 4 interval | 7 days | request |
| Box 5 interval | 21 days | request |
| Correct answer | box + 1 (max 5); new card → box 1 | estimated (standard Leitner) |
| Wrong answer | back to box 1, due in 10 min | estimated (standard Leitner) |
| Same-day rule | a card answered correctly is not shown again that calendar day | request |
| Correct after a wrong answer in the same round | counts for today, stays in its box | estimated |
| New-card order | count column, higher first; file order for ties | request |
| New cards per day | 10 (setting) | estimated – keeps the badge from showing every new card at once |
| Due reviews order | oldest due first, then higher count | estimated |

## Quiz

| Value | Number | Source |
|---|---|---|
| Card text | `中文 → first letter + "_" per letter (letter count)` | request |
| Answer check | trim, collapse spaces, case-insensitive | request |
| Wrong card requeue | 3 cards later (or at the end) | estimated |
| Green check pause | 0.7 s | estimated |
| Enter on a wrong answer | next card | estimated |
| Popover width | 380 pt | estimated |

## Reminders and watching

| Value | Number | Source |
|---|---|---|
| Nudge interval | 60 min (setting) | request |
| Quiet hours | 22:00–09:00 (setting) | request |
| Due / nudge / vault poll tick | 60 s | request (polling every 60 s) |
| FSEvents latency | 1 s | estimated |

## Fix my English

| Value | Number | Source |
|---|---|---|
| Shortcut | ⌃⌥E (setting) | request |
| Claude timeout | 30 s | request |
| Wait for ⌘C copy | 0.6 s | estimated |

## Stats

| Value | Number | Source |
|---|---|---|
| Category windows | 7 and 30 days | request |
| Top repeated words | 10 | request |
| Accuracy chart | 14 days | estimated |
