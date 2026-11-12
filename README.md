# M88 Cards

Personal iOS flashcard app (SwiftUI, iOS 17+). Subjects → subtopics → cards, a Quizlet-style
question | answer list per subtopic, and an Anki-style quiz (Again / Hard / Good / Easy, SM-2 scheduling).

## Build

```bash
brew install xcodegen   # once
xcodegen generate
open M88Cards.xcodeproj
```

Select your team under Signing & Capabilities, then run on your iPhone.

## Decks

Bundled decks live in `M88Cards/Decks/*.json`. One file = one subject:

```json
{ "id": "anatomy", "name": "Anatomy", "color": "#2563EB",
  "topics": [ { "id": "anatomy/upper-limb", "name": "Upper limb",
    "cards": [ { "id": "ul-1", "q": "Nerve of the thenar muscles?", "a": "Median (recurrent branch)", "note": "optional" } ] } ] }
```

Or import from the + button in the app: a JSON file in that shape, or a CSV / TSV with columns
`question, answer, topic (optional), subject (optional)`. Imported decks go to the app's Documents folder
(visible in the Files app) and override a bundled deck with the same id.

The six bundled ECG decks were generated from the drkard.com ECG course atoms.
