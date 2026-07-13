function reproduce_models_from_mat_batch_simple()
% =========================================================================
% Reproduce stacking model predictions directly from saved .mat files
% This script does NOT retrain the models.
% For each .mat file, the script:
%   1) recompute predictions on X_train and X_test
%   2) recompute stacking predictions
%   3) compute R², RMSE, and MAE
%   4) export one Excel file per model and one summary file
% =========================================================================

clc;
clear;
close all;
warning('off', 'all');

%% ===================== User settings ==========================
mat_folder = 'C:\Users\dell\Desktop\paper-code\codes\Stacking_prediction\Site 2';
output_folder = fullfile(mat_folder, 'reproduced_results');
search_subfolders = false;

%% ===================== Create output folder ============
if ~exist(output_folder, 'dir')
    mkdir(output_folder);
end

%% ===================== Search .mat files ===============
if search_subfolders
    mat_files = dir(fullfile(mat_folder, '**', '*.mat'));
else
    mat_files = dir(fullfile(mat_folder, '*.mat'));
end

if isempty(mat_files)
    error('No .mat files were found in the specified folder: %s', mat_folder);
end

fprintf('Found %d .mat file(s).\n', length(mat_files));

%% ===================== Summary container =====================
summary_cell = {};
summary_idx = 0;

%% ===================== Batch reproduction ====================
for k = 1:length(mat_files)
    try
        mat_path = fullfile(mat_files(k).folder, mat_files(k).name);
        fprintf('\n====================================================\n');
        fprintf('Processing: %s\n', mat_path);

        S = load(mat_path);

        required_fields = {'best_models', 'best_meta_model', 'X_train', 'X_test', 'y_train', 'y_test'};
        for i = 1:length(required_fields)
            if ~isfield(S, required_fields{i})
                error('Missing required field: %s', required_fields{i}, required_fields{i});
            end
        end

        best_models = S.best_models;
        best_meta_model = S.best_meta_model;
        X_train = S.X_train;
        X_test  = S.X_test;
        y_train = S.y_train(:);
        y_test  = S.y_test(:);

        if isfield(S, 'feature_names')
            feature_names = S.feature_names;
        else
            feature_names = {};
        end

        n_models = length(best_models);

        train_pred = zeros(length(y_train), n_models);
        test_pred  = zeros(length(y_test),  n_models);

        for i = 1:n_models
            train_pred(:, i) = predict(best_models{i}, X_train);
            test_pred(:, i)  = predict(best_models{i}, X_test);
        end

        stack_train = predict(best_meta_model, train_pred);
        stack_test  = predict(best_meta_model, test_pred);

        [r2_train, rmse_train, mae_train] = calc_metrics(y_train, stack_train);
        [r2_test,  rmse_test,  mae_test]  = calc_metrics(y_test,  stack_test);

        n_train = size(X_train, 1);
        n_test  = size(X_test, 1);
        n_total = n_train + n_test;
        train_ratio = n_train / n_total;
        test_ratio  = n_test  / n_total;

        [~, mat_name, ~] = fileparts(mat_files(k).name);

        default_model_names = {'DecisionTree', 'RandomForest', 'SVM', 'NeuralNet'};
        if n_models <= length(default_model_names)
            base_names = default_model_names(1:n_models);
        else
            base_names = cell(1, n_models);
            for i = 1:n_models
                base_names{i} = sprintf('BaseModel_%d', i);
            end
        end

        train_table = array2table([y_train, train_pred, stack_train], ...
            'VariableNames', [{'Observed'}, base_names, {'Stacking'}]);

        test_table = array2table([y_test, test_pred, stack_test], ...
            'VariableNames', [{'Observed'}, base_names, {'Stacking'}]);

        metric_table = table( ...
            n_train, n_test, train_ratio, test_ratio, ...
            r2_train, rmse_train, mae_train, ...
            r2_test, rmse_test, mae_test, ...
            'VariableNames', {'NTrain', 'NTest', 'TrainRatio', 'TestRatio', ...
                              'R2_Train', 'RMSE_Train', 'MAE_Train', ...
                              'R2_Test', 'RMSE_Test', 'MAE_Test'});

        if ~isempty(feature_names)
            if isstring(feature_names)
                feature_names = cellstr(feature_names);
            elseif ischar(feature_names)
                feature_names = cellstr(feature_names);
            end
            feature_table = table(feature_names(:), 'VariableNames', {'FeatureName'});
        else
            feature_table = table();
        end

        out_xlsx = fullfile(output_folder, [mat_name '_reproduced.xlsx']);
        writetable(train_table, out_xlsx, 'Sheet', 'TrainPrediction');
        writetable(test_table,  out_xlsx, 'Sheet', 'TestPrediction');
        writetable(metric_table, out_xlsx, 'Sheet', 'Metrics');

        if ~isempty(feature_names)
            writetable(feature_table, out_xlsx, 'Sheet', 'Features');
        end

        summary_idx = summary_idx + 1;
        summary_cell{summary_idx, 1}  = mat_name;
        summary_cell{summary_idx, 2}  = n_train;
        summary_cell{summary_idx, 3}  = n_test;
        summary_cell{summary_idx, 4}  = train_ratio;
        summary_cell{summary_idx, 5}  = test_ratio;
        summary_cell{summary_idx, 6}  = r2_train;
        summary_cell{summary_idx, 7}  = rmse_train;
        summary_cell{summary_idx, 8}  = mae_train;
        summary_cell{summary_idx, 9}  = r2_test;
        summary_cell{summary_idx, 10} = rmse_test;
        summary_cell{summary_idx, 11} = mae_test;
        summary_cell{summary_idx, 12} = out_xlsx;

        fprintf('Reproduction completed: %s\n', mat_name);
        fprintf('Train R^2 = %.4f | Test R^2 = %.4f\n', r2_train, r2_test);
        fprintf('Train RMSE = %.4f | Test RMSE = %.4f\n', rmse_train, rmse_test);

    catch ME
        fprintf('Failed: %s\n', mat_files(k).name);
        fprintf('Reason: %s\n', ME.message);
    end
end

%% ===================== Save summary ========================
if ~isempty(summary_cell)
    summary_table = cell2table(summary_cell, ...
        'VariableNames', {'ModelFile', ...
                          'NTrain', 'NTest', 'TrainRatio', 'TestRatio', ...
                          'R2_Train', 'RMSE_Train', 'MAE_Train', ...
                          'R2_Test',  'RMSE_Test',  'MAE_Test', ...
                          'OutputExcel'});
    summary_path = fullfile(output_folder, 'reproduction_summary.xlsx');
    writetable(summary_table, summary_path);

    fprintf('\n====================================================\n');
    fprintf('All reproductions completed\n');
    fprintf('Summary file: %s\n', summary_path);
else
    fprintf('\nNo model was reproduced successfully.\n');
end

end

%% ===================== Local function ========================
function [r2, rmse, mae] = calc_metrics(y_true, y_pred)
y_true = y_true(:);
y_pred = y_pred(:);

ss_res = sum((y_true - y_pred).^2);
ss_tot = sum((y_true - mean(y_true)).^2);

r2 = 1 - ss_res / ss_tot;
rmse = sqrt(mean((y_true - y_pred).^2));
mae = mean(abs(y_true - y_pred));
end
