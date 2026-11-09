# Gloss

Gloss is a small macOS menu bar app that helps a Chinese-speaking engineer practise English
spelling from their own Obsidian notes. It reads your vocabulary tables and daily mistake logs,
quizzes you with spaced repetition, nudges you when cards are due, and fixes the English you
select anywhere with one shortcut.

It has no Dock icon. It never writes to your vault.

![Gloss screenshot](docs/screenshot.png)

> Screenshot placeholder: run `make screenshot` and copy `shots/now.png` to `docs/screenshot.png`.

## Features

- **Menu bar badge** – the `character.book.closed` icon shows how many cards are due now.
- **Spelling quiz** – a card shows the Chinese meaning, the first letter and the letter count,
  for example `容量 → c_______ (8)`. Type the word and press Enter. Case and extra spaces are ignored.
  A right answer shows a green check and moves on. A wrong answer shows the right spelling with the
  wrong letters marked, your attempt, and your memory hint; the card comes back later in the round.
- **Spaced repetition** – Leitner boxes 1–5 with intervals of 10 minutes, 1 day, 3 days, 7 days and
  21 days. New cards come in order of how often you got them wrong. A card you answered correctly is
  not shown again the same day.
- **Nudges** – a notification every N minutes (default 60) while cards are due, except in quiet hours
  (default 22:00–09:00). Click it to open the quiz.
- **Fix my English** – select text in any app and press ⌃⌥E (configurable). Gloss copies the selection
  (and puts your clipboard back), asks `claude -p` for a correction, and shows the fixed text, a shorter
  version and each mistake with a Chinese explanation in a floating panel, with Copy buttons.
- **Stats** – mistakes per category in the last 7 and 30 days, your 10 most repeated spelling words,
  and quiz accuracy per day.
- **Settings** – vault folder, decks, new cards per day, reminder interval, quiet hours, shortcut,
  launch at login.

## Build

Needs macOS 14 or later and Xcode 15 or later (or the matching command line tools).

```sh
swift build          # debug build
swift test           # unit tests for GlossCore
make app             # or ./scripts/bundle.sh → build/Gloss.app (ad-hoc signed)
make run             # build and open the app
make install         # copy it to /Applications
```

Developer options:

```sh
.build/debug/Gloss --screenshot shots/now.png      # draws a demo window, saves a PNG, exits
.build/debug/Gloss --self-test shots/self-test.json # drives a demo quiz, writes results, exits
```

Both use a built-in deck of made-up words and never touch your vault or saved progress.

## Project layout

- `Sources/GlossCore` – parsing, scheduling, answer checking and stats (no UI). Unit-tested.
- `Sources/Gloss` – the SwiftUI menu bar app.
- `Tests/GlossCoreTests` – XCTest suites. Fixtures use made-up words only.
- `MECHANICS.md` / `mechanics.json` – every number that shapes how Gloss behaves.

## Vault format

The vault folder defaults to `~/ob/英文` (`~` is expanded and symlinks are followed; iCloud Drive works).
Gloss watches it with FSEvents and also checks it every 60 seconds.

### `單字.md`

Markdown tables under level-2 headings. The table under the heading that starts with `## 拼字` is the
spelling deck; the one under `## 用字` is the word-choice deck (off by default). Columns:

```markdown
## 拼字（會唸、不會拼）

| 正確拼法 | 你打的 | 中文 | 記法 | 次數 |
|---|---|---|---|---|
| flumbrance | flumberance | 容量 | **flum** + brance | 4 |
```

| Column | Meaning |
|---|---|
| 正確拼法 | correct spelling – the answer |
| 你打的 | what you typed |
| 中文 | Chinese meaning – shown on the card |
| 記法 | memory hint – shown after a wrong answer |
| 次數 | how many times – an integer, 1 when missing or unreadable |

Cells may use `**bold**`, backticks and `?`; Gloss removes the Markdown for display and removes `?`
from the answer. Rows with missing columns still load.

### `錯誤紀錄/YYYY-MM-DD.md`

One mistake per line:

```markdown
- `original` → `fix` — 中文說明 #類別
```

Categories: `#冠詞 #動詞形式 #單複數 #拼字 #用字 #介系詞 #句型`. Other lines are ignored.

## Saved progress

`~/Library/Application Support/Gloss/state.json`, keyed by the correct spelling: box, due time,
the last day answered correctly, review counts, and answers per day for the stats.

## Permissions

- **Accessibility** – needed by Fix my English to send ⌘C to the front app. Gloss shows a button that
  opens *System Settings → Privacy & Security → Accessibility*. An ad-hoc signed build gets a new
  signature each time you rebuild, so you may need to switch the permission off and on again.
- **Notifications** – asked on first launch; used for the nudges. They only work from `Gloss.app`
  (not from `swift run`).
- **Claude Code** – Fix my English runs the `claude` command line tool, found with
  `/bin/zsh -lc 'command -v claude'`. If it is missing, or takes longer than 30 seconds, the panel says so.
- **Launch at login** – uses `SMAppService`; works when Gloss runs from the `.app` bundle.

## License

MIT – see [LICENSE](LICENSE).
