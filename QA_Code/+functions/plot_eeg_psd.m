function plot_eeg_psd(eeg_signal, sample_rate, eeg, eeg_signal_1, sample_rate_1, eeg_1)

    num_channels = size(eeg_signal, 1);


    window = hamming(sample_rate); % Ventana Hamming
    noverlap = floor(length(window)/2); % 50% de solapamiento
    nfft = 2^nextpow2(length(window)); % N�mero de puntos FFT

    num_channels_1 = size(eeg_signal_1, 1);


    window_1 = hamming(sample_rate_1); % Ventana Hamming
    noverlap_1 = floor(length(window_1)/2); % 50% de solapamiento
    nfft_1 = 2^nextpow2(length(window_1)); % N�mero de puntos FFT

    figure('Renderer', 'painters', 'Position', [10 10 800 800])
    for ch = 1:16
        n = eeg_signal(ch, :);
        n(~isfinite(n)) = max(n);
        [Pxx, freqs] = pwelch(n, window, noverlap, nfft, sample_rate);

        n = eeg_signal_1(ch, :);
        n(~isfinite(n)) = max(n);
        [Pxx_1, freqs_1] = pwelch(n, window_1, noverlap_1, nfft_1, sample_rate_1);
        
        subplot(4, 4, ch);
        plot(freqs, 10*log10(Pxx));
        hold
        plot(freqs_1, 10*log10(Pxx_1));
        title(['' num2str(eeg.chanlocs(ch).labels)]);
        xlabel('(Hz)');
        ylabel('PSD (dB/Hz)');
        xlim([0 30]);        
    end
saveas(gcf, 'Results/PSD.png')

end
