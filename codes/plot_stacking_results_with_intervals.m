function plot_stacking_results_with_intervals_supplementary()
%PLOT_STACKING_RESULTS_WITH_INTERVALS_SUPPLEMENTARY Visualize stacking results.
%
% DESCRIPTION
%   This function loads a trained stacking model from a .mat file,
%   reproduces predictions for the training, test, and combined datasets,
%   rescales values if needed, and visualizes regression lines together
%   with 95% confidence intervals and 95% prediction intervals.
%
% INPUTS
%   None directly. User-defined settings are specified in the parameter
%   section below.
%
% USER SETTINGS
%   Edit the MAT-file path and optional scale factor before running.
%
% OUTPUTS
%   A publication-style figure showing:
%     - training-set scatter and regression line
%     - test-set scatter and regression line
%     - combined-dataset regression line
%     - confidence intervals and prediction intervals
%
% NOTES
%   1. This script assumes that the MAT-file contains:
%        X_train, X_test, y_train, y_test, best_models, best_meta_model
%   2. The scale factor can be set to 1 if no unit conversion is required.

    % ------------------------- User settings -------------------------
    mat_file = 'C:\Users\dell\Desktop\paper-code\codes\Stacking_prediction\Site 1\TSPU.mat';
    scale_factor = 65000 * 0.001 * 0.001;

    % --------------------------- Load model --------------------------
    S = load(mat_file);

    required_fields = {'X_train', 'X_test', 'y_train', 'y_test', 'best_models', 'best_meta_model'};
    for i = 1:numel(required_fields)
        if ~isfield(S, required_fields{i})
            error('The MAT-file is missing the required field: %s', required_fields{i});
        end
    end

    X_train = S.X_train;
    X_test = S.X_test;
    y_train = S.y_train(:);
    y_test = S.y_test(:);
    best_models = S.best_models;
    best_meta_model = S.best_meta_model;

    % ---------------------- Recompute predictions --------------------
    x_all = [X_train; X_test];
    y_all = [y_train; y_test];

    n_models = length(best_models);
    train_pred = zeros(length(y_train), n_models);
    test_pred  = zeros(length(y_test), n_models);
    all_pred   = zeros(length(y_all), n_models);

    for i = 1:n_models
        train_pred(:, i) = predict(best_models{i}, X_train);
        test_pred(:, i)  = predict(best_models{i}, X_test);
        all_pred(:, i)   = predict(best_models{i}, x_all);
    end

    stack_train = predict(best_meta_model, train_pred);
    stack_test  = predict(best_meta_model, test_pred);
    stack_all   = predict(best_meta_model, all_pred);

    % -------------------------- Rescale data -------------------------
    y_train = y_train * scale_factor;
    stack_train = stack_train * scale_factor;
    y_test = y_test * scale_factor;
    stack_test = stack_test * scale_factor;
    y_all = y_all * scale_factor;
    stack_all = stack_all * scale_factor;

    % ---------------------- Common plotting range --------------------
    all_measured = [y_train; y_test; y_all];
    all_predicted = [stack_train; stack_test; stack_all];
    min_val = min([all_measured; all_predicted]);
    max_val = max([all_measured; all_predicted]);
    x_range = linspace(min_val, max_val, 100)';

    % ---------------------- Regression statistics --------------------
    [train_b, train_stats, train_ci, train_pi] = calculate_regression_with_intervals(y_train, stack_train, x_range);
    [test_b,  test_stats,  test_ci,  test_pi]  = calculate_regression_with_intervals(y_test, stack_test, x_range);
    [all_b,   all_stats,   all_ci,   all_pi]   = calculate_regression_with_intervals(y_all, stack_all, x_range);

    % ----------------------------- Figure ----------------------------
    figure('Position', [100, 100, 1400, 900]);
    hold on;

    % Prediction intervals
    fill([x_range; flipud(x_range)], [train_pi(:, 1); flipud(train_pi(:, 2))], ...
         [0.80, 0.90, 1.00], 'EdgeColor', 'none', 'FaceAlpha', 0.20, ...
         'DisplayName', 'Training PI');
    fill([x_range; flipud(x_range)], [test_pi(:, 1); flipud(test_pi(:, 2))], ...
         [1.00, 0.90, 0.80], 'EdgeColor', 'none', 'FaceAlpha', 0.20, ...
         'DisplayName', 'Test PI');
    fill([x_range; flipud(x_range)], [all_pi(:, 1); flipud(all_pi(:, 2))], ...
         [0.90, 1.00, 0.80], 'EdgeColor', 'none', 'FaceAlpha', 0.20, ...
         'DisplayName', 'All-data PI');

    % Confidence intervals
    fill([x_range; flipud(x_range)], [train_ci(:, 1); flipud(train_ci(:, 2))], ...
         [0.60, 0.80, 1.00], 'EdgeColor', 'none', 'FaceAlpha', 0.30, ...
         'DisplayName', 'Training CI');
    fill([x_range; flipud(x_range)], [test_ci(:, 1); flipud(test_ci(:, 2))], ...
         [1.00, 0.70, 0.60], 'EdgeColor', 'none', 'FaceAlpha', 0.30, ...
         'DisplayName', 'Test CI');
    fill([x_range; flipud(x_range)], [all_ci(:, 1); flipud(all_ci(:, 2))], ...
         [0.70, 1.00, 0.60], 'EdgeColor', 'none', 'FaceAlpha', 0.30, ...
         'DisplayName', 'All-data CI');

    % Scatter points
    scatter(y_train, stack_train, 60, 'filled', ...
        'MarkerFaceColor', [0.20, 0.60, 0.80], ...
        'MarkerEdgeColor', 'k', ...
        'MarkerFaceAlpha', 0.70, ...
        'DisplayName', 'Training set');

    scatter(y_test, stack_test, 60, 'filled', ...
        'MarkerFaceColor', [0.80, 0.40, 0.20], ...
        'MarkerEdgeColor', 'k', ...
        'MarkerFaceAlpha', 0.70, ...
        'DisplayName', 'Test set');

    % 1:1 reference line
    perfect_fit = linspace(min_val, max_val, 100);
    plot(perfect_fit, perfect_fit, 'k--', 'LineWidth', 2.5, ...
        'Color', [0.30, 0.30, 0.30], 'DisplayName', '1:1 line');

    % Regression lines
    plot(x_range, train_b(1) + train_b(2) * x_range, '-', ...
        'Color', [0.10, 0.40, 0.70], 'LineWidth', 3.0, 'DisplayName', 'Training RL');
    plot(x_range, test_b(1) + test_b(2) * x_range, '-', ...
        'Color', [0.70, 0.30, 0.10], 'LineWidth', 3.0, 'DisplayName', 'Test RL');
    plot(x_range, all_b(1) + all_b(2) * x_range, '-', ...
        'Color', [0.30, 0.70, 0.20], 'LineWidth', 3.0, 'DisplayName', 'All-data RL');

    grid on;
    box on;
    xlabel('Observed value (kg ha^{-1})', 'FontSize', 16, 'FontWeight', 'bold');
    ylabel('Predicted value (kg ha^{-1})', 'FontSize', 16, 'FontWeight', 'bold');
    legend('Location', 'northwest', 'FontSize', 14, 'NumColumns', 1);

    axis([min_val, max_val, min_val, max_val]);
    axis equal;

    add_statistics_boxes(train_stats, test_stats, all_stats);
    hold off;

    % ---------------------- Console summary --------------------------
    fprintf('\n=== Stacking model summary with interval estimates ===\n');
    fprintf('Training set - R^2: %.4f, RMSE: %.4f, Slope: %.4f, Intercept: %.4f, Standard error: %.4f, N: %d\n', ...
        train_stats.R2, train_stats.RMSE, train_stats.slope, train_stats.intercept, train_stats.standard_error, train_stats.n);
    fprintf('Test set - R^2: %.4f, RMSE: %.4f, Slope: %.4f, Intercept: %.4f, Standard error: %.4f, N: %d\n', ...
        test_stats.R2, test_stats.RMSE, test_stats.slope, test_stats.intercept, test_stats.standard_error, test_stats.n);
    fprintf('All data - R^2: %.4f, RMSE: %.4f, Slope: %.4f, Intercept: %.4f, Standard error: %.4f, N: %d\n\n', ...
        all_stats.R2, all_stats.RMSE, all_stats.slope, all_stats.intercept, all_stats.standard_error, all_stats.n);
end

function [b, stats, ci, pi] = calculate_regression_with_intervals(x, y, x_range)
%CALCULATE_REGRESSION_WITH_INTERVALS Fit regression and compute intervals.
%
% INPUTS
%   x       : observed values
%   y       : predicted values
%   x_range : x-axis range for plotting fitted curves and intervals
%
% OUTPUTS
%   b     : regression coefficients [intercept; slope]
%   stats : structure containing fit statistics
%   ci    : confidence interval bounds for the mean response
%   pi    : prediction interval bounds for individual observations

    valid_idx = ~isnan(x) & ~isnan(y);
    x = x(valid_idx);
    y = y(valid_idx);

    X = [ones(size(x)), x];
    [b, bint, ~, ~, regress_stats] = regress(y, X);
    y_pred = X * b;

    n = length(y);
    p = 1;

    stats = struct();
    stats.R2 = regress_stats(1);
    stats.RMSE = sqrt(mean((y - y_pred).^2));
    stats.MAE = mean(abs(y - y_pred));

    nonzero_idx = y ~= 0;
    if any(nonzero_idx)
        stats.MAPE = mean(abs((y(nonzero_idx) - y_pred(nonzero_idx)) ./ y(nonzero_idx))) * 100;
    else
        stats.MAPE = NaN;
    end

    stats.RPD = std(y) / stats.RMSE;
    stats.slope = b(2);
    stats.intercept = b(1);
    stats.slope_CI = bint(2, :);
    stats.intercept_CI = bint(1, :);
    stats.n = n;

    alpha = 0.05;
    X_range = [ones(size(x_range)), x_range];
    y_pred_range = X_range * b;

    s_yx = sqrt(sum((y - y_pred).^2) / (n - p - 1));
    cov_b = inv(X' * X) * s_yx^2;
    se_fit = sqrt(diag(X_range * cov_b * X_range'));
    t_val = tinv(1 - alpha / 2, n - p - 1);

    ci_lower = y_pred_range - t_val * se_fit;
    ci_upper = y_pred_range + t_val * se_fit;
    ci = [ci_lower, ci_upper];

    pred_lower = y_pred_range - t_val * s_yx * sqrt(1 + diag(X_range * inv(X' * X) * X_range'));
    pred_upper = y_pred_range + t_val * s_yx * sqrt(1 + diag(X_range * inv(X' * X) * X_range'));
    pi = [pred_lower, pred_upper];

    stats.standard_error = s_yx;
end

function add_statistics_boxes(train_stats, test_stats, all_stats)
%ADD_STATISTICS_BOXES Add summary text boxes to the current figure.

    train_text = { ...
        'Training set statistics:', ...
        sprintf('R^2 = %.4f', train_stats.R2), ...
        sprintf('RMSE = %.4f', train_stats.RMSE), ...
        sprintf('MAE = %.4f', train_stats.MAE), ...
        sprintf('MAPE = %.2f%%', train_stats.MAPE), ...
        sprintf('RPD = %.4f', train_stats.RPD), ...
        sprintf('Slope = %.4f', train_stats.slope), ...
        sprintf('Intercept = %.4f', train_stats.intercept), ...
        sprintf('N = %d', train_stats.n)};

    test_text = { ...
        'Test set statistics:', ...
        sprintf('R^2 = %.4f', test_stats.R2), ...
        sprintf('RMSE = %.4f', test_stats.RMSE), ...
        sprintf('MAE = %.4f', test_stats.MAE), ...
        sprintf('MAPE = %.2f%%', test_stats.MAPE), ...
        sprintf('RPD = %.4f', test_stats.RPD), ...
        sprintf('Slope = %.4f', test_stats.slope), ...
        sprintf('Intercept = %.4f', test_stats.intercept), ...
        sprintf('N = %d', test_stats.n)};

    all_text = { ...
        'All-data statistics:', ...
        sprintf('R^2 = %.4f', all_stats.R2), ...
        sprintf('RMSE = %.4f', all_stats.RMSE), ...
        sprintf('MAE = %.4f', all_stats.MAE), ...
        sprintf('MAPE = %.2f%%', all_stats.MAPE), ...
        sprintf('RPD = %.4f', all_stats.RPD), ...
        sprintf('Slope = %.4f', all_stats.slope), ...
        sprintf('Intercept = %.4f', all_stats.intercept), ...
        sprintf('N = %d', all_stats.n)};

    annotation('textbox', [0.02, 0.60, 0.22, 0.35], ...
        'String', train_text, ...
        'EdgeColor', [0.20, 0.60, 0.80], ...
        'BackgroundColor', [0.90, 0.95, 1.00], ...
        'FontSize', 9, ...
        'FontWeight', 'bold', ...
        'LineWidth', 2);

    annotation('textbox', [0.02, 0.30, 0.22, 0.35], ...
        'String', test_text, ...
        'EdgeColor', [0.80, 0.40, 0.20], ...
        'BackgroundColor', [1.00, 0.95, 0.90], ...
        'FontSize', 9, ...
        'FontWeight', 'bold', ...
        'LineWidth', 2);

    annotation('textbox', [0.02, 0.00, 0.22, 0.35], ...
        'String', all_text, ...
        'EdgeColor', [0.40, 0.80, 0.30], ...
        'BackgroundColor', [0.95, 1.00, 0.90], ...
        'FontSize', 9, ...
        'FontWeight', 'bold', ...
        'LineWidth', 2);
end
