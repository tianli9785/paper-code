function plot_correlation_heatmap()
    % Define variable names.
    variables = {'LPC', 'SPC', 'GPC', 'LB', 'SB', 'GB', 'LPU', 'SPU', 'GPU', 'TSPU'};

    % Correlation coefficient matrix (10 variables × 6 indicators).
    correlation_data = [
        0.445222663492021, 0.493978074269942, 0.579437884256785, 0.673626583640671, 0.535571705946161, 0.622299372236596;
        0.524264235172078, 0.676680352295364, 0.803527695478088, 0.84848193068964,  0.764849016980263, 0.783656427374315;
        0.303967933427026, 0.247912944411411, 0.224829944118267, 0.295390108139174, 0.264729890999218, 0.264167045975269;
        0.422398893149006, 0.570261911179816, 0.539360843291265, 0.598529574968101, 0.512566360528754, 0.590394107286876;
        0.451789072541715, 0.540754194998653, 0.571519915940315, 0.615639797083131, 0.549714172740393, 0.628550280817809;
        0.465585910334329, 0.583696497737001, 0.694847712546608, 0.739325404518959, 0.640307410370509, 0.671246766305966;
        0.146523454543141, 0.256228854462149, 0.237444725094971, 0.266025575818065, 0.322885174301951, 0.256526539875185;
        0.553215050007591, 0.641817359141899, 0.772776907053436, 0.807052701405991, 0.732316263510674, 0.750278918582179;
        0.450419000652878, 0.598438072691798, 0.633995838687254, 0.679187615487722, 0.568936011555881, 0.620762114089284;
        0.364602874460468, 0.399324416309602, 0.499753265440494, 0.520879284002442, 0.458311048973555, 0.538258122171628
    ];

    % Matrix of p-values.
    pvalue_data = [
        3.7934385960871e-10,  1.8320528904641e-12,  1.57062716625536e-17, 3.72452178602357e-25, 9.44705188221295e-15, 1.11221183276948e-20;
        4.24951312146407e-14, 1.88910519882238e-25, 5.86887321629348e-42, 4.51264871196536e-51, 7.90108536856139e-36, 1.18851322035476e-38;
        3.34904058593971e-05, 0.000792311053008389, 0.00241062276631057,  5.68139243188289e-05, 0.000329073333515048, 0.000339217002215113;
        3.49714165394546e-09, 6.48385497310892e-17, 5.63584424109915e-15, 7.09774397068963e-19, 1.90066755531206e-13, 2.72328999263456e-18;
        1.94084681370052e-10, 4.65324091313393e-15, 5.35235972320548e-17, 3.69239795429146e-20, 1.32870160491185e-15, 3.51210619460966e-21;
        4.52829384005869e-11, 8.01090842100077e-18, 2.79443208839321e-27, 2.14775737272046e-32, 3.7374474566393e-22,  6.28619733280027e-25;
        0.049677639399804,    0.000516856763172436, 0.00132971548997813,  0.000306782525689263, 9.83495713433232e-06, 0.00050887879946346;
        8.05929318963214e-16, 2.78319567913862e-22, 5.50727160165447e-37, 1.38798048326966e-42, 1.60522291068914e-31, 8.11153840312843e-34;
        2.23475062639674e-10, 7.20743464950376e-19, 1.25922855472226e-21, 1.07531925550515e-25, 7.92926802085914e-17, 1.47090808713075e-20;
        4.8568800115182e-07,  2.80920422916944e-08, 9.19510136660725e-13, 6.5941475030105e-14,  9.83388485055723e-11, 6.55444817690685e-15
    ];

    % Column labels.
    column_labels = {'Jointing \newline Spectral', 'Jointing \newline Texture', ...
                    'Grain Filling \newline Spectral', 'Grain Filling \newline Texture', ...
                    'Milky Ripe \newline Spectral', 'Milky Ripe \newline Texture'};

    % Create figure.
    figure('Position', [100, 100, 900, 700]);

    % Define a more publication-oriented diverging color scheme (blue to red).
    colors = [0.2, 0.2, 0.8;   % dark blue
              0.4, 0.4, 1.0;   % blue
              0.8, 0.8, 1.0;   % light blue
              1.0, 1.0, 1.0;   % white
              1.0, 0.8, 0.8;   % light red
              1.0, 0.4, 0.4;   % red
              0.8, 0.2, 0.2];  % dark red

    % Generate a custom colormap.
    custom_colormap = interp1(linspace(0,1,7), colors, linspace(0,1,256));

    % Plot heatmap.
    imagesc(correlation_data);
    colormap(custom_colormap);
    colorbar;
    caxis([0, 1]); % Set the color range.

    % Set axis properties.
    set(gca, 'XTick', 1:6, 'XTickLabel', column_labels, ...
             'YTick', 1:10, 'YTickLabel', variables, ...
             'FontSize', 11, 'FontWeight', 'bold');

    % Add grid lines.
    grid on;
    set(gca, 'GridColor', [0.3, 0.3, 0.3], 'GridAlpha', 0.3);

    % Add correlation coefficients and significance symbols to each cell.
    for i = 1:size(correlation_data, 1)
        for j = 1:size(correlation_data, 2)
            corr_val = correlation_data(i, j);
            p_val = pvalue_data(i, j);

            % Determine significance markers.
            if p_val < 0.001
                stars = '***';
                text_color = 'k';
            elseif p_val < 0.01
                stars = '**';
                text_color = 'k';
            elseif p_val < 0.05
                stars = '*';
                text_color = 'k';
            else
                stars = '';
                text_color = 'k';
            end

            % Display coefficient and significance marker.
            text_str = sprintf('%.2f%s', corr_val, stars);
            text(j, i, text_str, ...
                 'HorizontalAlignment', 'center', ...
                 'VerticalAlignment', 'middle', ...
                 'FontName', 'Times New Roman', ...
                 'FontSize', 12, ...
                 'FontWeight', 'bold', ...
                 'Color', text_color);
        end
    end

    % Set title and axis labels.
    title('Correlation Heatmap with Statistical Significance', ...
          'FontName', 'Times New Roman', 'FontSize', 14, 'FontWeight', 'bold', 'Padding', 10);
    xlabel('Growth Stages and Index Types', 'FontName', 'Times New Roman', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('Physiological Parameters', 'FontName', 'Times New Roman', 'FontSize', 12, 'FontWeight', 'bold');

    % Add annotation for significance symbols.
    annotation('textbox', [0.02, 0.02, 0.3, 0.05], ...
               'String', 'Significance: *p<0.05, **p<0.01, ***p<0.001', ...
               'FontSize', 9, 'EdgeColor', 'none', ...
               'BackgroundColor', [0.95, 0.95, 0.95]);

    % Refine figure appearance.
    set(gca, 'TickLength', [0, 0]);
    axis equal tight;
end

% Run the function if needed.
% plot_correlation_heatmap();
