from pathlib import Path
import os

# Prevent OpenMP deadlocks when loading models created with older ML libraries.
os.environ.setdefault("OMP_NUM_THREADS", "1")
os.environ.setdefault("OPENBLAS_NUM_THREADS", "1")
os.environ.setdefault("MKL_NUM_THREADS", "1")

import pickle
import warnings
import numpy as np
import pandas as pd

warnings.filterwarnings("ignore")

ROOT = Path(__file__).resolve().parent
MODEL_DIR = ROOT / "models"
TRAIN_FILE = ROOT / "Train_Data.xlsx"
TEST_FILE = ROOT / "Test_Data.xlsx"
DATA_FILE = ROOT / "DATA.xlsx"
OUTPUT_FILE = ROOT / "Site1_reproduced_results.xlsx"

def read_features(path, target, feature_input):
    raw = pd.read_excel(path, sheet_name=target, header=None)
    group = raw.iloc[0].ffill().astype(str)
    scale = raw.iloc[1].ffill().astype(str)
    feature = raw.iloc[2].astype(str)

    columns = []
    for column in range(1, raw.shape[1]):
        label = group.iloc[column].lower()
        if feature_input == "Combined":
            keep = "spectral" in label or "texture" in label
        else:
            keep = feature_input.lower() in label
        if keep:
            columns.append(column)

    sample_ids = pd.to_numeric(raw.iloc[3:, 0], errors="coerce").to_numpy(float)
    X = raw.iloc[3:, columns].apply(pd.to_numeric, errors="coerce").to_numpy(float)
    names = [
        f"{group.iloc[c].strip()}__{scale.iloc[c].strip()}__{feature.iloc[c].strip()}"
        for c in columns
    ]

    valid = np.isfinite(sample_ids) & np.all(np.isfinite(X), axis=1)
    return sample_ids[valid].astype(int), X[valid], names

def read_observations(sheet_name, target):
    data = pd.read_excel(DATA_FILE, sheet_name=sheet_name)
    sample_column = next(c for c in data.columns if "sample" in str(c).lower())
    target_column = next(
        c for c in data.columns
        if str(c).replace(" ", "").upper().startswith(target.upper())
    )

    sample_ids = pd.to_numeric(data[sample_column], errors="coerce")
    values = pd.to_numeric(data[target_column], errors="coerce")
    valid = sample_ids.notna() & values.notna()
    return dict(zip(sample_ids[valid].astype(int), values[valid].astype(float)))

def select_samples(sample_ids, X, required_ids):
    position = {int(sample): row for row, sample in enumerate(sample_ids)}
    missing = [int(sample) for sample in required_ids if int(sample) not in position]
    if missing:
        raise KeyError(f"Missing feature samples: {missing}")
    return X[[position[int(sample)] for sample in required_ids]]

def repair_preprocessor(obj):
    if hasattr(obj, "steps"):
        for _, step in obj.steps:
            repair_preprocessor(step)
    elif isinstance(obj, dict):
        for value in obj.values():
            repair_preprocessor(value)

    if (
        obj.__class__.__name__ == "SimpleImputer"
        and not hasattr(obj, "_fill_dtype")
        and hasattr(obj, "_fit_dtype")
    ):
        obj._fill_dtype = obj._fit_dtype

def transform_features(X, selected_idx, preprocessor):
    repair_preprocessor(preprocessor)
    selected = np.asarray(X, dtype=float)[:, np.asarray(selected_idx, dtype=int)]

    if isinstance(preprocessor, dict) and preprocessor.get("type") == "raw_pca":
        raw = preprocessor["base"].transform(selected)
        pca = preprocessor["pca"].transform(raw)
        return np.hstack([raw, pca])

    return preprocessor.transform(selected)

def inverse_target(values, transform):
    values = np.asarray(values, dtype=float)
    if transform == "sqrt":
        values = np.square(np.maximum(values, 0))
    elif transform == "log1p":
        values = np.expm1(values)
    return np.maximum(values, 0)

def predict(model, X):
    mean_y = float(model["y_train_mean"])
    ensemble = model["ensemble"]
    member_predictions = []

    for member in ensemble["members"]:
        transformed = transform_features(
            X, member["selected_idx"], member["preprocess"]
        )
        prediction = member["model"].predict(transformed)
        prediction = inverse_target(prediction, member["target_transform"])
        prediction = mean_y + float(member["gamma"]) * (prediction - mean_y)
        prediction = np.maximum(prediction, 0)

        if member["linear_calibration"] and member["calibration_ab"] is not None:
            intercept, slope = member["calibration_ab"]
            prediction = np.maximum(intercept + slope * prediction, 0)

        member_predictions.append(prediction)

    prediction = sum(
        float(weight) * member_prediction
        for weight, member_prediction in zip(
            ensemble["weights"], member_predictions
        )
    )
    prediction = mean_y + float(ensemble["gamma"]) * (prediction - mean_y)
    prediction = np.maximum(prediction, 0)

    if ensemble["linear_calibration"] and ensemble["calibration_ab"] is not None:
        intercept, slope = ensemble["calibration_ab"]
        prediction = np.maximum(intercept + slope * prediction, 0)

    return prediction

def metrics(observed, predicted):
    observed = np.asarray(observed, dtype=float)
    predicted = np.asarray(predicted, dtype=float)
    residual = observed - predicted
    rmse = np.sqrt(np.mean(residual ** 2))
    return {
        "N": len(observed),
        "R2": 1 - np.sum(residual ** 2) / np.sum((observed - observed.mean()) ** 2),
        "RMSE": rmse,
        "MAE": np.mean(np.abs(residual)),
        "R": np.corrcoef(observed, predicted)[0, 1],
        "RPD": np.std(observed, ddof=1) / rmse,
    }

def main():
    model_paths = sorted(MODEL_DIR.glob("*_Direct_*.pkl"))
    if len(model_paths) != 30:
        raise FileNotFoundError(f"Expected 30 model files, found {len(model_paths)}.")

    feature_cache = {}
    observation_cache = {}
    metric_rows = []
    prediction_rows = []

    for model_path in model_paths:
        with model_path.open("rb") as file:
            model = pickle.load(file)

        target = model["target"]
        feature_input = model["feature_input"]

        for split, feature_file, sample_key, data_sheet in (
            ("Training", TRAIN_FILE, "train_samples", "Train"),
            ("Validation", TEST_FILE, "valid_samples", "Test"),
        ):
            feature_key = (str(feature_file), target, feature_input)
            if feature_key not in feature_cache:
                feature_cache[feature_key] = read_features(
                    feature_file, target, feature_input
                )

            sample_ids, X, feature_names = feature_cache[feature_key]
            if feature_names != model["feature_names"]:
                raise ValueError(f"Feature names do not match for {model_path.name}.")

            required_ids = np.asarray(model[sample_key], dtype=int)
            X_selected = select_samples(sample_ids, X, required_ids)

            observation_key = (data_sheet, target)
            if observation_key not in observation_cache:
                observation_cache[observation_key] = read_observations(
                    data_sheet, target
                )
            observation_map = observation_cache[observation_key]

            missing_observations = [
                int(sample) for sample in required_ids
                if int(sample) not in observation_map
            ]
            if missing_observations:
                raise KeyError(
                    f"Missing observed values for {target}: {missing_observations}"
                )

            observed = np.array(
                [observation_map[int(sample)] for sample in required_ids],
                dtype=float,
            )
            predicted = predict(model, X_selected)

            metric_rows.append({
                "Feature input": feature_input,
                "Target variable": target,
                "Split": split,
                **metrics(observed, predicted),
            })

            prediction_rows.extend({
                "Feature input": feature_input,
                "Target variable": target,
                "Split": split,
                "Sample": int(sample),
                "Observed": float(obs),
                "Predicted": float(pred),
                "Residual": float(obs - pred),
            } for sample, obs, pred in zip(required_ids, observed, predicted))

    metrics_df = pd.DataFrame(metric_rows)
    predictions_df = pd.DataFrame(prediction_rows)

    feature_order = {"Spectral": 0, "Texture": 1, "Combined": 2}
    target_order = {
        target: index for index, target in enumerate(
            ["TSPU", "GPU", "LPU", "SPU", "GB", "GPC", "LB", "LPC", "SB", "SPC"]
        )
    }
    split_order = {"Training": 0, "Validation": 1}

    metrics_df["_feature"] = metrics_df["Feature input"].map(feature_order)
    metrics_df["_target"] = metrics_df["Target variable"].map(target_order)
    metrics_df["_split"] = metrics_df["Split"].map(split_order)
    metrics_df = metrics_df.sort_values(
        ["_feature", "_target", "_split"]
    ).drop(columns=["_feature", "_target", "_split"])

    with pd.ExcelWriter(OUTPUT_FILE, engine="openpyxl") as writer:
        metrics_df.to_excel(writer, sheet_name="Metrics", index=False)
        predictions_df.to_excel(writer, sheet_name="Predictions", index=False)

    print(metrics_df.to_string(index=False, float_format=lambda value: f"{value:.6f}"))
    print(f"\nSaved: {OUTPUT_FILE.name}")

if __name__ == "__main__":
    main()
