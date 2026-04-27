Readme
======

File name
----------------
Stacking_prediction.m

Purpose
--------------
This script reproduces stacking-model predictions directly from saved .mat files.

Required variables in each .mat file
-----------------------------------------------------------------------
Each .mat file must contain the following fields:

1. best_models
   Trained base learners.

2. best_meta_model
   Trained stacking meta-learner.

3. feature_names
   Names of predictor variables.

4. X_train, y_train
   Training dataset and target values.

5. X_test, y_test
   Test dataset and target values.

Main functions
------------------------
For each .mat file, the script will:

1. Load best_models and best_meta_model.
2. Use X_train and X_test to recompute base-model predictions.
3. Use best_meta_model to recompute stacking predictions.
4. Recalculate R², RMSE, and MAE.
5. Export one Excel file for each model.
6. Export one summary Excel file for all models.

Default folder settings
------------------------------------
Default model folder:
C:\Users\dell\Desktop\paper-code\codes\Stacking_prediction\Site 2
Default output folder:
C:\Users\dell\Desktop\paper-code\codes\Stacking_prediction\Site 2\reproduced_results

How to use
--------------------
1. Put all .mat model files into the specified folder.
2. Open the script Stacking_prediction.m.
3. Modify the following parameters if needed:
   - mat_folder
   - output_folder
   - search_subfolders
4. Run the script in MATLAB:
   reproduce_models_from_mat_batch_simple

Output files
----------------------
For each .mat model file, the script exports:

1. modelname_reproduced.xlsx
   This file contains:
   - TrainPrediction
     Observed values and reproduced predictions for the training set.
   - TestPrediction
     Observed values and reproduced predictions for the test set.
   - Metrics
     Recomputed R², RMSE, MAE, and inferred train:test ratio.
   - Features
     Predictor names stored in feature_names.

2. reproduction_summary.xlsx
   Summary of all reproduced models.

Notes
------------
1. This script does not retrain any model.
2. The train:test ratio is inferred from X_train and X_test.
3. If a .mat file is missing required fields, it will be skipped and the reason
   will be displayed in the MATLAB Command Window.

Recommended use
-------------------------
This script is suitable for:
- reproducing model outputs stored in multiple .mat files;
- organizing prediction results under different train:test splits;
- preparing reproducibility materials for code release or supplementary files.