# Hual Mock API

Run from the repository root:

```powershell
python -m pip install -r backend/mock/requirements.txt
python -m uvicorn backend.mock.app:app --host 127.0.0.1 --port 8000
```

The mock reads `progress/01_API_CONTRACT.yaml` on startup and returns the
documented JSON examples. Success examples are returned by default. Alternate
examples can be selected with `?example=...`, such as:

```powershell
curl.exe "http://127.0.0.1:8000/search?example=failure"
curl.exe "http://127.0.0.1:8000/recommendations/u_001?example=cold_start_fallback"
```
