from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score

ROOT = Path(__file__).resolve().parent
DATA_FILE = ROOT / "Time_series_index.xlsx"
MODEL_FILE = ROOT / "final_models.joblib"
OUTPUT_FILE = ROOT / "Site2_reproduced_results.xlsx"
TARGETS = ("LPU", "SPU", "GPU")

def read_data(target, subset):
    raw = pd.read_excel(DATA_FILE, sheet_name=f"{target}_{subset}", header=None)
    group = raw.iloc[0].ffill().astype(str)
    stage = raw.iloc[1].ffill().astype(str)
    feature = raw.iloc[2].astype(str)
    data = raw.iloc[3:]

    sample_id = pd.to_numeric(data.iloc[:, 0], errors="coerce")
    y = pd.to_numeric(data.iloc[:, 1], errors="coerce")
    names = [
        f"{target}__{group.iloc[i].strip()}__{stage.iloc[i].strip()}__{feature.iloc[i].strip()}"
        for i in range(2, raw.shape[1])
    ]
    X = data.iloc[:, 2:].apply(pd.to_numeric, errors="coerce").to_numpy(float)
    keep = np.isfinite(sample_id) & np.isfinite(y) & np.all(np.isfinite(X), axis=1)
    return sample_id[keep].astype(int).to_numpy(), X[keep], y[keep].to_numpy(float), names

def expand_features(X, names):
    values = [X]
    expanded_names = list(names)

    unary = []
    for i, name in enumerate(names):
        x = X[:, i]
        unary.extend((x**2, np.abs(x), np.sign(x) * np.log1p(np.abs(x))))
        expanded_names.extend((f"{name}__square", f"{name}__abs", f"{name}__slog1p"))
    values.append(np.column_stack(unary))

    pairwise = []
    with np.errstate(divide="ignore", invalid="ignore"):
        for i in range(X.shape[1]):
            for j in range(i + 1, X.shape[1]):
                a, b = X[:, i], X[:, j]
                na, nb = names[i], names[j]
                pairwise.extend((
                    a - b,
                    np.abs(a - b),
                    a * b,
                    a / (np.sign(b) * np.maximum(np.abs(b), 1e-8)),
                    b / (np.sign(a) * np.maximum(np.abs(a), 1e-8)),
                ))
                expanded_names.extend((
                    f"{na}__minus__{nb}",
                    f"{na}__absdiff__{nb}",
                    f"{na}__x__{nb}",
                    f"{na}__ratio__{nb}",
                    f"{nb}__ratio__{na}",
                ))
    values.append(np.column_stack(pairwise))

    return np.nan_to_num(np.hstack(values), nan=0.0, posinf=0.0, neginf=0.0), expanded_names

def preprocess(transformer, X):
    if isinstance(transformer, dict):
        raw = transformer["base"].transform(X)
        return np.hstack((raw, transformer["pca"].transform(raw)))
    return transformer.transform(X)

def inverse_transform(pred, method):
    if method == "sqrt":
        pred = np.square(np.maximum(pred, 0))
    else:
        pred = np.expm1(pred)
    return np.maximum(pred, 0)

def shrink_expand(pred, mean_y, gamma):
    return np.maximum(mean_y + gamma * (pred - mean_y), 0)

def predict_target(target, saved):
    train_id, X_train, y_train, names = read_data(target, "Train")
    valid_id, X_valid, y_valid, _ = read_data(target, "Valid")
    X_train, expanded_names = expand_features(X_train, names)
    X_valid, _ = expand_features(X_valid, names)
    index = {name: i for i, name in enumerate(expanded_names)}

    train_predictions = []
    valid_predictions = []
    for member in saved["members"]:
        cols = [index[name] for name in member["selected_features"]]
        pred_train = inverse_transform(
            member["model"].predict(preprocess(member["preprocess"], X_train[:, cols])),
            member["target_transform"],
        )
        pred_valid = inverse_transform(
            member["model"].predict(preprocess(member["preprocess"], X_valid[:, cols])),
            member["target_transform"],
        )
        train_predictions.append(shrink_expand(pred_train, y_train.mean(), member["gamma"]))
        valid_predictions.append(shrink_expand(pred_valid, y_train.mean(), member["gamma"]))

    pred_train = sum(w * pred for w, pred in zip(saved["weights"], train_predictions))
    pred_valid = sum(w * pred for w, pred in zip(saved["weights"], valid_predictions))
    pred_train = shrink_expand(pred_train, y_train.mean(), saved["gamma"])
    pred_valid = shrink_expand(pred_valid, y_train.mean(), saved["gamma"])

    if saved["linear_calibration"]:
        intercept, slope = saved["calibration_ab"]
        pred_train = np.maximum(intercept + slope * pred_train, 0)
        pred_valid = np.maximum(intercept + slope * pred_valid, 0)

    predictions = pd.concat((
        pd.DataFrame({
            "SampleNumber": train_id,
            "Observed": y_train,
            "Predicted": pred_train,
            "Residual": y_train - pred_train,
            "Subset": "Train",
        }),
        pd.DataFrame({
            "SampleNumber": valid_id,
            "Observed": y_valid,
            "Predicted": pred_valid,
            "Residual": y_valid - pred_valid,
            "Subset": "Validation",
        }),
    ), ignore_index=True)

    summary = []
    for subset, observed, predicted in (
        ("Train", y_train, pred_train),
        ("Validation", y_valid, pred_valid),
    ):
        rmse = np.sqrt(mean_squared_error(observed, predicted))
        summary.append({
            "Target": target,
            "Subset": subset,
            "N": len(observed),
            "R2": r2_score(observed, predicted),
            "RMSE": rmse,
            "MAE": mean_absolute_error(observed, predicted),
            "R": np.corrcoef(observed, predicted)[0, 1],
            "RPD": np.std(observed, ddof=1) / rmse,
        })
    return summary, predictions

def main():
    models = joblib.load(MODEL_FILE)
    summary = []
    predictions = {}

    for target in TARGETS:
        target_summary, predictions[target] = predict_target(target, models[target])
        summary.extend(target_summary)

    with pd.ExcelWriter(OUTPUT_FILE, engine="openpyxl") as writer:
        pd.DataFrame(summary).to_excel(writer, sheet_name="Summary", index=False)
        for target in TARGETS:
            predictions[target].to_excel(writer, sheet_name=f"{target}_Predictions", index=False)

if __name__ == "__main__":
    main()
