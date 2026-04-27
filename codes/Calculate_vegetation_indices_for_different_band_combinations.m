clc;
clear;

t1 = clock;

% Specify the input and output directories.
input_folder = 'C:\Users\dell\Desktop\DATA\UAV';
output_folder = 'C:\Users\dell\Desktop\DATA\VIs';

% Retrieve all Excel files in the input directory (.xlsx format).
excel_files = dir(fullfile(input_folder, '*.xlsx'));
num_files = length(excel_files);

% Define vegetation index formulas.
computeARVI  = @(band1, band2, band3) (band2 - (2 * band1 - band3)) ./ (band2 + (2 * band1 - band3));
computeDVI   = @(band1, band2) (band2 - band1);
computeEVI   = @(band1, band2, band3) 2.5 * (band2 - band1) ./ (band2 + 6 * band1 - 7.5 * band3 + 1);
computeMCARI = @(band1, band2, band3) ((band2 - band1) - 0.2 * (band2 - band3)) .* (band2 ./ band1);
computeMSAVI = @(band1, band2) (2 * band2 + 1 - sqrt((2 * band2 + 1).^2 - 8 * (band2 - band1))) / 2;
computeMSR   = @(band1, band2) (band2 ./ band1 - 1) ./ sqrt(band2 ./ band1 + 1);
computeNDVI  = @(band1, band2) (band2 - band1) ./ (band2 + band1);
computeOSAVI = @(band1, band2) 1.16 * (band2 - band1) ./ (band2 - band1 + 0.16);
computeRVI   = @(band1, band2) band2 ./ band1;
computeRDVI  = @(band1, band2) (band2 - band1) ./ sqrt(band2 + band1);
computeSAVI  = @(band1, band2) 1.5 * (band2 - band1) ./ (band2 + band1 + 0.5);
computeVARI  = @(band1, band2, band3) (band2 - band1) ./ (band2 + band1 - band3);

% Iterate over each Excel file.
for file_idx = 1:num_files
    current_file = excel_files(file_idx).name;
    fprintf('Processing file: %s\n', current_file);

    input_path = fullfile(input_folder, current_file);
    [~, base_name, ~] = fileparts(current_file);
    output_path = fullfile(output_folder, [base_name '_AllBandCombinations.xlsx']);

    if exist(output_path, 'file')
        delete(output_path);
    end

    [~, sheet_names] = xlsfinfo(input_path);
    num_sheets = length(sheet_names);

    for sheet_idx = 1:num_sheets
        current_sheet = sheet_names{sheet_idx};
        fprintf('  Processing worksheet: %s\n', current_sheet);

        data = xlsread(input_path, current_sheet);
        data = data(:, 1:end);
        num_bands = size(data, 2);

        if num_bands < 2
            warning('Worksheet %s contains fewer than two columns; calculation is skipped.', current_sheet);
            continue;
        end

        all_results = table();

        % Compute all two-band combinations.
        for b1 = 1:num_bands
            for b2 = 1:num_bands
                if b1 == b2
                    continue;
                end

                band1 = data(:, b1);
                band2 = data(:, b2);

                dvi   = computeDVI(band1, band2);
                msavi = computeMSAVI(band1, band2);
                msr   = computeMSR(band1, band2);
                ndvi  = computeNDVI(band1, band2);
                osavi = computeOSAVI(band1, band2);
                rvi   = computeRVI(band1, band2);
                rdvi  = computeRDVI(band1, band2);
                savi  = computeSAVI(band1, band2);

                combo_str = sprintf('B%d_B%d', b1, b2);
                temp_table = table( ...
                    dvi, msavi, msr, ndvi, osavi, rvi, rdvi, savi, ...
                    'VariableNames', ...
                    {['DVI_' combo_str], ...
                     ['MSAVI_' combo_str], ...
                     ['MSR_' combo_str], ...
                     ['NDVI_' combo_str], ...
                     ['OSAVI_' combo_str], ...
                     ['RVI_' combo_str], ...
                     ['RDVI_' combo_str], ...
                     ['SAVI_' combo_str]});

                all_results = [all_results, temp_table];
            end
        end

        % Compute all three-band combinations.
        if num_bands >= 3
            for b1 = 1:num_bands
                for b2 = 1:num_bands
                    for b3 = 1:num_bands
                        if b1 == b2 || b1 == b3 || b2 == b3
                            continue;
                        end

                        band1 = data(:, b1);
                        band2 = data(:, b2);
                        band3 = data(:, b3);

                        evi   = computeEVI(band1, band2, band3);
                        vari  = computeVARI(band2, band1, band3); % green, red, blue
                        arvi  = computeARVI(band1, band2, band3); % red, nir, blue
                        mcari = computeMCARI(band1, band2, band3);

                        combo_str = sprintf('B%d_B%d_B%d', b1, b2, b3);
                        temp_table = table( ...
                            evi, vari, arvi, mcari, ...
                            'VariableNames', ...
                            {['EVI_' combo_str], ...
                             ['VARI_' combo_str], ...
                             ['ARVI_' combo_str], ...
                             ['MCARI_' combo_str]});

                        all_results = [all_results, temp_table];
                    end
                end
            end
        end

        % Compute all four-band combinations.
        if num_bands >= 4
            for b1 = 1:num_bands
                for b2 = 1:num_bands
                    for b3 = 1:num_bands
                        for b4 = 1:num_bands
                            if length(unique([b1 b2 b3 b4])) < 4
                                continue;
                            end

                            band1 = data(:, b1);
                            band2 = data(:, b2);
                            band3 = data(:, b3);
                            band4 = data(:, b4);

                            % Example user-defined four-band index.
                            custom4 = (band2 - band1) ./ (band3 + band4 + eps);

                            combo_str = sprintf('B%d_B%d_B%d_B%d', b1, b2, b3, b4);
                            temp_table = table( ...
                                custom4, ...
                                'VariableNames', ...
                                {['Custom4_' combo_str]});

                            all_results = [all_results, temp_table];
                        end
                    end
                end
            end
        end

        % Compute all five-band combinations.
        if num_bands >= 5
            for b1 = 1:num_bands
                for b2 = 1:num_bands
                    for b3 = 1:num_bands
                        for b4 = 1:num_bands
                            for b5 = 1:num_bands
                                if length(unique([b1 b2 b3 b4 b5])) < 5
                                    continue;
                                end

                                band1 = data(:, b1);
                                band2 = data(:, b2);
                                band3 = data(:, b3);
                                band4 = data(:, b4);
                                band5 = data(:, b5);

                                % Example user-defined five-band index.
                                custom5 = (band2 - band1) ./ (band3 + band4 + band5 + eps);

                                combo_str = sprintf('B%d_B%d_B%d_B%d_B%d', b1, b2, b3, b4, b5);
                                temp_table = table( ...
                                    custom5, ...
                                    'VariableNames', ...
                                    {['Custom5_' combo_str]});

                                all_results = [all_results, temp_table];
                            end
                        end
                    end
                end
            end
        end

        % Write results to Excel.
        writetable(all_results, output_path, 'Sheet', current_sheet);
    end

    fprintf('  File %s has been processed successfully. Results were saved to: %s\n', current_file, output_path);
end

fprintf('All files have been processed successfully. Results are available in: %s\n', output_folder);
t2 = clock;
tim = etime(t2, t1);
disp(['------------------ Total runtime: ', num2str(tim), ' seconds -------------------']);
