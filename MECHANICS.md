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
| Green check pause | 0.7 s, then the next card by itself (tracked by card, cancelled if Enter, typing or Skip moved on first); the field is cleared for the new card | person's follow-up (it did not always move on) |
| Enter on a wrong answer | with the copy drill on: counts a copy; on an empty field: skips to the next card | person's follow-up |
| Copy drill after a mistake | type the right spelling 3 times (setting 0–5; 0 = off); boxes show each letter right (mint) or wrong (rose) as you type; a copy with a mistake doesn't count and shakes the card; the next card comes 0.6 s after the last copy; it doesn't change the schedule | person's follow-up |
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
| Save mistakes to vault | off (setting “Save Fix My English mistakes to vault”) | person's follow-up |
| Mistake log file | `<vault>/錯誤紀錄/YYYY-MM-DD.md` (local date), append-only (opened with O_APPEND), created if missing; a newline is added first if the file does not end with one | person's follow-up |
| Mistake line | ``- `original` → `fix` — 中文說明 #類別`` | person's follow-up |
| Categories saved | 冠詞, 動詞形式, 單複數, 拼字, 用字, 介系詞, 句型; others and capitalization/punctuation-only changes are skipped (apostrophes `'` `’` are not punctuation here) | person's follow-up |
| Dedupe | a line exactly equal (after trimming) to one already in today's file is not written; 單字.md only changes for lines written now | person's follow-up |
| 單字.md update | 拼字 → `## 拼字` table, 用字 → `## 用字` table; existing row (正確拼法, case-insensitive, Markdown stripped): 次數 + 1, new wrong spelling added to 你打的 with `, `; new word: row `correct \| wrong \| 中文 \| 記法 \| 1` at the end of the table; proper nouns skipped | person's follow-up |
| 單字.md safety | re-read right before writing; only targeted lines change; temp file in the same folder, then rename; heading/table missing, duplicate heading/row, not 5 columns or two tables (when adding) → no write, warning in the panel | person's follow-up |
| Status line | “Saved N mistakes to 錯誤紀錄” (+ “updated N words in 單字.md”), “Already saved to 錯誤紀錄”, or the warning | person's follow-up |

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
| Menu popover height | the popover window resizes to its content (overview ↔ quiz) with its top kept under the menu bar | person's follow-up (quiz floated with a gap above it) |
| Menu popover corners | the whole popover window is clipped to 22 pt rounded corners, with a light edge | person's follow-up (square corners looked broken) |
| App icon | blue-violet 824 pt rounded tile, two frosted flashcards, "Aa" with spelling blanks, mint check | person's follow-up |
| Card corner radius | 30 pt (panels 34 pt, text field and buttons fully round) | person's follow-up request; sizes estimated |

## Menu overview

| Value | Number | Source |
|---|---|---|
| First screen of the menu | overview; the quiz opens from "Start Quiz" (⌘[ goes back) | person's follow-up request |
| Tiles | due now, accuracy (7 days), streak, Leitner boxes, mistakes (7 days, top 3), Fix my English | estimated |
| Tile layout | a 3 × 2 grid: both tiles of a row share one height, action links sit on the bottom edge, every tile at least 112 pt | person's follow-up (blocks were different sizes) |
| English Health | "Getting started" under 5 answers in 7 days; "Good" ≥ 80 % and ≤ 20 due; "Fair" ≥ 60 %; else "Needs practice" | estimated |
| Streak | days in a row with at least one answer, ending today or yesterday | estimated |
| Open Gloss from anywhere | ⌃⌥G shows the overview as a window at the top right (press again to hide) | person's follow-up; key estimated |
| First launch / opening Gloss.app again | shows the overview, with a "Gloss lives in your menu bar" note until "Got It" | person's follow-up |
| Windows | one main window with a sidebar: Overview, Quiz, Stats, Fix My English, Settings (⌘1–5); the menu, ⌃⌥G, notifications and reopening all open it | person's follow-up (too many windows) |
| ⌘Tab and Dock | while the Gloss window is open Gloss is a regular app (Dock icon, ⌘Tab, ⌘W closes); closed, it is menu bar only (setting, on by default) | person's follow-up |
| Main window size | 1000 × 760 pt (min 900 × 640), position remembered | estimated |
| Screenshot and self-test windows | drawn off-screen, so checks never flash a window | person's follow-up |
| README recordings (`make demos`) | each scene runs 4× slower off-screen (animations, pauses, wash, script), one snapshot every 1/30 s of scene time, played back at true speed: 30 frames a second, no gap over ~50 ms; the main window is snapshotted at 820 px | person's follow-up (choppy), measured |
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
| Right answer | 16 sparks burst out (0.85 s); boxes turn mint and hop 3 pt one by one with a glow (no scale-up, so long words keep their spacing); check mark bounces | person's follow-up (boxes too crowded) |
| Next card | slides in from the right | estimated |
| Sidebar | the selected highlight slides to the new page; pages fade in | estimated |
| Speaker buttons | ripple while the word is spoken | estimated |
| Background | the violet glows drift slowly (24/30/36 s loops), run by Core Animation; paused while the window is hidden, closed or in the background | person's follow-up (CPU) |
| CPU | idle with windows closed: 0.0 %; window in use: about 0.1 % (self-test step idle-cpu, `--cpu-check`) — was 8–10 % | person's follow-up, measured |
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

## New words and Claude speed

| Value | Number | Source |
|---|---|---|
| New words deck | the `## 問過的字` table of 單字.md (`| 字 | 中文 | 例句 |`; the example is the hint after a mistake) plus words added in Gloss; on by default; a word already in another deck is quizzed once | person's follow-up |
| Add Word page | type the word, Enter: Claude fills a Traditional Chinese meaning and an example (and fixes the spelling); ⌘↩ adds it; "Practise These" starts a practice round | person's follow-up |
| Where a new word goes | with "Write to my notes" on: a new row at the end of `## 問過的字` (refused if the word is there or the table has other columns); off: `~/Library/Application Support/Gloss/words.json` | estimated |
| Claude start-up | 5.3 s before the model sees a question (measured, `claude -p "ok"`) | measured |
| Waiting Claude | one `claude -p --input-format stream-json` started ahead; each question gets a fresh one, the next starts in the background; replaced after 60 min | person's follow-up (speed) |
| Claude flags | `--setting-sources project --strict-mcp-config --tools "" --effort low --no-session-persistence --model haiku` (no hooks, MCP servers or tools) | measured |
| Answer times | word look-up 1.2 s; fix 2.5–7 s depending on the answer's length (was 10.8 s) | measured with `--claude-check` |
