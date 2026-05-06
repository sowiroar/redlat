function qualityMatrix = eeg_quality_nan(eeg_signal, sample_rate)
    % eeg_signal: Una matriz donde cada fila es un canal y cada columna es un punto de datos.
    % sample_rate: La tasa de muestreo de la se�al de EEG.

    [num_channels, num_data_points] = size(eeg_signal);

    num_windows = floor(num_data_points / sample_rate);

    qualityMatrix = zeros(num_channels, num_windows);

    for win = 1:num_windows
        start_idx = (win - 1) * sample_rate + 1;
        end_idx = win * sample_rate;

        current_window = eeg_signal(:, start_idx:end_idx);

        for ch = 1:num_channels
            if any(isnan(current_window(ch, :)))
                qualityMatrix(ch, win) = 1;
            end

            if any(isinf(current_window(ch, :)))
                qualityMatrix(ch, win) = 1;
            end
        end
    end
end
