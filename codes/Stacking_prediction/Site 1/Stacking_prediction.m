function predict_from_mat_excel_by_sheet_bilingual()
% =========================================================================
% Batch prediction from trained .mat models using a multi-sheet Excel file
%
% Assumptions:
% 1) Each model corresponds to a worksheet with the same name in NewData.xlsx.
% 2) In each worksheet, the first column is the observed target variable,
%    and the remaining columns are predictor variables.
%
% Outputs:
% - One prediction Excel file for each model
% - One summary file: prediction_summary.xlsx
% =========================================================================

clc;
clear;
close all;
warning('off', 'all');

%% ===================== User-defined settings =====================
% Folder containing trained .mat files
mat_folder = 'C:\Users\dell\Desktop\paper-code\codes\Stacking_prediction\Site 1';

% Path to the multi-sheet Excel file for prediction
new_excel_file = 'C:\Users\dell\Desktop\paper-code\codes\Stacking_prediction\Site 1\NewData_Example.xlsx';

% Output folder for prediction results
output_folder = fullfile(mat_folder, 'prediction_outputs');

% Whether to recursively search subfolders for .mat files
search_subfolders = false;

% If feature_names are missing in .mat, skip the first column by default
skip_first_column_when_no_feature_names = true;

%% ===================== Create output folder =====================
if ~exist(output_folder, 'dir')
    mkdir(output_folder);
end

%% ===================== Search for .mat files =====================
if search_subfolders
    mat_files = dir(fullfile(mat_folder, '**', '*.mat'));
else
    mat_files = dir(fullfile(mat_folder, '*.mat'));
end

if isempty(mat_files)
    error('No .mat files were found in the specified folder: %s', mat_folder);
end

fprintf('A total of %d .mat file(s) were found.\n', length(mat_files));

%% ===================== Retrieve worksheet names =====================
[~, sheet_names] = xlsfinfo(new_excel_file);
if isempty(sheet_names)
    error('Unable to read worksheet information from the Excel file: %s', new_excel_file);
end

%% ===================== Batch prediction =====================
summary_cell = {};
summary_idx = 0;

for k = 1:length(mat_files)
    try
        mat_path = fullfile(mat_files(k).folder, mat_files(k).name);
        fprintf('\n--------------------------------------------------\n');
        fprintf('Processing model file : %s\n', mat_path);

        %% ===== Load .mat file =====
        S = load(mat_path);

        % Compatible with both direct fields and a final_results structure
        if isfield(S, 'final_results')
            M = S.final_results;
        else
            M = S;
        end

        %% ===== Extract trained models =====
        if isfield(M, 'best_models')
            best_models = M.best_models;
        else
            error('The field "best_models" was not found.');
        end

        if isfield(M, 'best_meta_model')
            best_meta_model = M.best_meta_model;
        elseif isfield(M, 'meta_model')
            best_meta_model = M.meta_model;
        else
            error('Neither "best_meta_model" nor "meta_model" was found.');
        end

        %% ===== Determine worksheet name =====
        % Priority: use sheet_name stored in .mat
        if isfield(M, 'sheet_name') && ~isempty(M.sheet_name)
            model_sheet_name = char(string(M.sheet_name));
        else
            % Fallback: use the .mat file name (without extension)
            [~, model_sheet_name, ~] = fileparts(mat_files(k).name);
        end

        %% ===== Check worksheet existence =====
        if ~ismember(model_sheet_name, sheet_names)
            fprintf('Skipped: no matched worksheet in Excel -> %s\n', model_sheet_name);
            continue;
        end

        %% ===== Read matched worksheet =====
        new_table = readtable(new_excel_file, 'Sheet', model_sheet_name);
        fprintf('Matched worksheet: %s | Rows: %d | Columns: %d\n', ...
            model_sheet_name, height(new_table), width(new_table));

        %% ===== Determine target column =====
        if isfield(M, 'target_col') && ~isempty(M.target_col)
            target_col = char(string(M.target_col));
        else
            % Default: use the first column name in the worksheet
            target_col = new_table.Properties.VariableNames{1};
        end

        %% ===== Read feature names =====
        feature_names = {};
        if isfield(M, 'feature_names')
            feature_names = M.feature_names;
        end

        %% ===== Read scaling parameters if available =====
        has_scaler = false;
        if isfield(M, 'mu') && isfield(M, 'sigma')
            mu = M.mu;
            sigma = M.sigma;
            sigma(sigma == 0) = 1;
            has_scaler = true;
        end

        %% ===== Build predictor matrix =====
        if ~isempty(feature_names)
            % Normalize feature_names format to cellstr
            if isstring(feature_names)
                feature_names = cellstr(feature_names);
            elseif ischar(feature_names)
                feature_names = cellstr(feature_names);
            end

            % Check missing predictor columns
            missing_features = setdiff(feature_names, new_table.Properties.VariableNames);
            if ~isempty(missing_features)
                fprintf('Skipped: missing predictor columns:\n');
                disp(missing_features(:));
                continue;
            end

            % Extract predictors by column names
            X_new = table2array(new_table(:, feature_names));
        else
            % If feature_names are unavailable, infer feature dimension from X_train
            n_features = [];
            try
                n_features = size(M.X_train, 2);
            catch
            end

            if isempty(n_features)
                error('feature_names are unavailable and feature dimension cannot be inferred from X_train.');
            end

            if skip_first_column_when_no_feature_names
                % Assume the first column is the target variable
                if width(new_table) < (n_features + 1)
                    error(['The worksheet does not contain enough columns for the format ', ...
                           '"first column = target, remaining columns = predictors". ']);
                end
                X_new = table2array(new_table(:, 2:(n_features+1)));
            else
                % Use the first n_features columns directly
                if width(new_table) < n_features
                    error('The worksheet does not contain enough predictor columns.');
                end
                X_new = table2array(new_table(:, 1:n_features));
            end
        end

        %% ===== Apply scaling if available =====
        if has_scaler
            X_new = (X_new - mu) ./ sigma;
        end

        %% ===== Prediction by base learners =====
        n_models = length(best_models);
        base_pred = zeros(size(X_new, 1), n_models);

        for i = 1:n_models
            base_pred(:, i) = predict(best_models{i}, X_new);
        end

        %% ===== Prediction by stacking meta-learner =====
        stack_pred = predict(best_meta_model, base_pred);

        %% ===== Compute metrics if observed values are available =====
        has_actual = false;
        R2 = NaN; RMSE = NaN; MAE = NaN;

        if ~isempty(target_col) && ismember(target_col, new_table.Properties.VariableNames)
            actual_y = table2array(new_table(:, target_col));
            if isnumeric(actual_y)
                actual_y = actual_y(:);
                if length(actual_y) == length(stack_pred)
                    has_actual = true;
                    ss_res = sum((actual_y - stack_pred).^2);
                    ss_tot = sum((actual_y - mean(actual_y)).^2);
                    R2 = 1 - ss_res / ss_tot;
                    RMSE = sqrt(mean((actual_y - stack_pred).^2));
                    MAE = mean(abs(actual_y - stack_pred));
                end
            end
        end

        %% ===== Organize output tables =====
        default_model_names = {'DecisionTree', 'RandomForest', 'SVM', 'NeuralNet'};
        if n_models <= length(default_model_names)
            base_names = default_model_names(1:n_models);
        else
            base_names = cell(1, n_models);
            for i = 1:n_models
                base_names{i} = sprintf('BaseModel_%d', i);
            end
        end

        % Prediction table: base learners + stacking result
        pred_table = array2table([base_pred, stack_pred], ...
            'VariableNames', [base_names, {'Stacking'}]);

        % Combine original data with predictions
        output_table = [new_table, pred_table];

        % Metrics sheet
        if has_actual
            metric_table = table(R2, RMSE, MAE);
        else
            metric_table = table();
        end

        %% ===== Write output Excel =====
        [~, mat_name, ~] = fileparts(mat_files(k).name);
        output_excel = fullfile(output_folder, [mat_name '_prediction.xlsx']);
        writetable(output_table, output_excel, 'Sheet', 'Prediction');

        if has_actual
            writetable(metric_table, output_excel, 'Sheet', 'Metrics');
        end

        %% ===== Update summary =====
        summary_idx = summary_idx + 1;
        summary_cell{summary_idx, 1} = mat_name;
        summary_cell{summary_idx, 2} = model_sheet_name;
        summary_cell{summary_idx, 3} = size(X_new, 1);
        summary_cell{summary_idx, 4} = R2;
        summary_cell{summary_idx, 5} = RMSE;
        summary_cell{summary_idx, 6} = MAE;
        summary_cell{summary_idx, 7} = output_excel;

        fprintf('Prediction completed: %s\n', output_excel);
        if has_actual
            fprintf('R^2 = %.4f | RMSE = %.4f | MAE = %.4f\n', R2, RMSE, MAE);
        end

    catch ME
        fprintf('Processing failed: %s\n', mat_files(k).name);
        fprintf('Reason: %s\n', ME.message);
    end
end

%% ===================== Save summary table =====================
if ~isempty(summary_cell)
    summary_table = cell2table(summary_cell, ...
        'VariableNames', {'ModelFile', 'MatchedSheet', 'NumSamples', ...
                          'R2', 'RMSE', 'MAE', 'OutputExcel'});
    summary_path = fullfile(output_folder, 'prediction_summary.xlsx');
    writetable(summary_table, summary_path);
    fprintf('\n=== All tasks completed ===\n');
    fprintf('The summary file was saved to: %s\n', summary_path);
else
    fprintf('\nNo prediction task was completed successfully.\n');
end

end
