function qualityMatrix = eeg_quality_high_amplitude(eeg_signal, sample_rate)

    % eeg_signal: matriz donde cada fila es un canal y cada columna es un punto de datos.
    % sample_rate: tasa de muestreo de la señal EEG.

    [num_channels, num_data_points] = size(eeg_signal);


    num_windows = round(num_data_points / sample_rate);

    qualityMatrix = zeros(num_channels, num_windows);
    stdMatrix = zeros(num_channels, num_windows);

    for win = 1:num_windows

        start_idx = (win - 1) * sample_rate + 1;

        end_idx = win * sample_rate - 1;


        end_idx = min(end_idx, num_data_points);

        current_window = eeg_signal(:, start_idx:end_idx);

        for ch = 1:num_channels

            stdMatrix(ch, win) = nanmean(current_window(ch, :));

        end
    end


    for win = 1:num_windows

        for ch = 1:num_channels


            global_mean = mean(stdMatrix(:));
            global_std = std(stdMatrix(:));


            value = (stdMatrix(ch, win) - global_mean) / global_std;


            if value > 4 || stdMatrix(ch, win) > 150 || isinf(stdMatrix(ch, win)) || isnan(stdMatrix(ch, win))


                qualityMatrix(ch, win) = 0;

            else


                qualityMatrix(ch, win) = 1;

            end
        end
    end
end