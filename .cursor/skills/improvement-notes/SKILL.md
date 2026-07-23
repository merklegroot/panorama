---
name: improvement-notes
description: >-
  Read and implement Panorama notes from notes/improvements.json, then mark
  completed notes as done. Use when the user asks to read notes, implement
  notes, work through feedback notes, or process items captured in the app's
  Notes panel.
---

# Notes

Panorama stores notes in `notes/improvements.json`. Users capture them in the
app (sticky-note button in the command bar). When asked to read or implement
those notes, follow this workflow.

## Source of truth

File: `notes/improvements.json`

```json
{
  "notes": [
    {
      "id": "note_…",
      "body": "What to improve",
      "status": "open",
      "createdAt": "ISO-8601",
      "completedAt": null,
      "folderPath": "/optional/context/path"
    }
  ]
}
```

- `status` is `"open"` or `"done"`.
- `folderPath` is optional context from when the note was written (often the folder the user was browsing).
- Do not delete notes; mark them `"done"` instead.

## Workflow

1. **Read** `notes/improvements.json`.
2. **List** every note with `"status": "open"`. If none, say so and stop.
3. **Confirm scope** briefly with the user if there are many open notes or some are ambiguous; otherwise implement all open notes.
4. **Implement** each open note in the codebase. Use `folderPath` as context when relevant.
5. **Mark done** only after that note’s change is actually implemented:
   - set `"status": "done"`
   - set `"completedAt"` to the current ISO-8601 timestamp
   - leave `id`, `body`, `createdAt`, and `folderPath` unchanged
6. **Write** the updated JSON back (pretty-printed, 2-space indent, trailing newline).
7. **Summarize** what you implemented and which note ids were marked done.

## Rules

- Prefer implementing open notes over only summarizing them, unless the user asks for a plan/review only.
- If a note is unclear, ask one focused question instead of guessing.
- If a note is obsolete or already done in the code, still mark it `"done"` and say why.
- Keep unrelated notes untouched.
- Do not invent notes or edit note `body` text unless the user asks.

## Example status update

Before:
```json
{ "id": "note_abc", "body": "Add breadcrumb overflow menu", "status": "open", "createdAt": "2026-07-23T15:00:00.000Z", "completedAt": null, "folderPath": null }
```

After implementing:
```json
{ "id": "note_abc", "body": "Add breadcrumb overflow menu", "status": "done", "createdAt": "2026-07-23T15:00:00.000Z", "completedAt": "2026-07-23T16:12:00.000Z", "folderPath": null }
```
