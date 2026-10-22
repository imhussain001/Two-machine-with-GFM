%% RUN_STUDYA  -  STUDY A - effect of supplementary control (no GFM)
% Compares Case 1 (primary control only) with Case 2 (primary + AGC); no GFM.
%
% All models used here are in this folder; this script does not depend on
% any other folder. Same load step in every case (set in the models):
% dP_L2_MW = -100 MW at t = 1 s, bus 2 (load rejection in Area 1).
% Primary control (governor droop) is active in all cases.
%
% Output (saved in this folder): the comparison table in the Command
% Window and studyA_comparison.png, studyA_SG_frequencies.png, studyA_power.png, studyA_tie_line.png.

clear; clc;

study_title = 'Study A - without vs. with supplementary control (no GFM)';
prefix      = 'studyA';
%           model                    overrides   legend name                  table column
cases = {   'case1_primary_control', {}, 'Case 1: no supplementary control', 'Case 1 (no AGC)';
    'case2_primary_AGC', {}, 'Case 2: supplementary control', 'Case 2 (AGC)'   };
case_colour       = [1 2];     % same colour for a case in every study
with_gfm          = false;      % show GFM active / reactive power
make_study_figure = true;

here = fileparts(mfilename('fullpath'));
col  = {[0 0.45 0.74], [0.85 0.33 0.10], [0.47 0.67 0.19], [0.49 0.18 0.56]};   % colour per case

%% Run the cases (models are in this folder)
for k = 1:size(cases, 1)
    R(k) = run_case(here, cases{k,1}, cases{k,2});   %#ok<SAGROW>
    R(k).name  = cases{k,3};
    R(k).short = cases{k,4};
end
c = col(case_colour);

%% Table
print_table('STUDY A - effect of supplementary control (no GFM)', R);

%% Figures
if make_study_figure
    plot_study(study_title, R, c, with_gfm, fullfile(here, [prefix '_comparison.png']));
end
names = {R.name};

% Frequency of each synchronous generator
fig = figure('Color', 'w', 'Position', [80 80 1000 420]);
tl  = tiledlayout(1, 2, 'TileSpacing', 'compact');
title(tl, [study_title ' - rotor frequency of each SG']);
for g = 1:2
    nexttile; hold on; grid on;
    for k = 1:numel(R), plot(R(k).t, R(k).f(:,g), 'Color', c{k}, 'LineWidth', 1.3); end
    xlabel('Time [s]'); ylabel('f [Hz]'); title(sprintf('SG%d', g));
    if g == 1, legend(names, 'Location', 'best', 'FontSize', 8); end
end
save_fig(fig, fullfile(here, [prefix '_SG_frequencies.png']));

% Active and reactive power of each source
src = {'SG1', 'SG2', 'GFM'};
ns  = 2 + with_gfm;
fig = figure('Color', 'w', 'Position', [80 80 1000 270*ns]);
tl  = tiledlayout(ns, 2, 'TileSpacing', 'compact');
title(tl, [study_title ' - active and reactive power']);
for s = 1:ns
    nexttile; hold on; grid on;
    for k = 1:numel(R), plot(R(k).t, R(k).P(:,s), 'Color', c{k}, 'LineWidth', 1.3); end
    xlabel('Time [s]'); ylabel('P [MW]'); title([src{s} ' active power']);
    if s == 1, legend(names, 'Location', 'best', 'FontSize', 7); end
    nexttile; hold on; grid on;
    for k = 1:numel(R), plot(R(k).t, R(k).Q(:,s), 'Color', c{k}, 'LineWidth', 1.3); end
    xlabel('Time [s]'); ylabel('Q [MVAr]'); title([src{s} ' reactive power']);
end
save_fig(fig, fullfile(here, [prefix '_power.png']));

% Active power through the interconnection
fig = figure('Color', 'w', 'Position', [80 80 700 420]);
hold on; grid on;
for k = 1:numel(R), plot(R(k).t, R(k).Ptie, 'Color', c{k}, 'LineWidth', 1.3); end
xlabel('Time [s]'); ylabel('P_{tie} [MW]');
title({study_title, 'Active power through the tie-lines (bus 2 \rightarrow 3)'});
legend(names, 'Location', 'best');
save_fig(fig, fullfile(here, [prefix '_tie_line.png']));


%% ---------------------------------------------------------------
function r = run_case(folder, mdl, overrides)
% Runs one case model of this folder (optionally overriding Model
% Workspace variables, e.g. {'Ki', 0}) and returns the main signals.
    % Always use the saved model file (an already-open copy may be older).
    if bdIsLoaded(mdl)
        if strcmp(get_param(mdl, 'Dirty'), 'on')
            error('%s has unsaved changes. Save or close it, then run again.', mdl);
        end
        close_system(mdl, 0);
    end
    load_system(fullfile(folder, [mdl '.slx']));

    in = Simulink.SimulationInput(mdl);
    for k = 1:2:numel(overrides)
        in = in.setVariable(overrides{k}, overrides{k+1}, 'Workspace', mdl);
    end
    out = sim(in);

    r.name   = '';
    r.short  = '';
    r.t_step = get_param(mdl, 'ModelWorkspace').getVariable('t_step');
    r.t    = out.f_Hz.time;
    f      = columns(out.f_Hz);         % [SG1 SG2 (bus5)] Hz
    r.f    = f(:,1:2);                  % SG1, SG2 rotor frequency
    r.Pm   = columns(out.Pm_MW);        % [SG1 SG2] MW
    r.P    = columns(out.Pe_MW);        % [SG1 SG2 (GFM)] MW
    r.Q    = columns(out.Q_MVAr);       % [SG1 SG2 (GFM)] MVAr
    if size(r.P, 2) == 2                % model without GFM: GFM power is zero
        r.P(:,3) = 0;
        r.Q(:,3) = 0;
    end
    r.Ptie = columns(out.Ptie_MW);      % MW
end


function print_table(title_str, R)
% Side-by-side performance indices of the cases.
    rows = {'SG1 peak frequency deviation [mHz]', 'SG2 peak frequency deviation [mHz]', ...
            'SG1 max RoCoF, first 0.5 s [Hz/s]',  'SG2 max RoCoF, first 0.5 s [Hz/s]', ...
            'Final frequency [Hz]', ...
            'SG1 final change in Pm [MW]',        'SG2 final change in Pm [MW]', ...
            'Peak tie-line change [MW]',          'Final tie-line change [MW]', ...
            'Peak GFM active power [MW]'};
    n = numel(R);
    M = zeros(numel(rows), n);
    for k = 1:n
        r = R(k);
        [tu, iu] = unique(r.t);
        win = tu > r.t_step & tu <= r.t_step + 0.5;
        for g = 1:2
            df = (r.f(:,g) - r.f(1,g)) * 1e3;                  % mHz
            [~, i] = max(abs(df));
            rocof = gradient(r.f(iu,g), tu);
            peak(g) = df(i);  rmax(g) = max(abs(rocof(win)));   %#ok<AGROW>
        end
        dPm  = r.Pm(end,:) - r.Pm(1,:);
        dtie = r.Ptie - r.Ptie(1);
        [~, j] = max(abs(dtie));
        M(:,k) = [peak(1); peak(2); rmax(1); rmax(2); r.f(end,1); dPm(1); dPm(2); ...
                  dtie(j); dtie(end); max(abs(r.P(:,3)))];
    end
    fprintf('%s\n', title_str);
    fprintf('%s\n', repmat('-', 1, 38 + 19*n));
    fprintf('%-38s', '');  fprintf(' %18s', R.short);  fprintf('\n');
    for j = 1:numel(rows)
        fprintf('%-38s', rows{j});  fprintf(' %18.3f', M(j,:));  fprintf('\n');
    end
end


function plot_study(title_str, R, col, with_gfm, file)
% Study figure: SG frequencies, governor response, tie-line (+ GFM P, Q).
    fig = figure('Color', 'w', 'Position', [80 80 1100 760]);
    tl  = tiledlayout(2 + with_gfm, 2, 'TileSpacing', 'compact');
    title(tl, title_str);
    names = {R.name};

    for g = 1:2
        nexttile; hold on; grid on;
        for k = 1:numel(R), plot(R(k).t, R(k).f(:,g), 'Color', col{k}, 'LineWidth', 1.3); end
        xlabel('Time [s]'); ylabel('f [Hz]'); title(sprintf('SG%d rotor frequency', g));
        if g == 1, legend(names, 'Location', 'best', 'FontSize', 8); end
    end

    nexttile; hold on; grid on;
    for k = 1:numel(R)
        plot(R(k).t, R(k).Pm(:,1) - R(k).Pm(1,1), '-',  'Color', col{k}, 'LineWidth', 1.3);
        plot(R(k).t, R(k).Pm(:,2) - R(k).Pm(1,2), '--', 'Color', col{k}, 'LineWidth', 1.3);
    end
    xlabel('Time [s]'); ylabel('\DeltaP_m [MW]');
    title('Governor response (solid SG1, dashed SG2)');

    nexttile; hold on; grid on;
    for k = 1:numel(R), plot(R(k).t, R(k).Ptie, 'Color', col{k}, 'LineWidth', 1.3); end
    xlabel('Time [s]'); ylabel('P_{tie} [MW]'); title('Tie-line active power (bus 2 \rightarrow 3)');

    if with_gfm
        nexttile; hold on; grid on;
        for k = 1:numel(R), plot(R(k).t, R(k).P(:,3), 'Color', col{k}, 'LineWidth', 1.3); end
        xlabel('Time [s]'); ylabel('P [MW]'); title('GFM active power');
        nexttile; hold on; grid on;
        for k = 1:numel(R), plot(R(k).t, R(k).Q(:,3), 'Color', col{k}, 'LineWidth', 1.3); end
        xlabel('Time [s]'); ylabel('Q [MVAr]'); title('GFM reactive power');
    end
    save_fig(fig, file);
end


function save_fig(fig, file)
    arrayfun(@(a) set(a.Toolbar, 'Visible', 'off'), findall(fig, 'Type', 'axes'));
    exportgraphics(fig, file, 'Resolution', 150);
end


function X = columns(s)
% Scope log (structure with time) -> matrix, one column per scope input.
    X = cell2mat(arrayfun(@(k) s.signals(k).values, 1:numel(s.signals), ...
                          'UniformOutput', false));
end
