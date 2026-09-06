# HemaVision Firebase Data Structure

HemaVision uses Firebase Authentication and Cloud Firestore when a real Firebase configuration is active.

## Authentication

Firebase Console path:

```text
Authentication > Users
```

Firebase Authentication manages:

- Email/password accounts
- Firebase user identifiers
- Sign-in provider information
- Account creation and last sign-in information
- Secure password-reset emails

Passwords are managed securely by Firebase Authentication and are not stored in Cloud Firestore by HemaVision.

## Cloud Firestore

Firebase Console path:

```text
Firestore Database > Data
```

### `users`

Created during registration or when a missing profile is saved.

Fields can include:

- `fullName`
- `email`
- `role`
- `phone`
- `createdAt`

The document ID is the authenticated user's Firebase UID.

### `cbc_reports`

Created when CBC parameters are entered and submitted through the **CBC Values** form.

Fields include:

- `userId`
- `createdAt`
- `wbc`
- `rbc`
- `hemoglobin`
- `hematocrit`
- `mcv`
- `mch`
- `mchc`
- `platelets`
- `neutrophils`
- `lymphocytes`
- `monocytes`
- `eosinophils`
- `basophils`

Cancer-image and CBC-cell image classifications do not create fabricated CBC-value documents.

### `analysis_results`

Stores saved analysis output.

Fields include:

- `reportId`
- `userId`
- `cancerType`
- `riskLevel`
- `stage`
- `confidenceScore`
- `recommendation`
- `analyzedAt`
- `analysisType`
- `modelType`
- `cellType` when applicable

Supported analysis categories include cancer-image classification, CBC-cell image classification, and experimental rule-based CBC Values screening.

## Firebase Storage

Storage rules are configured for paths using:

```text
cbc_reports/{userId}/{fileName}
```

Only the authenticated owner can read or write within their path. The current image-analysis workflow sends selected images directly to the local FastAPI model bridge and does not require Firebase Storage persistence.

## Security

Firestore and Storage rules restrict profile and report access using the authenticated user's UID.

Real Firebase configuration files are kept locally and excluded from Git. Safe setup templates are provided in:

```text
hemavision/config_examples/
```

> HemaVision is an educational research prototype and is not a substitute for professional diagnosis.
