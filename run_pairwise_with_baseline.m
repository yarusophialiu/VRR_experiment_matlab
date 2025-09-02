function run_pairwise_with_baseline()
% RUN_PAIRWISE_PWCMP  Pairwise video quality test (Reference vs Test)
%
% Folder layout under dataset_root:
%   dataset_root/
%     sceneX/
%       reference_*_WxH_*fps_*mbps_*.mp4
%       <basename>_chunk0.mp4
%       <basename>_chunk1.mp4
% Controls
%   Left / Right : switch between Reference and Test
%   Space        : choose the CURRENTLY PLAYING option as better
%   Esc          : quit early
%
% Output CSV columns:
%   userid,scene,bitrate,basename,choice,order,timestamp
%
% Notes
% - Reference loops continuously.
% - Test always plays chunk0 -> chunk1 -> chunk2, then stops (awaits key).
% - Order is randomized per trial (which option is presented first).
%

% ==== CONFIG ====
userid        = 'yl962';
dataset_root  = fullfile(pwd, 'dataset');
out_csv_dir   = fullfile(pwd, 'csv');
if ~exist(out_csv_dir,'dir'), mkdir(out_csv_dir); end
timestamp     = datestr(now, 'yyyymmdd_HHMMSS');
out_csv       = fullfile(out_csv_dir, ['experiment_' timestamp '.csv']);
bgColor       = 0;
targetFps     = 0; % 0 lets PTB choose; set >0 to try to cap drawing rate
screenNumber = 1;
Screen('Preference', 'SkipSyncTests', 1);

FULL_SCREEN_MODE = false; % false; true

% ==== DISCOVER TRIALS ====
trials = discover_trials(dataset_root); % defined below
if isempty(trials)
    error('No trials found under: %s', dataset_root);
end

% Randomize trial order
trials = trials(randperm(numel(trials)));
% if ~isempty(trials)
%     T = struct2table(trials);
%     disp(T(:, {'scene','reference_name','ref_path','test_group_id', 'w', 'h', 'fps','bitrate_str'}));
% end
% for i = 1:numel(trials)
%     fprintf('\nTrial %d (%s):\n', i, trials(i).scene);
%     for j = 1:numel(trials(i).test_chunks)
%         fprintf('   %s\n', trials(i).test_chunks{j});
%     end
% end

% ==== PSYCHTOOLBOX SETUP ====
AssertOpenGL;
HideCursor;
ListenChar(2);
KbName('UnifyKeyNames');
key.left   = KbName('LeftArrow');
key.right  = KbName('RightArrow');
key.space  = KbName('space');
key.esc    = KbName('ESCAPE');

oldVerbosity = Screen('Preference','Verbosity', 1);
oldSync      = Screen('Preference','SkipSyncTests', 1); % set to 0 on lab rigs
addpath('utils');
try
    screens = Screen('Screens');
    scr     = max(screens);

    % CSV header
    fid = fopen(out_csv,'w');
    fprintf(fid, 'userid,scene,bitrate,speed,choice\n');

    if ~FULL_SCREEN_MODE
        rect = [100 100 1650 950];
        [window, windowRect] = Screen('OpenWindow', screenNumber, 0, rect);
    else
        [window, windowRect] = Screen('OpenWindow', screenNumber, 0); % fullscreen
    end
    % Priority(MaxPriority(win));

    % ==== RUN TRIALS ====
    for ti = 1:numel(trials)
        t = trials(ti);

        % % Reference loops
        % disp(t.ref_path);

        [choice, aborted] = play_trial(window, windowRect, t.ref_path, t.test_chunks, ti, numel(trials), true);
        if aborted
            fprintf('Trial %d aborted by user.\n', ti);
            fclose(fid);
            Screen('CloseAll');   % close all PTB windows
            ListenChar(0);        % re-enable keyboard input to MATLAB
            ShowCursor;           % show the mouse cursor again
            return;               % exit the function completely
        end

        % map choice string to numeric code
        if strcmp(choice, 'test')
            choice_code = 1;
        elseif strcmp(choice, 'reference')
            choice_code = 0;
        else
            choice_code = -1; % fallback if nothing selected
        end

        fprintf('Trial %d choice = %s\n', ti, choice);
        % fprintf(fid, 'userid,scene,bitrate,speed,choice\n');
        % row = {userid,t.basename, t.bitrate_str, t.scene, choice};
        % write_to_csv(out_csv, row);
        
        % write one line to CSV
        fprintf(fid, '%s,%s,%s,%s,%d\n', ...
            userid, ...
            t.basename, ...
            t.bitrate_str, ...
            t.scene, ...       % "speed" field in your header = fps
            choice_code);
        end

    fclose(fid);
    draw_center_text(window, 'All done! Thank you 🙏', 30, [255 255 255]);
    WaitSecs(1.5);   % optional: keep it visible for 1–2 seconds
    
    % --- Cleanup and exit ---
    Screen('CloseAll');   % close the PTB window
    ListenChar(0);        % re-enable MATLAB keyboard input
    ShowCursor;           % show mouse cursor
    return;               % exit function/script

    
catch ME
    sca_cleanup([], oldVerbosity, oldSync);
    ShowCursor; ListenChar(0);
    rethrow(ME);
end
end


function trials = discover_trials(root)
% DISCOVER_TRIALS
% Group tests by (basename, idx) ignoring per-chunk W/H/FPS differences.
% Match reference by the same (basename, idx).
%
% Filenames:
%   Test:      <base>_<W>x<H>_<FPS>fps_<MBPS>mbps_<idx>_chunkK.mp4
%   Reference: reference_<base>_<W>x<H>_<FPS>fps_<MBPS>mbps_<idx>.mp4
%
% Returns fields:
%   scene           : <base> (e.g., 'battlefield')
%   reference_name  : reference filename
%   ref_path        : full path to reference
%   test_group_id   : '<base>_<idx>'
%   test_chunks     : cellstr of full chunk paths (chunk0..N)
%   w,h,fps         : from chunk0 if available (NaN otherwise)
%   bitrate_str     : from chunk0 if available ('' otherwise)

fprintf('[discover_trials] root = %s\n', root);

if ~exist(root,'dir')
    warning('[discover_trials] Root does not exist: %s', root);
    trials = [];
    return;
end

scenes = dir(root);
% for i = 1:numel(scenes)
    % fprintf('%d: %s\n', i, scenes(i).name);
% end
scenes = scenes([scenes.isdir]);
scenes = scenes(~ismember({scenes.name},{'.','..'}));

trials = struct('scene',{},'basename',{},'reference_name',{},'ref_path',{}, ...
    'test_group_id',{},'test_chunks',{},'w',{},'h',{},'fps',{},'bitrate_str',{});

for i = 1:numel(scenes)
    sdir = fullfile(root, scenes(i).name);
    vids = dir(fullfile(sdir, '*.mp4'));
    if isempty(vids), continue; end

    names = {vids.name};

    % -------- Build reference map keyed by (base, idx) --------
    % reference_<base>_<W>x<H>_<FPS>fps_<MBPS>mbps_<idx>.mp4
    refMap = containers.Map(); % key: "<base>_<idx>" -> filename
    for r = 1:numel(names)
        nm = names{r};
        toks = regexp(nm, ...
            '^reference_([^_]+)_(\d+)x(\d+)_(\d+)fps_(\d+)(?:mbps|Mbps|MBPS)_(\d+)\.mp4$', ...
            'tokens','once');
        if isempty(toks), continue; end
        base = toks{1};
        idx  = toks{6};
        key  = sprintf('%s_%s', base, idx);
        refMap(key) = nm;
    end

    % -------- Group all test chunks by (base, idx) --------
    % <base>_<W>x<H>_<FPS>fps_<MBPS>mbps_<idx>_chunkK.mp4
    groups = struct(); % dynamic struct with fields as keys
    allTestMatches = regexp(names, ...
        '^([^_]+)_(\d+)x(\d+)_(\d+)fps_(\d+)(?:mbps|Mbps|MBPS)_(\d+)_chunk(\d+)\.mp4$', ...
        'tokens', 'once');

    for n = 1:numel(names)
        tk = allTestMatches{n};
        if isempty(tk), continue; end
        base = tk{1};
        W    = str2double(tk{2}); %#ok<NASGU>
        H    = str2double(tk{3}); %#ok<NASGU>
        FPS  = str2double(tk{4}); %#ok<NASGU>
        MBPS = tk{5};             %#ok<NASGU> % numeric string
        idx  = tk{6};
        K    = str2double(tk{7});

        key = sprintf('%s_%s', base, idx);
        if ~isfield(groups, key)
            groups.(key) = struct( ...
                'base', base, ...
                'idx', idx, ...
                'names', {{}} , ...
                'k', [] );
        end
        groups.(key).names{end+1} = names{n}; %#ok<AGROW>
        groups.(key).k(end+1)     = K;
    end

    % -------- Build trials for each (base, idx) group --------
    gkeys = fieldnames(groups);
    for g = 1:numel(gkeys)
        key   = gkeys{g};
        G     = groups.(key);
        base  = G.base;
        idx   = G.idx;

        % Sort chunks by K
        [Ks, ord]   = sort(G.k, 'ascend');
        chunkNames  = G.names(ord);

        % Require first chunk to be 0 (recommended)
        if isempty(Ks) || Ks(1) ~= 0
            warning('[discover_trials] Skipping %s: first chunk is not chunk0 (have %s).', ...
                key, mat2str(Ks));
            continue;
        end

        % Build full paths
        chunkPaths = fullfile(sdir, chunkNames);

        % Find matching reference by (base, idx)
        if ~isKey(refMap, key)
            warning('[discover_trials] No reference for group %s in %s', key, sdir);
            refName = '';
            refPath = '';
        else
            refName = refMap(key);
            refPath = fullfile(sdir, refName);
        end

        % Extract display params from chunk0 (if present)
        % Parse: <base>_<W>x<H>_<FPS>fps_<MBPS>mbps_<idx>_chunk0.mp4
        w = NaN; h = NaN; fps = NaN; bitrate_str = '';
        chunk0 = chunkNames{1};
        tk0 = regexp(chunk0, ...
            '^([^_]+)_(\d+)x(\d+)_(\d+)fps_(\d+)(?:mbps|Mbps|MBPS)_(\d+)_chunk0\.mp4$', ...
            'tokens','once');
        if ~isempty(tk0)
            w = str2double(tk0{2});
            h = str2double(tk0{3});
            fps = str2double(tk0{4});
            bitrate_str = sprintf('%smbps', tk0{5});
        end

        trials(end+1) = struct( ... %#ok<AGROW>
            'scene',          scenes(i).name, ...
            'basename',       base, ...
            'reference_name', refName, ...
            'ref_path',       refPath, ...
            'test_group_id',  key, ...
            'test_chunks',    {chunkPaths}, ...
            'w',              w, ...
            'h',              h, ...
            'fps',            fps, ...
            'bitrate_str',    bitrate_str);
    end
end

fprintf('[discover_trials] total trials: %d\n', numel(trials));
end





%% ===== Helper: draw centered text =========================================
function draw_center_text(win, txt, pt, col)
Screen('FillRect', win, 0);
Screen('TextSize', win, pt);    % set font size
DrawFormattedText(win, txt, 'center', 'center', col, 70, [], [], 1.5);
Screen('Flip', win);
end



%% ===== Helper: overlay label ==============================================
function draw_label(win, titleStr, currentLabel)
rect = Screen('Rect', win);
margin = 20;
bbox = [margin, margin, rect(3)-margin, margin+60];
Screen('FillRect', win, 0, bbox);
DrawFormattedText(win, sprintf('%s   |   Current: %s', titleStr, upper(currentLabel)), ...
    margin+10, margin+15, [255 255 255], 70);
end


%% ===== Helper: cleanup =====================================================
function sca_cleanup(win, oldVerbosity, oldSync)
if ~isempty(win)
    try, Screen('CloseAll'); end %#ok<TRYNC>
else
    try, Screen('CloseAll'); end %#ok<TRYNC>
end
try, Screen('Preference','Verbosity', oldVerbosity); end %#ok<TRYNC>
try, Screen('Preference','SkipSyncTests', oldSync);  end %#ok<TRYNC>
end
