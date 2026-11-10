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
| Answer field | keeps the cursor for every card (no clicking); only the question slides | person's follow-up |
| Typing during the green check | goes to the next card at once and keeps the letters | estimated |
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

## Pronunciation

| Value | Number | Source |
|---|---|---|
| Say the word after each answer | on (setting) | person's follow-up request; default estimated |
| Say the word when a card appears | off (setting) | estimated |
| Pronounce shortcut | ⌘P | estimated |
| Voice | system English (en-US), offline | estimated |
| Speed | 0.85 × system default | estimated |

## Look

| Value | Number | Source |
|---|---|---|
| Glass | Liquid Glass on macOS 26; frosted material on macOS 14–15 | person's follow-up request |
| Colour scheme | always dark | person's follow-up request |
| Accent | blue-violet #7D70FF; also blue #5494FF and violet #B06BFF | person's follow-up request; shades estimated |
| Background tone | navy #0D0F2B → plum #24124A over the glass | person's follow-up request; shades estimated |
| Right / wrong / hint colours | mint #61EBD6 / rose #FF669E / amber #FFBD6B | estimated (chosen to sit with blue-violet) |
| Menu popover corners | the whole popover window is clipped to 22 pt rounded corners, with a light edge | person's follow-up (square corners looked broken) |
| App icon | blue-violet 824 pt rounded tile, two frosted flashcards, "Aa" with spelling blanks, mint check | person's follow-up |
| Card corner radius | 30 pt (panels 34 pt, text field and buttons fully round) | person's follow-up request; sizes estimated |

## Menu overview

| Value | Number | Source |
|---|---|---|
| First screen of the menu | overview; the quiz opens from "Start Quiz" (⌘[ goes back) | person's follow-up request |
| Tiles | due now, accuracy (7 days), streak, Leitner boxes, mistakes (7 days, top 3), Fix my English | estimated |
| English Health | "Getting started" under 5 answers in 7 days; "Good" ≥ 80 % and ≤ 20 due; "Fair" ≥ 60 %; else "Needs practice" | estimated |
| Streak | days in a row with at least one answer, ending today or yesterday | estimated |
| Open Gloss from anywhere | ⌃⌥G shows the overview as a window at the top right (press again to hide) | person's follow-up; key estimated |
| First launch / opening Gloss.app again | shows the overview, with a "Gloss lives in your menu bar" note until "Got It" | person's follow-up |
| Windows | one main window with a sidebar: Overview, Quiz, Stats, Fix My English, Settings (⌘1–5); the menu, ⌃⌥G, notifications and reopening all open it | person's follow-up (too many windows) |
| ⌘Tab and Dock | while the Gloss window is open Gloss is a regular app (Dock icon, ⌘Tab, ⌘W closes); closed, it is menu bar only (setting, on by default) | person's follow-up |
| Main window size | 1000 × 760 pt (min 900 × 640), position remembered | estimated |
| Screenshot and self-test windows | drawn off-screen, so checks never flash a window | person's follow-up |
| Today's Recommendation | due cards first (names the meaning, never the word), then the worst 7-day category, then Fix my English | estimated |

## Motion

All of it turns off when macOS "Reduce motion" is on.

| Value | Number | Source |
|---|---|---|
| Letter boxes | one box per letter, filled as you type (no right/wrong shown until Enter); the first letter is a hint; "+N" for extra letters; boxes up to 30 pt, shrinking to fit | person's follow-up; design estimated |
| Round progress bar | right answers ÷ (right answers + cards left), springs on change | estimated |
| Overview tiles | fade and slide in one after another, 0.06 s apart; numbers roll up from 0; bars grow from 0 | estimated |
| Hover | tiles lift 1.5 % with a violet glow; buttons grow 3–8 % and brighten | estimated |
| Wrong answer | the card shakes 3 times (9 pt, 0.45 s); wrong letters pop | estimated |
| Right answer | 16 sparks burst out (0.85 s); boxes turn mint one by one; check mark bounces | estimated |
| Next card | slides in from the right | estimated |
| Sidebar | the selected highlight slides to the new page; pages fade in | estimated |
| Speaker buttons | ripple while the word is spoken | estimated |
| Background | the violet glows drift slowly (24 s loop) | estimated |
| Spring | response 0.42 s, damping 0.78 (quick taps 0.28 s) | estimated |

## Extra practice

Shown when the day's reviews are done (and from "Practise More" on the overview).

| Value | Number | Source |
|---|---|---|
| Choices | Hardest 10 (count column, then lowest box) · Random 10 · Today's words (answered today) · Learn 10 new | person's follow-up |
| Round size | 10 cards | estimated |
| Schedule | practice answers never change boxes or due times; a wrong practice card still comes back later in the round | estimated |
| Stats | practice answers are counted per day on their own, not in quiz accuracy | estimated |
| Learn 10 new | raises today's new-card limit by 10 and starts them as real (scheduled) cards | estimated |
| Overview suggestion | "Keep practising" when nothing is due, unless one category has 3+ mistakes this week | estimated |
