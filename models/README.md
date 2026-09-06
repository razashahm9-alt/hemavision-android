# HemaVision Model Files

This directory contains the configuration and label metadata for the two Vision Transformer image-classification models used by the HemaVision local model bridge.

> HemaVision is an educational research prototype. Model outputs are not clinically validated diagnoses.

## Directory structure

```text
models/
├── cancer_model/
│   ├── config.json
│   ├── labels.json
│   ├── stage_info.json
│   └── model.safetensors
└── cbc_model/
    ├── config.json
    ├── labels.json
    ├── cbc_info.json
    ├── model.safetensors
    └── cbc_best.pt
```

## Cancer image model

The cancer image classifier uses a Vision Transformer configured for 224 × 224 RGB images.

Classes:

- Leukemia
- Lymphoma
- Myeloma
- Normal

The included training metadata records a best checkpoint accuracy of approximately 94.57%. This is a training/validation artifact and must not be interpreted as independently verified clinical accuracy.

## CBC cell image model

The CBC image classifier identifies the dominant white blood-cell class in a microscopic image.

Classes:

- EOSINOPHIL
- LYMPHOCYTE
- MONOCYTE
- NEUTROPHIL

The included training metadata records a best checkpoint accuracy of approximately 88.95%. This model performs cell classification, not direct cancer diagnosis.

## Model weights

Large weight files are excluded from Git because they exceed normal GitHub file-size limits:

```text
models/cancer_model/model.safetensors
models/cbc_model/model.safetensors
models/cbc_model/cbc_best.pt
```

To run inference, place the trained weights in the locations above before starting the FastAPI bridge.

The bridge also supports custom locations through:

```text
CANCER_MODEL_DIR
CBC_MODEL_DIR
```

Model configuration, labels, and descriptive metadata remain included in the repository.
