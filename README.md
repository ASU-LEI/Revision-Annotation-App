# TRACE Revision Event Labeler

A Heroku-ready FastAPI web app for reviewing TRACE CSV output and assigning `revision_event_label` values by combining adjacent rows into one revision event.

## Features

- Upload one TRACE CSV at a time
- Display selected columns only:
  - `operation_id`
  - `operation`
  - `chunk_label`
  - `source`
  - `source_index`
  - `target`
  - `target_index`
- Check adjacent rows and combine them into one event
- Undo a combined event
- Recompute event labels from the current grouping structure
- Export the full original CSV with an added `revision_event_label` column
- Export filename pattern: `originalname_event_label.csv`

## Local run

```bash
python -m venv .venv
source .venv/bin/activate  # macOS/Linux
pip install -r requirements.txt
uvicorn app:app --reload
```

Open `http://127.0.0.1:8000`

## Heroku deployment

This app is ready for a standard Python deployment on Heroku.

Core files included:
- `Procfile`
- `requirements.txt`
- `runtime.txt`

## Notes

Modern browsers do not let normal web pages force a download into an arbitrary folder. This app uses the browser download flow, and when supported it will try to use the File System Access API so the user can choose a save location more directly.
