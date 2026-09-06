# HemaVision Local Model Bridge

This FastAPI service connects the Flutter application to the local PyTorch Vision Transformer models. The Flutter client sends image or CBC-value requests, and the bridge returns structured JSON results.

> HemaVision is an educational research prototype and is not a substitute for professional diagnosis.

## Expected model structure

Model weights are expected in the repository-level `models` directory:

```text
HemaVision_Android/
├── hemavision/
│   └── model_bridge/
│       ├── server.py
│       └── requirements.txt
└── models/
    ├── cancer_model/
    │   ├── config.json
    │   ├── labels.json
    │   └── model.safetensors
    └── cbc_model/
        ├── config.json
        ├── labels.json
        ├── model.safetensors
        └── cbc_best.pt
```

Large model weights are excluded from Git and must be added locally.

Custom paths can be supplied with the `CANCER_MODEL_DIR` and `CBC_MODEL_DIR` environment variables.

## Setup

From the repository root:

```powershell
cd .\hemavision\model_bridge
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r requirements.txt
```

The verified development environment uses Python 3.13.9.

## Run for Flutter web or desktop

```powershell
python -m uvicorn server:app --host 127.0.0.1 --port 8000
```

Flutter web and desktop use:

```text
http://127.0.0.1:8000
```

## Run for an Android emulator or physical device

```powershell
python -m uvicorn server:app --host 0.0.0.0 --port 8000
```

The Android emulator uses:

```text
http://10.0.2.2:8000
```

For a physical Android phone, keep the phone and computer on the same network and start Flutter with:

```powershell
flutter run -d <device-id> --dart-define=MODEL_BRIDGE_BASE=http://<computer-ipv4>:8000
```

## Verification

Check model paths:

```powershell
Invoke-RestMethod http://127.0.0.1:8000/health
```

Load both models:

```powershell
Invoke-RestMethod http://127.0.0.1:8000/warmup -TimeoutSec 300
```

## API endpoints

| Method | Endpoint | Purpose |
|---|---|---|
| `GET` | `/health` | Reports model paths and loading state |
| `GET` | `/warmup` | Loads both models into memory |
| `POST` | `/predict/cancer` | Classifies a microscopic image into cancer/normal classes |
| `POST` | `/predict/cbc-image` | Classifies the dominant white blood-cell type |
| `POST` | `/predict/cbc-values` | Applies experimental rule-based screening to manually entered CBC values |

The image endpoints expect multipart form data with a field named `file`.
