function run_pairwise_pwcmp()
% RUN_PAIRWISE_PWCMP  Psychtoolbox pairwise comparison (Reference vs Test)
%
% Usage:
%   run_pairwise_pwcmp('dataset', 'results.csv', true)
%
% Dataset layout:
%   dataset_root/
%     sceneA/
%       reference_sceneA_1280x720_60fps_4mbps_1.mp4
%       battlefield_1280x720_60fps_4mbps_1_chunk0.mp4
%       battlefield_1280x720_60fps_4mbps_1_chunk1.mp4
%       battlefield_1280x720_60fps_4mbps_1_chunk2.mp4
%       battlefield_1280x720_60fps_4mbps_1_chunk3.mp4
%     sceneB/ ...
%
% What this does
%  - Matches each *test* (chunk0..3) to its *reference* in the same scene
%  - Plays video(s) with Psychtoolbox (reference loops; test plays its 4 chunks in sequence)
%  - Forces a full watch the first time if must_watch_all == true
%  - Lets the participant re-watch either video, then choose the better one
%  - Logs each trial to CSV: timestamp, scene, test, reference, params, order, choice, RT
%
% Keys during playback
%   Reference player:  Left/Right → go to Test;  ESC → quit
%   Test player:       Up Arrow → go to Reference; Left/Right → stay on Test; ESC → quit
%   Decision screen:   1 → Reference better, 2 → Test better, R → rewatch Reference, T → rewatch Test
%
% Dependencies
%   Psychtoolbox (Screen, KbCheck, etc.).
%
% Tip
%   If you already have helper UIs like show_noisy_screen/show_trial_screen, you can
%   add calls to them where indicated. This script is self-contained otherwise.

must_watch_all = false; % true; 
dataset_root = fullfile(pwd, 'dataset');
timestamp = datestr(now, 'mmdd_HHMM');
out_csv = fullfile(pwd, 'csv', ['experiment_' timestamp '.csv']);
root = fullfile(pwd,'dataset');              % or the absolute path you expect
disp(dataset_root);
disp(exist(root,'dir'));                      % should be 7 if folder exists


trials = discover_trials(root);
userid = 'yl962';

AssertOpenGL;
HideCursor;
ListenChar(2); %#ok<*LCHART>
oldVerbosity = Screen('Preference','Verbosity',1);
oldSyncTests = Screen('Preference','SkipSyncTests', 1); % set to 0 for lab rigs!

try
    % --- Build trials ------------------------------------------------------
    trials = discover_trials(dataset_root);
    if isempty(trials)
        error('No trials discovered under %s', dataset_root);
    end
    disp(trials(1))           % first trial
    disp({trials.scene})      % list of all scenes

    % Randomize trial order
    trials = trials(randperm(numel(trials)));

    % --- Open window -------------------------------------------------------
    screens = Screen('Screens');
    scr = max(screens);
    [win, winRect] = Screen('OpenWindow', scr, 0);
    Priority(MaxPriority(win));

    % Instruction
    draw_center_text(win, 'Pairwise Video Quality Test\n\nWatch both videos. Then choose which is better.\n\nReference loops; Test plays 4 chunks.\n\nKeys:\n  Reference: Left/Right→Test\n  Test: Up→Reference\n  Decision: 1=Reference better, 2=Test better\n\nPress any key to start.', 32, [255 255 255]);
    KbStrokeWait;

    % --- CSV header --------------------------------------------------------
    if ~exist(out_csv, 'file')
        fid = fopen(out_csv,'w');
        fprintf(fid, 'userid,scene,bitrate,basename,choice\n');
        fclose(fid);
    end

    % --- Run trials --------------------------------------------------------
    for ti = 1:numel(trials)
        tr = trials(ti);

        % Overlay label (top-left)
        overlayRef = sprintf('%dx%d %dfps REF', tr.w, tr.h, tr.fps);
        overlayTest = sprintf('%dx%d %dfps TEST', tr.w, tr.h, tr.fps);

        % First-view order: reference first in odd trials, test first in even
        if mod(ti,2)==1
            first = 'reference';
        else
            first = 'test';
        end

        choice = '';
        rt_ms  = NaN;

        % States: 'reference' or 'test' or 'decision'
        state = first;
        first_pass_ref  = must_watch_all;
        first_pass_test = must_watch_all;

        % Start RT when both have been watched at least once
        rt_started = false;
        t_start = NaN;

        watched_ref = false; watched_test = false;

        while true
            switch state
                case 'reference'
                    play_reference_loop(win, winRect, tr.ref_path, overlayRef, first_pass_ref);
                    watched_ref = true;
                    first_pass_ref = false;
                    state = 'test';

                case 'test'
                    play_test_chunks(win, winRect, tr.test_chunks, overlayTest, first_pass_test);
                    watched_test = true;
                    first_pass_test = false;
                    state = 'decision';

                case 'decision'
                    if ~rt_started && watched_ref && watched_test
                        t_start = GetSecs;
                        rt_started = true;
                    end
                    [decision, go_where] = decision_screen(win, tr.scene, tr.test_basename);
                    if strcmp(go_where,'reference')
                        state = 'reference';
                    elseif strcmp(go_where,'test')
                        state = 'test';
                    else
                        % User made a choice
                        choice = decision; % 'reference' or 'test'
                        if rt_started
                            rt_ms = round((GetSecs - t_start)*1000);
                        end
                        % Inter-trial screen
                        draw_center_text(win, 'Got it!\nNext trial starting...', 40, [255 255 255]);
                        WaitSecs(0.6);
                        break;
                    end
            end
        end

        % --- Append CSV row -------------------------------------------------
        fid = fopen(out_csv,'a');
        fprintf(fid, '%s,%s,%s,%s,%d,%d,%d,%s,%d,%s,%s,%d\n', ...
            datestr(now,'yyyy-mm-dd HH:MM:SS.FFF'), tr.scene, tr.test_basename, tr.reference_name, ...
            tr.w, tr.h, tr.fps, tr.bitrate_str, numel(tr.test_chunks), first, choice, rt_ms);
        fclose(fid);
    end

    % Goodbye
    draw_center_text(win, 'All done. Thank you!\n\nPress any key to exit.', 36, [255 255 255]);
    KbStrokeWait;

catch ME
    sca;
    ListenChar(0);
    ShowCursor;
    Screen('Preference','Verbosity',oldVerbosity);
    Screen('Preference','SkipSyncTests', oldSyncTests);
    rethrow(ME);
end

sca;
ListenChar(0);
ShowCursor;
Screen('Preference','Verbosity',oldVerbosity);
Screen('Preference','SkipSyncTests', oldSyncTests);
end


%% --- Trial discovery ------------------------------------------------------
function trials = discover_trials(root)
fprintf('[discover_trials] root = %s\n', root);

if ~exist(root,'dir')
    warning('[discover_trials] Root does not exist: %s', root);
    trials = [];
    return;
end

scenes = dir(root);
scenes = scenes([scenes.isdir]);
scenes = scenes(~ismember({scenes.name},{'.','..'}));


trials = struct('scene',{},'reference_name',{},'ref_path',{},'test_basename',{},'test_chunks',{},'w',{},'h',{},'fps',{},'bitrate_str',{});

for i = 1:numel(scenes)
    sdir = fullfile(root, scenes(i).name);
    vids = dir(fullfile(sdir, '*.mp4'));
    if isempty(vids), continue; end

    % Reference: reference_* pattern
    refIdx = find(contains({vids.name}, 'reference_'));
    if isempty(refIdx), warning('No reference in %s', sdir); continue; end

    % Build a map from (WxH_fps_bitrate_index) to reference file for robust matching
    refMap = containers.Map();
    for r = refIdx
        nm = vids(r).name;
        % Example: reference_scene_wxh_60fps_bmbps_index.mp4
        toks = regexp(nm, 'reference_[^_]+_(\d+)x(\d+)_(\d+)fps_(\d+)(?:mbps|Mbps|MBPS)_(\d+)\.mp4$', 'tokens');
        if isempty(toks), continue; end
        t = toks{1};
        key = sprintf('%sx%sfps_%s_%s', t{1}, t{2}, t{3}, t{4}); % w x h fps bitrate
        refMap(key) = nm;
    end

    % Tests: ..._chunk0.mp4 (assume chunk1..3 exist)
    test0 = vids(endsWith({vids.name}, '_chunk0.mp4'));
    for k = 1:numel(test0)
        base = erase(test0(k).name, '_chunk0.mp4');
        % battlefield_1280x720_60fps_4mbps_1_chunk0.mp4
        toks = regexp(test0(k).name, '(.+?)_(\d+)x(\d+)_(\d+)fps_(\d+)(?:mbps|Mbps|MBPS)_(\d+)_chunk0\.mp4$', 'tokens');
        if isempty(toks), continue; end
        t = toks{1};
        w = str2double(t{2}); h = str2double(t{3}); fps = str2double(t{4});
        bitrate_str = [t{5} 'mbps'];

        key = sprintf('%dx%dfps_%s_%s', w, h, t{4}, t{5});
        if ~isKey(refMap, key)
            warning('No matching reference for test %s', test0(k).name);
            continue;
        end

        % Gather chunks 0..3, but only include existing ones
        chunks = {};
        for ci = 0:3
            cand = fullfile(sdir, sprintf('%s_chunk%d.mp4', base, ci));
            if exist(cand, 'file')
                chunks{end+1} = cand; %#ok<AGROW>
            end
        end
        if isempty(chunks)
            continue;
        end

        trials(end+1) = struct( ...
            'scene', scenes(i).name, ...
            'reference_name', refMap(key), ...
            'ref_path', fullfile(sdir, refMap(key)), ...
            'test_basename', base, ...
            'test_chunks', {chunks}, ...
            'w', w, 'h', h, 'fps', fps, 'bitrate_str', bitrate_str); %#ok<AGROW>
    end
end
end


%% --- Players --------------------------------------------------------------
function play_reference_loop(win, winRect, path, overlayText, must_watch_all)
% Loop the reference until user presses Left/Right to leave.
movie = Screen('OpenMovie', win, path);
Screen('SetMovieTimeIndex', movie, 0);
Screen('PlayMovie', movie, 1);

first_pass = must_watch_all;

while true
    tex = Screen('GetMovieImage', win, movie);
    if tex <= 0
        Screen('SetMovieTimeIndex', movie, 0);
        Screen('PlayMovie', movie, 1);
        first_pass = false; % one full pass done
        continue;
    end
    Screen('DrawTexture', win, tex, [], winRect);
    Screen('TextSize', win, 48);
    DrawFormattedText(win, overlayText, 30, 30, [255 255 255]);
    Screen('Flip', win);
    Screen('Close', tex);

    [down,~,kc] = KbCheck;
    if first_pass
        continue; % block keys until first pass finishes
    end
    if down
        if kc(KbName('ESCAPE')), abort_all(); end
        if kc(KbName('LeftArrow')) || kc(KbName('RightArrow'))
            break; % go to test
        end
    end
end
Screen('PlayMovie', movie, 0);
Screen('CloseMovie', movie);
KbReleaseWait;
end

function play_test_chunks(win, winRect, paths, overlayText, must_watch_all)
% Play all chunks in sequence. After one full sequence, allow keys.
handles = zeros(1,numel(paths));
for i=1:numel(paths), handles(i) = Screen('OpenMovie', win, paths{i}); end
first_pass = must_watch_all;

while true
    all_done_once = true;
    for i=1:numel(handles)
        Screen('SetMovieTimeIndex', handles(i), 0);
        Screen('PlayMovie', handles(i), 1);
        chunk_done = false;
        while ~chunk_done
            tex = Screen('GetMovieImage', win, handles(i));
            if tex <= 0
                chunk_done = true;
                break;
            end
            Screen('DrawTexture', win, tex, [], winRect);
            Screen('TextSize', win, 48);
            DrawFormattedText(win, overlayText, 30, 30, [255 255 255]);
            Screen('Flip', win);
            Screen('Close', tex);

            [down,~,kc] = KbCheck;
            if ~first_pass && down
                if kc(KbName('ESCAPE')), abort_all(); end
                if kc(KbName('UpArrow')) % go back to reference
                    for j=1:numel(handles)
                        Screen('PlayMovie', handles(j), 0);
                        Screen('CloseMovie', handles(j));
                    end
                    KbReleaseWait; return; 
                end
            end
        end
        Screen('PlayMovie', handles(i), 0);
    end
    if first_pass
        first_pass = false; % one full sequence watched, now allow navigation
    else
        % After not-first-pass, end sequence and return to decision
        break;
    end
end
for j=1:numel(handles)
    Screen('PlayMovie', handles(j), 0);
    Screen('CloseMovie', handles(j));
end
KbReleaseWait;
end


%% --- Decision UI ----------------------------------------------------------
function [decision, go_where] = decision_screen(win, scene, test_base)
% Returns decision in {'reference','test'} or '' if navigation chosen.
% go_where in {'reference','test',''}

msg = sprintf(['Scene: %s\nTest: %s\n\nWhich looks better?\n' ...
               '  [1] Reference\n  [2] Test\n\n' ...
               'Need another look?\n  [R] Rewatch Reference\n  [T] Rewatch Test\n  [ESC] Quit'], scene, test_base);

while true
    draw_center_text(win, msg, 32, [255 255 255]);
    [down,~,kc] = KbStrokeWait;
    if kc(KbName('ESCAPE')), abort_all(); end
    if kc(KbName('1!')) || kc(KbName('1'))
        decision = 'reference'; go_where=''; return;
    elseif kc(KbName('2@')) || kc(KbName('2'))
        decision = 'test'; go_where=''; return;
    elseif kc(KbName('R'))
        decision = ''; go_where='reference'; return;
    elseif kc(KbName('T'))
        decision = ''; go_where='test'; return;
    end
end
end


%% --- Small helpers --------------------------------------------------------
function draw_center_text(win, txt, pts, color)
Screen('FillRect', win, 0);
Screen('TextSize', win, pts);
DrawFormattedText(win, txt, 'center', 'center', color, 70, [], [], 1.5);
Screen('Flip', win);
end

function abort_all()
sca; ListenChar(0); ShowCursor; error('Experiment aborted by user.');
end
