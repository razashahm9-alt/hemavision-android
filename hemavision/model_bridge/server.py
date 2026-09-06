from __future__ import annotations

import io
import json
import os
from pathlib import Path
from typing import Any, Dict, List, Optional

from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from PIL import Image
from pydantic import BaseModel

REPO_ROOT = Path(__file__).resolve().parents[2]
CANCER_MODEL_DIR = Path(
    os.getenv("CANCER_MODEL_DIR", REPO_ROOT / "models" / "cancer_model")
)
CBC_MODEL_DIR = Path(
    os.getenv(
        "CBC_MODEL_DIR",
        REPO_ROOT / "models" / "cbc_model",
    )
)

app = FastAPI(title="HemaVision Local Model Bridge")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

_cancer_model: Optional[Any] = None
_cancer_processor: Optional[Any] = None
_cancer_labels: List[str] = []
_cbc_model: Optional[Any] = None
_cbc_processor: Optional[Any] = None
_cbc_labels: List[str] = []
_last_errors: Dict[str, str] = {}

DISCLAIMER = (
    "HemaVision is an educational research prototype and is not a substitute "
    "for professional diagnosis."
)


class CbcValues(BaseModel):
    wbc: float
    rbc: float
    hemoglobin: float
    hematocrit: float
    mcv: float
    mch: float
    mchc: float
    platelets: float
    neutrophils: float
    lymphocytes: float
    monocytes: float
    eosinophils: float
    basophils: float


def _load_labels(path: Path, fallback: List[str]) -> List[str]:
    try:
        with (path / "labels.json").open("r", encoding="utf-8") as f:
            data = json.load(f)
        return data.get("labels", fallback)
    except Exception:
        return fallback


def _load_image_processor(model_dir: Path) -> Any:
    from transformers import AutoImageProcessor, ViTImageProcessor

    try:
        return AutoImageProcessor.from_pretrained(model_dir)
    except Exception:
        return ViTImageProcessor(
            do_resize=True,
            size={"height": 224, "width": 224},
            do_rescale=True,
            rescale_factor=1 / 255,
            do_normalize=True,
            image_mean=[0.5, 0.5, 0.5],
            image_std=[0.5, 0.5, 0.5],
        )


def _load_cancer_model() -> bool:
    global _cancer_model, _cancer_processor, _cancer_labels
    if _cancer_model is not None and _cancer_processor is not None:
        return True
    try:
        import torch
        from transformers import ViTForImageClassification

        _cancer_labels = _load_labels(
            CANCER_MODEL_DIR, ["Leukemia", "Lymphoma", "Myeloma", "Normal"]
        )
        _cancer_processor = _load_image_processor(CANCER_MODEL_DIR)
        _cancer_model = ViTForImageClassification.from_pretrained(CANCER_MODEL_DIR)
        _cancer_model.eval()
        torch.set_grad_enabled(False)
        return True
    except Exception as exc:
        _last_errors["cancer"] = str(exc)
        print(f"Cancer model load failed: {exc}")
        return False


def _load_cbc_model() -> bool:
    global _cbc_model, _cbc_processor, _cbc_labels
    if _cbc_model is not None and _cbc_processor is not None:
        return True
    try:
        import torch
        from transformers import ViTConfig, ViTForImageClassification

        _cbc_labels = _load_labels(
            CBC_MODEL_DIR, ["EOSINOPHIL", "LYMPHOCYTE", "MONOCYTE", "NEUTROPHIL"]
        )
        _cbc_processor = _load_image_processor(CBC_MODEL_DIR)
        id2label = {i: label for i, label in enumerate(_cbc_labels)}
        label2id = {label: i for i, label in id2label.items()}

        try:
            _cbc_model = ViTForImageClassification.from_pretrained(CBC_MODEL_DIR)
        except Exception:
            config = ViTConfig.from_pretrained(
                CBC_MODEL_DIR,
                num_labels=len(_cbc_labels),
                id2label=id2label,
                label2id=label2id,
            )
            _cbc_model = ViTForImageClassification(config)
            checkpoint_path = CBC_MODEL_DIR / "cbc_best.pt"
            checkpoint = torch.load(checkpoint_path, map_location="cpu")
            if hasattr(checkpoint, "eval") and callable(checkpoint):
                _cbc_model = checkpoint
            else:
                state = checkpoint
                if isinstance(checkpoint, dict):
                    for key in ("model_state_dict", "state_dict", "model"):
                        if key in checkpoint:
                            state = checkpoint[key]
                            break
                if isinstance(state, dict):
                    cleaned = {
                        key.replace("module.", "", 1): value
                        for key, value in state.items()
                    }
                    _cbc_model.load_state_dict(cleaned, strict=False)
        _cbc_model.eval()
        torch.set_grad_enabled(False)
        return True
    except Exception as exc:
        _last_errors["cbc"] = str(exc)
        print(f"CBC image model load failed: {exc}")
        return False


def _risk_stage(label: str, values: CbcValues, confidence: float = 80) -> Dict[str, Any]:
    if label == "Normal":
        return {
            "analysisType": "manual_cbc",
            "modelType": "rule-based-cbc",
            "cancerType": "Normal",
            "riskLevel": "Low",
            "stage": "N/A",
            "confidenceScore": confidence,
            "recommendation": (
                "Rule-based CBC screening did not flag a strong abnormal pattern. "
                "Continue routine monitoring and clinical follow-up. " + DISCLAIMER
            ),
        }
    risk = "High" if confidence >= 80 else "Medium"
    stage = "Stage 2"
    if label == "Leukemia":
        stage = (
            "Stage 4"
            if values.wbc > 100
            else "Stage 3"
            if values.wbc > 50
            else "Stage 2"
            if values.wbc > 30
            else "Stage 1"
        )
    elif label == "Lymphoma":
        stage = (
            "Stage 4"
            if values.hemoglobin < 8
            else "Stage 3"
            if values.hemoglobin < 10
            else "Stage 2"
            if values.hemoglobin < 12
            else "Stage 1"
        )
    elif label == "Myeloma":
        stage = "Stage 3" if values.platelets < 50 else "Stage 2" if values.platelets <= 100 else "Stage 1"
    return {
        "analysisType": "manual_cbc",
        "modelType": "rule-based-cbc",
        "cancerType": label,
        "riskLevel": risk,
        "stage": stage,
        "confidenceScore": confidence,
        "recommendation": (
            f"Rule-based CBC screening logic flagged a {label} pattern with an "
            f"experimental/rule-based stage estimate of {stage}. This is not a "
            "clinically validated staging result. Please obtain professional "
            "review and confirmatory testing. " + DISCLAIMER
        ),
    }


def _cancer_image_result(label: str, confidence: float) -> Dict[str, Any]:
    risk = "Low" if label == "Normal" else "High" if confidence >= 85 else "Medium"
    return {
        "analysisType": "cancer_image",
        "modelType": "cancer-image-vit",
        "cancerType": label,
        "riskLevel": risk,
        "stage": "N/A",
        "confidenceScore": confidence,
        "recommendation": (
            f"Cancer image model predicted {label} with {confidence:.1f}% "
            "confidence. The risk label is prototype screening logic based on "
            "model confidence only; this model predicts class, not clinical "
            "stage or diagnosis. Please obtain professional review and "
            "confirmatory testing. " + DISCLAIMER
        ),
    }


def _cbc_cell_result(label: str, confidence: float) -> Dict[str, Any]:
    mapping = {
        "LYMPHOCYTE": "Educational context: lymphocyte patterns can be reviewed alongside lymphoma/CLL workups.",
        "MONOCYTE": "Educational context: monocyte abnormalities can appear in chronic marrow disorder reviews.",
        "NEUTROPHIL": "Educational context: neutrophil abnormalities can be reviewed alongside leukemia workups.",
        "EOSINOPHIL": "Educational context: eosinophil patterns may be reviewed in some Hodgkin lymphoma contexts.",
    }
    note = mapping.get(label.upper(), "Educational context unavailable for this cell class.")
    return {
        "analysisType": "cbc_cell_image",
        "modelType": "cbc-cell-image-vit",
        "cancerType": label,
        "riskLevel": "Low",
        "stage": "N/A",
        "confidenceScore": confidence,
        "cellType": label,
        "recommendation": (
            f"CBC cell image model classified the dominant white blood cell as "
            f"{label} with {confidence:.1f}% confidence. This is a cell "
            "classification result, not a direct cancer diagnosis. "
            f"{note} Confirm with CBC values, smear review, and a hematologist "
            "before making clinical decisions. " + DISCLAIMER
        ),
    }


@app.get("/health")
def health() -> Dict[str, Any]:
    return {
        "ok": True,
        "cancer_model": str(CANCER_MODEL_DIR),
        "cbc_model": str(CBC_MODEL_DIR),
        "cancer_model_exists": CANCER_MODEL_DIR.exists(),
        "cbc_model_exists": CBC_MODEL_DIR.exists(),
        "cancer_labels": _load_labels(
            CANCER_MODEL_DIR, ["Leukemia", "Lymphoma", "Myeloma", "Normal"]
        ),
        "cbc_labels": _load_labels(
            CBC_MODEL_DIR, ["EOSINOPHIL", "LYMPHOCYTE", "MONOCYTE", "NEUTROPHIL"]
        ),
        "loaded": {
            "cancer": _cancer_model is not None,
            "cbc": _cbc_model is not None,
        },
        "last_errors": _last_errors,
    }


@app.get("/")
def root() -> Dict[str, Any]:
    return {
        "ok": True,
        "service": "HemaVision Local Model Bridge",
        "health": "/health",
        "warmup": "/warmup",
        "endpoints": ["/predict/cancer", "/predict/cbc-image", "/predict/cbc-values"],
    }


@app.get("/warmup")
def warmup() -> Dict[str, Any]:
    return {
        "ok": True,
        "cancer_loaded": _load_cancer_model(),
        "cbc_loaded": _load_cbc_model(),
        "last_errors": _last_errors,
    }


@app.post("/predict/cancer")
async def predict_cancer(file: UploadFile = File(...)) -> Dict[str, Any]:
    loaded = _load_cancer_model()
    if not loaded:
        raise HTTPException(
            status_code=503,
            detail=f"Cancer model failed to load: {_last_errors.get('cancer', 'unknown error')}",
        )

    import torch

    raw = await file.read()
    image = Image.open(io.BytesIO(raw)).convert("RGB")
    inputs = _cancer_processor(images=image, return_tensors="pt")
    outputs = _cancer_model(**inputs)
    probs = torch.softmax(outputs.logits, dim=-1)[0]
    idx = int(torch.argmax(probs).item())
    confidence = float(probs[idx].item() * 100)
    label = _cancer_labels[idx] if idx < len(_cancer_labels) else f"LABEL_{idx}"
    result = _cancer_image_result(label, confidence=confidence)
    result["rawLabel"] = label
    result["probabilities"] = {
        (_cancer_labels[i] if i < len(_cancer_labels) else f"LABEL_{i}"): float(
            probs[i].item() * 100
        )
        for i in range(len(probs))
    }
    return result


@app.post("/predict/cbc-image")
async def predict_cbc_image(file: UploadFile = File(...)) -> Dict[str, Any]:
    loaded = _load_cbc_model()
    if not loaded:
        raise HTTPException(
            status_code=503,
            detail=f"CBC image model failed to load: {_last_errors.get('cbc', 'unknown error')}",
        )

    import torch

    raw = await file.read()
    image = Image.open(io.BytesIO(raw)).convert("RGB")
    inputs = _cbc_processor(images=image, return_tensors="pt")
    outputs = _cbc_model(**inputs) if callable(_cbc_model) else _cbc_model(inputs)
    logits = outputs.logits if hasattr(outputs, "logits") else outputs
    probs = torch.softmax(logits, dim=-1)[0]
    idx = int(torch.argmax(probs).item())
    confidence = float(probs[idx].item() * 100)
    label = _cbc_labels[idx] if idx < len(_cbc_labels) else f"LABEL_{idx}"
    result = _cbc_cell_result(label, confidence)
    result["modelType"] = "cbc-cell-image"
    result["rawLabel"] = label
    result["probabilities"] = {
        (_cbc_labels[i] if i < len(_cbc_labels) else f"LABEL_{i}"): float(
            probs[i].item() * 100
        )
        for i in range(len(probs))
    }
    return result


@app.post("/predict/cbc-values")
def predict_cbc_values(values: CbcValues) -> Dict[str, Any]:
    abnormal = sum(
        [
            values.wbc > 11 or values.wbc < 4.5,
            values.hemoglobin < 13.5,
            values.platelets < 150 or values.platelets > 400,
            values.lymphocytes > 40,
            values.neutrophils < 40,
            values.monocytes > 8,
        ]
    )
    if abnormal < 2:
        return _risk_stage("Normal", values, 88)
    if values.lymphocytes > 45 or values.wbc > 30:
        label = "Leukemia"
    elif values.platelets < 100 or values.monocytes > 8:
        label = "Myeloma"
    else:
        label = "Lymphoma"
    confidence = min(96, 55 + abnormal * 9)
    return _risk_stage(label, values, confidence)
