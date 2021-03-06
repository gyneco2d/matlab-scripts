function [EEGFREQS] = fftEEGdata(ALLEEG)
    % fftEEGdata() - FFT EEGLAB datasets into structure 'EEGFREQS'
    %
    % Usage:
    %   >> fftEEGdata( ALLEEG );
    %
    % Inputs:
    %   ALLEEG - [structure] EEGLAB dataset structure
    %
    % structure array:
    %   EEGFREQS setname                          - dataset name
    %            axis                             - frequency axis
    %            distribution                     - EEG power for each frequency 
    %            timeseries_distribution          - time series EEG power for each frequency
    %            percentage                       - EEG percentages
    %            timeseries_percentage            - timeseries EEG percentages
    %            timeseries_{each EEG}            - square root of average EEG waves for fft window
    %            section_{each EEG}               - average of timeseries_{each EEG}_power for section
    %            normalized_timeseries_{each EEG} - normalized section_{each EEG}_power (respect to raw average)
    %            normalized_section_{each EEG}    - normalized alpha waves (respect to raw average)

    % Import constants
    import('constants.ProjectConstants');

    waves = {'theta', 'alpha', 'beta', 'gamma'};
    n = ProjectConstants.BioSemiSamplingRate * ProjectConstants.FFTwindowSize;
    f = (0:n-1)*(ProjectConstants.BioSemiSamplingRate/n);
    waveIndex = {
        getIndexOfFreqAxis(ProjectConstants.ThetaWaves, f) ...
        getIndexOfFreqAxis(ProjectConstants.AlphaWaves, f) ...
        getIndexOfFreqAxis(ProjectConstants.BetaWaves, f) ...
        getIndexOfFreqAxis(ProjectConstants.GammaWaves, f)
    };
    for section = 1:size(ALLEEG, 2)
        totalTime = length(ALLEEG(section).data(1, :)) / ...
                    ProjectConstants.BioSemiSamplingRate;
        nComponent = fix(totalTime - 1);
        stepsize = n / 2;

        % Initialize EEGFREQS structure
        EEGFREQS(section).setname = ALLEEG(section).setname;
        EEGFREQS(section).axis = f;
        EEGFREQS(section).distribution = zeros(32, n);
        EEGFREQS(section).timeseries_distribution(nComponent) = {[]};
        EEGFREQS(section).percentage = struct();
        EEGFREQS(section).timeseries_percentage = struct();
        for wave = waves
            EEGFREQS(section).(['section_' char(wave)]) = zeros(32, 1);
            EEGFREQS(section).(['timeseries_' char(wave)]) = zeros(32, nComponent);
        end

        for channel = ProjectConstants.AllElectrodes
            for iComponent = 1:nComponent
                % FFT EEG data in window
                first = (iComponent-1)*stepsize + 1;
                last = first + (n-1);
                x = ALLEEG(section).data(channel, first:last);
                y = fft(x);
                power = abs(y).^2/n;

                % Sum to find the average frequency distribution
                EEGFREQS(section).distribution(channel, :) = ...
                    EEGFREQS(section).distribution(channel, :) + power;
                % Collect frequency distribution for each fft window
                EEGFREQS(section).timeseries_distribution(iComponent) = ...
                    {...
                        [cell2mat(EEGFREQS(section).timeseries_distribution(iComponent));
                        power]...
                    };

                % Collect each EEG wave power for each fft window
                for iWave = 1:length(waves)
                    waveRange = cell2mat(waveIndex(iWave));
                    EEGFREQS(section).(['timeseries_', char(waves(iWave))])(channel, iComponent) = ...
                        sqrt(mean(power(waveRange)));
                end
            end
            % Calculate the average frequency distribution between fft window
            EEGFREQS(section).distribution(channel, :) = ...
                EEGFREQS(section).distribution(channel, :) / nComponent;

            % Calculate section average of each EEG wave power
            for wave = waves
                EEGFREQS(section).(['section_' char(wave)])(channel, 1) = ...
                    mean(EEGFREQS(section).(['timeseries_' char(wave)])(channel, :));
            end
        end

        % Calculate the percentage of each EEG
        fftpower = EEGFREQS(section).distribution;
        freqaxis = EEGFREQS(section).axis;
        [...
            EEGFREQS(section).percentage.theta, ...
            EEGFREQS(section).percentage.alpha,...
            EEGFREQS(section).percentage.beta, ...
            EEGFREQS(section).percentage.gamma ...
        ] = calcEEGpercentage(fftpower, freqaxis);

        % Collect the percentage of each EEG for each fft window
        for iComponent = 1:nComponent
            [...
                EEGFREQS(section).timeseries_percentage(iComponent).theta,...
                EEGFREQS(section).timeseries_percentage(iComponent).alpha,...
                EEGFREQS(section).timeseries_percentage(iComponent).beta,...
                EEGFREQS(section).timeseries_percentage(iComponent).gamma...
            ] = calcEEGpercentage(...
                    cell2mat(EEGFREQS(section).timeseries_distribution(iComponent)), ...
                    EEGFREQS(section).axis);
        end

        % Create normalized data
        for wave = waves
            standard = mean(EEGFREQS(section).(['timeseries_' char(wave)]), 'all');
            EEGFREQS(section).(['normalized_timeseries_' char(wave)]) = ...
                EEGFREQS(section).(['timeseries_' char(wave)]) / standard;
            for channel = ProjectConstants.AllElectrodes
                EEGFREQS(section).(['normalized_section_' char(wave)])(channel, 1) = ...
                    mean(EEGFREQS(section).(['normalized_timeseries_' char(wave)])(channel, :));
            end
        end
    end
end
