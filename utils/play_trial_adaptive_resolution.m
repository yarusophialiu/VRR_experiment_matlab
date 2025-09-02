function [choice, aborted] = play_trial_adaptive_resolution(window, windowRect, ref_chunks, test_chunks, trial_num, num_trials, must_watch_all)
% PLAY_TRIAL  Run a single trial: reference vs test (multi-chunk).
%
% Returns:
%   choice  : 'reference' | 'test'
%   aborted : true if ESCAPE pressed

choice  = '';
aborted = false;

% state        = 'reference';
watched_ref  = false;
watched_test = false;
first_ref    = true;
first_test   = true;

% --- Randomize initial state ---
if rand < 0.5
    state = 'reference';
else
    state = 'test';
end

state = 'reference';

% Labeling: the one that plays FIRST is Video1, the other is Video2
if strcmp(state,'reference')
    ref_label  = 1;   % reference starts -> Video1
    test_label = 2;   % test is Video2
else
    ref_label  = 2;   % test starts -> Video1, so reference is Video2
    test_label = 1;   % test is Video1
end

% Labeling: the one that plays FIRST is Video1, the other is Video2
if strcmp(state,'reference')
    ref_label  = 'A reference';   % reference starts -> Video1
    test_label = 'B test';   % test is Video2
else
    ref_label  = 'B reference';   % test starts -> Video1, so reference is Video2
    test_label = 'A test';   % test is Video1
end


while isempty(choice) && ~aborted
    switch state
        case 'reference'
            [state, aborted, watched_ref, choice] = ...
                play_ref_chunks(window, windowRect, ref_chunks, trial_num, num_trials, ref_label, first_ref, must_watch_all, watched_ref, watched_test);
            first_ref = false;
            % disp('Reference: watched_ref');
            % disp(watched_ref);
        case 'test'
            [state, aborted, watched_test, choice] = ...
                play_test_chunks(window, windowRect, test_chunks, trial_num, num_trials, test_label, first_test, must_watch_all, watched_ref, watched_test);
            first_test = false;
            % disp('Test: watched_test');
            % disp(watched_test);
    end
end
end
