README
======

File Description
--------
1. Stacking_prediction.m
   This script reads trained .mat model files from a specified directory and automatically performs prediction for a multi-sheet NewData.xlsx file.

Format of NewData
----------------
1.  NewData.xlsx is organized as a single Excel workbook containing multiple worksheets, for example:
    LPC, SPC, GPC, LB, SB, GB, LPU, SPU, GPU, and TSPU.

2.  In each worksheet, the first column represents the target variable or observed value.
    For example, in the LPC worksheet, the first column is LPC.

3. The remaining columns are feature variables, such as:
     VARI_B25_B33, EVI_2_B3_B5, ARVI_D_B15_B4, OSAVI_E16_B19, OSAVI_F_B33_B25, and OSAVI_G_B33_B29.

Correspondence Between the Script and NewData
------------------------------
1.  Each .mat model automatically searches for a worksheet with the same name.
    For example:
    LPC.mat → reads the LPC worksheet in NewData.xlsx
    SPC.mat → reads the SPC worksheet in NewData.xlsx

2.  Because the .mat models store feature_names, the script extracts predictor variables from the corresponding worksheet by matching column names.
    Therefore, even if the column order changes, correct prediction can still be achieved as long as the column names remain consistent.

Default Paths
--------
The default path for mat_folder is:
C:\Users\dell\Desktop\paper-code\codes\Stacking_prediction\Site 1

The default path for new_excel_file is:
C:\Users\dell\Desktop\paper-code\codes\Stacking_prediction\Site 1\NewData.xlsx

The default output directory is:
C:\Users\dell\Desktop\paper-code\codes\Stacking_prediction\Site 1\prediction_outputs

Usage Instructions
--------
1. Place your .mat model files in:
   C:\Users\dell\Desktop\paper-code\codes\Stacking_prediction\Site 1

2. Place the new multi-sheet Excel file in the appropriate directory, for example:
   C:\Users\dell\Desktop\paper-code\codes\Stacking_prediction\Site 1\NewData.xlsx

3. Open the script Stacking_prediction.m and modify the following parameters as needed:
   - mat_folder
   - new_excel_file
   - output_folder

4. Run the following command in the MATLAB Command Window:
   Stacking_prediction

Output Files
--------
After execution, the script automatically generates:

1. One prediction result file for each model, named in the format:
    model_filename_prediction.xlsx

2. Each prediction result file contains two worksheets:
   - Prediction: original input data, predictions from each base learner, and the final stacking prediction
   - Metrics: if the observed target column is available, this worksheet stores R², RMSE, and MAE

3. One summary file:
    prediction_summary.xlsx

Important Notes
--------
1. Each worksheet name in NewData.xlsx must correspond to a model name. Otherwise, the relevant model will be skipped automatically.

2. If the new data do not contain the feature columns required by the trained model, that model will also be skipped, and the reason will be displayed in the MATLAB Command Window.

3. This script does not retrain the model. It only loads the trained .mat files and performs direct prediction.

Recommended Practice
--------
If the current folder contains:
- LPC.mat
- SPC.mat
- LPU.mat

and NewData.xlsx contains:
- LPC sheet
- SPC sheet
- LPU sheet

then, after running the script, the program will automatically:
- use the LPC model to predict the LPC worksheet
- use the SPC model to predict the SPC worksheet
- use the LPU model to predict the LPU worksheet

Frequently Asked Questions
--------
Q1：This usually occurs for one of two reasons:
A：This usually occurs for one of two reasons:
   - NewData.xlsx does not contain a worksheet with the corresponding name.
   - The worksheet lacks the feature columns required by the trained model.

Q2：Why are R², RMSE, and MAE calculated automatically?
A：Because, in the current NewData structure, the first column is the observed target variable, prediction accuracy can be evaluated directly.

Q3：Does this script retrain the model?
A：No. It only loads the trained .mat models and performs direct prediction.

Q4：Can prediction still be performed if the column order changes?
A：Yes. As long as feature_names are stored in the .mat file, the script aligns the predictor variables automatically by column name.
