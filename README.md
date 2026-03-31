# TRACE Revision Event Labeler

A Heroku-ready FastAPI web app for reviewing TRACE CSV output and assigning `revision_event_label` values by combining adjacent rows into one revision event.

## Features

- Upload one TRACE CSV at a time
- Display selected columns:
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


