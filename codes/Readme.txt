Readme
======

1. Stacking_prediction/
   A folder containing scripts and resources related to stacking-model prediction,
   model reproduction, and batch prediction workflows.

2. Calculate_vegetation_indices_for_different_band_combinations.m
   A MATLAB script for computing vegetation indices from all possible
   band combinations in UAV spectral datasets stored in Excel files.

3. plot_correlation_heatmap.m
   A MATLAB script for visualizing a predefined correlation matrix and
   corresponding statistical significance levels as a publication-style heatmap.

4. plot_stacking_results_with_intervals.m
   A MATLAB script for reproducing and visualizing stacking-model fitting
   results with regression lines, confidence intervals, and prediction intervals.

Folder Description
------------------
Stacking_prediction/
This folder contains scripts, trained MAT-files, and supporting files used for:
- stacking-model prediction on new datasets;
- reproduction of saved model outputs;
- batch processing of multiple MAT models;
- exporting prediction and evaluation results.

If you use the scripts in this folder, please first check the internal file paths
and modify them according to your local computer environment.

Script Descriptions
-------------------

1. Calculate_vegetation_indices_for_different_band_combinations.m
Purpose:
    Compute vegetation indices for all valid two-band, three-band, four-band,
    and five-band combinations from input Excel files.

Main function:
    - Reads all Excel files in the specified input folder.
    - Iterates through all worksheets in each file.
    - Computes a large set of vegetation indices, including:
      DVI, MSAVI, MSR, NDVI, OSAVI, RVI, RDVI, SAVI, EVI, VARI, ARVI, and MCARI.
    - Writes the results to a new Excel workbook for each input file.

Typical output:
    One Excel file per input file, containing all computed band-combination indices.

2. plot_correlation_heatmap.m
Purpose:
    Visualize the correlation structure between physiological parameters
    and spectral/texture indicators.

Main function:
    - Uses predefined correlation coefficients and p-values.
    - Produces a heatmap with significance markers:
      *   p < 0.05
      **  p < 0.01
      *** p < 0.001
    - Generates a figure suitable for manuscript figures or supplementary materials.

Typical output:
    A formatted heatmap figure displayed in MATLAB.

3. plot_stacking_results_with_intervals.m
Purpose:
    Reproduce and visualize stacking-model performance using a saved MAT-file.

Main function:
    - Loads a trained stacking model and saved datasets from a MAT-file.
    - Recomputes predictions for the training, test, and combined datasets.
    - Fits regression relationships between observed and predicted values.
    - Plots:
      - scatter points,
      - regression lines,
      - 95% confidence intervals,
      - 95% prediction intervals,
      - 1:1 reference line.
    - Reports statistical metrics such as R², RMSE, MAE, MAPE, RPD, slope,
      intercept, and sample size.

Typical output:
    A publication-style regression figure and command-window statistics.

Recommended Usage
-----------------
1. First check and update all file paths in each script.
2. Use the scripts in Stacking_prediction/ when you need model prediction,
   reproduction, or batch processing of trained stacking models.
3. Use Calculate_vegetation_indices_for_different_band_combinations.m when
   spectral index generation is required.
4. Use plot_correlation_heatmap.m for visualizing predefined correlation matrices.
5. Use plot_stacking_results_with_intervals.m for reproducing manuscript figures
   related to stacking-model fitting performance.

Software Requirements
---------------------
- MATLAB R2021b or later is recommended.
- Some scripts require Statistics and Machine Learning Toolbox.
- Excel read/write support is required for scripts processing .xlsx files.

Important Notes
---------------
1. These scripts are primarily intended for supplementary analysis,
   reproducibility, and figure generation.
2. The scripts are not necessarily organized as a fully automated end-to-end pipeline.
3. Users should verify:
   - file paths,
   - folder locations,
   - required MAT variables,
   - worksheet names,
   before execution.
4. Some scripts assume that saved MAT-files already contain trained models
   and corresponding train/test datasets.

Contact and Reuse
-----------------
If these scripts are reused in another study or repository, please cite the
corresponding manuscript or acknowledge the original source of the code.

