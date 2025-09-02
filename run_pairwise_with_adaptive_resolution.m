function run_pairwise_with_adaptive_resolution()
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
dataset_root  = fullfile(pwd, 'dataset_adaptive_resolution');
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
trials = discover_trials_with_adaptive_resolution(dataset_root); % defined below
if isempty(trials)
    error('No trials found under: %s', dataset_root);
end

% Randomize trial order
trials = trials(randperm(numel(trials)));
fprintf('\n=== Trials discovered (%d total) ===\n', numel(trials));
for i = 1:numel(trials)
    t = trials(i);
    fprintf('Trial %d:\n', i);
    fprintf('  Scene      : %s\n', t.scene);
    fprintf('  Basename      : %s\n', t.basename);
    fprintf('  Bitrate    : %s\n', t.bitrate_str);
    fprintf('  W x H      : %dx%d\n', t.w, t.h);
    fprintf('  FPS        : %d\n', t.fps);
    fprintf('  Index      : %d\n', t.idx);
    fprintf('  Ref folder : %s\n', t.ref_folder);
    fprintf('  Test folder: %s\n', t.test_folder);
    % fprintf('  Ref chunks : %d files\n', numel(t.ref_chunks));
    % for j = 1:numel(t.ref_chunks)
    %     fprintf('    %s\n', t.ref_chunks{j});
    % end
    % fprintf('  Test chunks: %d files\n', numel(t.test_chunks));
    % for j = 1:numel(t.test_chunks)
    %     fprintf('    %s\n', t.test_chunks{j});
    % end
    % fprintf('\n');
end

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

        [choice, aborted] = play_trial_adaptive_resolution(window, windowRect, t.ref_chunks , t.test_chunks, ti, numel(trials), true);
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
            choice_code = 0;s
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
            t.scene, ...
            t.bitrate_str, ...
            t.basename, ...       % "speed" field in your header = fps
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
