# HemaVision Flutter Client

This directory contains the Flutter client for HemaVision, an educational blood-analysis research prototype.

The application supports:

- Cancer-image classification
- CBC white blood-cell image classification
- Experimental rule-based screening from manually entered CBC values
- Firebase Authentication and user profiles
- Firestore-backed report history
- PDF export, sharing, text-to-speech, dashboard analytics, and themes

The Flutter client communicates with the local FastAPI/PyTorch service located in [`model_bridge`](model_bridge/README.md).

For complete project documentation, architecture, screenshots, model setup, security configuration, and limitations, see the [main repository README](../README.md).

## Quick start

Start the model bridge first, then run:

```powershell
flutter pub get
flutter run -d chrome --dart-define=MODEL_BRIDGE_BASE=http://127.0.0.1:8000
```

> HemaVision is an educational research prototype. Its outputs are not clinically validated diagnoses and must not replace professional medical evaluation.
