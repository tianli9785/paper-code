# Site 1 raw-data fixed-split reproduction
This package reproduces the Site 1 fixed-split results by reading the Excel
feature and observation files and executing model.predict() for all 30 final
models.

## Files
- models/ (30 final inference models)
- requirements.txt
- reproduce_site1.py

## Run
    pip install -r requirements.txt
    python reproduce_site1.py

## Output
    Site1_reproduced_results.xlsx
    The output workbook contains:
    - Metrics: N, R2, RMSE, MAE, R and RPD
    - Predictions: sample-level observed values, predictions and residuals