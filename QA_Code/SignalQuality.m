% SignalQuality.m
% Calcula metricas de calidad de senal EEG (NaN/Inf y alta amplitud)
% para cada archivo .edf disponible en la carpeta del script.
% Genera figuras por sujeto y un CSV resumen con ONS, OHA, ODQ.

clear; close all; clc;

% ---- Configuracion ----
script_dir = fileparts(mfilename('fullpath'));
if isempty(script_dir); script_dir = pwd; end

files = dir(fullfile(script_dir, '*.edf'));
if isempty(files)
    error('No se encontraron archivos .edf en: %s', script_dir);
end

results_dir = fullfile(script_dir, 'Results');
if ~exist(results_dir, 'dir'); mkdir(results_dir); end

n_files = numel(files);
results = struct('subject', {}, 'ONS', {}, 'OHA', {}, 'ODQ', {});

% ---- Loop sobre los 3 sujetos ----
for i = 1:n_files
    edf_path = fullfile(files(i).folder, files(i).name);
    [~, base] = fileparts(files(i).name);
    fprintf('\n[%d/%d] Procesando %s ...\n', i, n_files, files(i).name);

    % ---- Carga del .edf ----
    EEG = load_edf_as_eeg(edf_path);

    % ---- Calidad ----
    qMatrixNan = functions.eeg_quality_nan(EEG.data, EEG.srate);
    qMatrixSD  = functions.eeg_quality_high_amplitude(EEG.data, EEG.srate);

    correct_Nan = nnz(qMatrixNan == 0);
    correct_SD  = nnz(qMatrixSD  == 0);
    total       = numel(qMatrixNan);

    ONS = 100 * correct_Nan / total;
    OHA = 100 * correct_SD  / total;
    ODQ = 100 * (correct_Nan + correct_SD) / (4 * total);

    results(i).subject = files(i).name;
    results(i).ONS = ONS;
    results(i).OHA = OHA;
    results(i).ODQ = ODQ;

    fprintf('  ONS=%.2f%%  OHA=%.2f%%  ODQ=%.2f%%\n', ONS, OHA, ODQ);

    % ---- Figura por sujeto ----
    fig = figure('Visible', 'off', 'Position', [100 100 1100 450]);
    subplot(1,2,1);
    imagesc(qMatrixNan); colorbar; clim([0 1]);
    title(sprintf('NaN/Inf - %s', base), 'Interpreter', 'none');
    xlabel('Ventana (s)'); ylabel('Canal');

    subplot(1,2,2);
    imagesc(qMatrixSD); colorbar; clim([0 1]);
    title(sprintf('Amplitud - %s', base), 'Interpreter', 'none');
    xlabel('Ventana (s)'); ylabel('Canal');

    saveas(fig, fullfile(results_dir, [base '_quality.png']));
    close(fig);
end

% ---- Resumen ----
T = struct2table(results);
disp(T);
writetable(T, fullfile(results_dir, 'quality_summary.csv'));
fprintf('\nResultados guardados en: %s\n', results_dir);


% =====================================================================
function EEG = load_edf_as_eeg(edf_path)
% Carga un .edf y devuelve una estructura tipo EEGLAB con campos:
%   EEG.data   [canales x muestras]
%   EEG.srate  frecuencia de muestreo (Hz)
%   EEG.chanlocs(k).labels  etiquetas de canal

    info = edfinfo(edf_path);
    tt   = edfread(edf_path);

    n_ch = numel(info.SignalLabels);
    sig_cells = tt{:, 1:n_ch};
    n_records = size(sig_cells, 1);

    samples_per_record = zeros(1, n_ch);
    for c = 1:n_ch
        samples_per_record(c) = numel(sig_cells{1, c});
    end
    if numel(unique(samples_per_record)) ~= 1
        error('Canales con distinta tasa de muestreo no soportados.');
    end
    spr = samples_per_record(1);

    data = zeros(n_ch, spr * n_records);
    for c = 1:n_ch
        col = vertcat(sig_cells{:, c});
        data(c, :) = col(:)';
    end

    srate = double(spr) / seconds(info.DataRecordDuration);

    EEG = struct();
    EEG.data  = data;
    EEG.srate = srate;
    EEG.chanlocs = struct('labels', {});
    for c = 1:n_ch
        EEG.chanlocs(c).labels = char(info.SignalLabels(c));
    end
    EEG.nbchan = n_ch;
    EEG.pnts   = size(data, 2);
    EEG.trials = 1;
    EEG.xmin   = 0;
    EEG.xmax   = (EEG.pnts - 1) / EEG.srate;
end
