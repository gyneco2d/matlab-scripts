function [AlphaEEG] = collectAlpha()
    % collectAlpha() - Collect alpha waves (8-13Hz) into structure 'AlphaEEG'

    % Load EEG data from .mat file
    [filename, filepath] = uigetfile('*.mat');
    if ~ischar(filename) || ~ischar(filepath)
        error('no files selected');
    end
    load(strcat(filepath, filename));

    % Initialize
    % sampling frequency: 2048Hz
    fs = 2048;
    % electrode channels
    channels = [1:32];
    % fft interval: 2sec
    interval = 2;
    % alpha wave band: 8-13Hz
    alphaBand = [8:13];

    n = fs * interval;
    f = (0:n-1)*(fs/n);
    for iState = 1:size(ALLEEG, 2)
        totalTime = length(ALLEEG(iState).data(1, :)) / fs;
        nComponent = fix(totalTime - 1);
        stepsize = n / 2;
        alphaBandIndex = calcFreqIndex(alphaBand, f);
        AlphaEEG(iState).setname = ALLEEG(iState).setname;
        AlphaEEG(iState).axis = f;
        AlphaEEG(iState).freq_distribution = zeros(32, n);
        AlphaEEG(iState).timeseries_rootmean = zeros(32, nComponent);
        AlphaEEG(iState).raw = zeros(32, length(alphaBandIndex)*nComponent);
        AlphaEEG(iState).rootmean = zeros(32, 1);

        for channel = channels
            for iComponent = 1:nComponent
                first = (iComponent-1)*stepsize + 1;
                last = first + (n-1);
                x = ALLEEG(iState).data(channel, first:last);
                y = fft(x);
                power = abs(y).^2/n;

                AlphaEEG(iState).freq_distribution(channel, :) = AlphaEEG(iState).freq_distribution(channel, :) + power;
                for iAlpha = 1:length(alphaBandIndex)
                    AlphaEEG(iState).raw(channel, iAlpha + (iComponent-1)*length(alphaBandIndex)) = power(alphaBandIndex(iAlpha));
                end
                AlphaEEG(iState).timeseries_rootmean(channel, iComponent) = sqrt(mean(power(alphaBandIndex)));
            end
            AlphaEEG(iState).freq_distribution(channel, :) = AlphaEEG(iState).freq_distribution(channel, :) / nComponent;
            AlphaEEG(iState).rootmean(channel, 1) = sqrt(mean(AlphaEEG(iState).raw(channel, :)));
        end
    end
end