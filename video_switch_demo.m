function video_switch_demo()
    % press 1 to play Test 1 video, 2 for Test 2 video, 3 for refrence video
    % experiment for varying fps and resolution
    % 100 trials per session, 2 session
    ENABLE_GAMMA_TABLE = true; % false;
    FULL_SCREEN_MODE = true;

    userid = input('Enter user ID: ', 's');
    session_time = datestr(now, 'yyyymmdd_HHMMSS');
    csv_filename = sprintf('varying_%s_%s.csv', userid, session_time);
    fprintf('csv_filename %s', csv_filename);
    num_tests = 200; % TODO: change number of pairwise comparison tests

    % --- Window setup ---
    Screen('Preference', 'SkipSyncTests', 1);
    KbName('UnifyKeyNames');
    screens = Screen('Screens');
    screenNumber = 1; % min(screens); % Use 1 for LG, 0 for main screen


    % Fix high contrast issue on Titanium - comment out for LG display
    % % My PC may be loading an ICC profile or Psychtoolbox identity-gamma table at startup; the server probably isn't.
    % if ENABLE_GAMMA_TABLE
    %     gammaTab = repmat(linspace(0,1,256)', 1, 3);   % identity (linear) LUT
    %     Screen('LoadNormalizedGammaTable', screenNumber, gammaTab);
    % end
    % gammaTab = repmat(linspace(0,1,256)', 1, 3);   % identity (linear) LUT
    % Screen('LoadNormalizedGammaTable', screenNumber, gammaTab);
    
    if ~FULL_SCREEN_MODE
        rect = [100 100 900 700];
        [window, windowRect] = Screen('OpenWindow', screenNumber, 0, rect);
    else
        [window, windowRect] = Screen('OpenWindow', screenNumber, 0); % fullscreen
    end

    addpath('D:\VVQA\VQA_over_time\ASAP')
    parentFolder = 'D:\VVQA\VQA_over_time\dataset4k';
    all_data = collect_all_reference_and_tests(parentFolder);
    fprintf('Number of scene/path combos: %d\n', length(all_data));
    condition_table = build_condition_table(all_data);

    videos(1).label = 'Reference'; videos(1).fps = 'Reference'; videos(1).color = [250 128 114]; % [173 216 230];
    videos(2).label = 'TEST-1'; videos(2).fps = 'Test 1'; videos(2).color = [250 128 114];
    videos(3).label = 'TEST-2'; videos(3).fps = 'Test 2'; videos(3).color = [250 128 114]; % [144 238 144];

    % block_columns → comparisons only *within* the same scene+path
    sch = PwcmpASAPScheduler(csv_filename, userid, condition_table, {'scene','vidpath'});
    
    [sch, N_left] = sch.get_pair_left();
    fprintf('%d pairwise comparisons in this batch\n', N_left);

    for p = 1:num_tests
        watched_test1 = false;
        watched_test2 = false;
        state = 'reference';
        quit = false;
        selection_made = false;
        % returns two rows belonging to the same scene/path 1 2      
        [sch, iA, iB] = sch.get_next_pair(); % row indices in condition_table 
        rowA = condition_table(iA,:);
        rowB = condition_table(iB,:);
        
        fprintf('Scene "%s"  Path "%s"\n', rowA.scene{1}, rowA.vidpath{1});
        % fprintf('Compare  test-A (row %d)  vs  test-B (row %d)\n', iA, iB);
        % fprintf('rowA chunk paths:\n');
        % disp(rowA.testpaths{1}); % 1×3 cell  → each element is a char/ stringfprintf('rowA chunk paths:\n');

        videos(1).paths = {rowA.reference{1}}; 
        videos(2).paths = rowA.testpaths{1};
        videos(3).paths = rowB.testpaths{1};

        first_reference = true;
        first_test1 = true;
        first_test2 = true;

        try
            while ~quit && ~selection_made
                switch state
                    case 'reference'
                        [state, quit, selection_made, watched_test1, watched_test2] = ...
                            play_and_switch(window, windowRect, videos(1), 'reference', p, num_tests, watched_test1, watched_test2, first_reference);
                        first_reference = false;
                        % fprintf('reference state %s\n', state);
                    case 'test1'
                        [state, quit, selection_made, watched_test1, watched_test2] = ...
                            play_and_switch(window, windowRect, videos(2), 'test', p+1, num_tests, watched_test1, watched_test2, first_test1);
                        first_test1 = false;
                        if selection_made
                            sch = sch.set_pair_result( 1 );
                        end
                    case 'test2'
                        [state, quit, selection_made, watched_test1, watched_test2] = ...
                            play_and_switch(window, windowRect, videos(3), 'test', p+1, num_tests, watched_test1, watched_test2, first_test2);
                        first_test2 = false;
                        if selection_made
                            sch = sch.set_pair_result( 2 );
                        end
                end
            end
            if quit
                break; % User hit ESCAPE, exit all pairs
            end
        catch ME
            Screen('CloseAll');
            rethrow(ME);
        end
    end

    Screen('CloseAll');
    sca;
end

function [next_state, quit, selection_made, watched_test1, watched_test2] = play_and_switch(window, windowRect, vid, mode, trial_num, num_tests, watched_test1, watched_test2, must_watch_all)
    warnmsg = '';
    quit = false; next_state = ''; selection_made = false;
    % If just one path (reference), play and loop it
    if numel(vid.paths) == 1
        first_pass = must_watch_all;
        if first_pass
            show_trial_screen(window, windowRect, trial_num, num_tests, 600);
        end
        movie = Screen('OpenMovie', window, vid.paths{1});
        Screen('SetMovieTimeIndex', movie, 0);
        Screen('PlayMovie', movie, 1);
        
        while true
            tex = Screen('GetMovieImage', window, movie);
            if tex <= 0
                Screen('SetMovieTimeIndex', movie, 0);
                Screen('PlayMovie', movie, 1);
                if first_pass
                    first_pass = false;
                    % disp('Reference finish: first_pass');
                    % disp(first_pass);
                end
                continue;
            end
            Screen('DrawTexture', window, tex, [], windowRect);
            % Screen('FrameRect', window, vid.color, windowRect, 8);
            Screen('TextSize', window, 70);
            Screen('DrawText', window, vid.fps, 20, 20, vid.color);
            Screen('Flip', window);
            Screen('Close', tex);

            [keyIsDown, ~, keyCode] = KbCheck;
            if first_pass
                % Ignore all keys until first playback is done
                continue;
            end
            if keyIsDown
                % keyIdx = find(keyCode);
                % fprintf('KbName of pressed keys: %s', KbName(keyIdx));
                if keyCode(KbName('ESCAPE'))
                    quit = true; next_state = 'ESCAPE'; break;
                elseif keyCode(KbName('LeftArrow'))
                    show_noisy_screen(window, windowRect, 500);
                    watched_test1 = true; 
                    next_state = 'test1'; break;
                elseif keyCode(KbName('RightArrow'))
                    show_noisy_screen(window, windowRect, 500);
                    watched_test2 = true; 
                    next_state = 'test2'; break;
                end
            end
        end
        Screen('PlayMovie', movie, 0);
        Screen('CloseMovie', movie);
        KbReleaseWait;
    else
        % Play all chunks in sequence, loop if reach end
        % Pre-open all chunks
        n_chunks = numel(vid.paths);
        movie_handles = zeros(1, n_chunks);
        for c = 1:n_chunks
            movie_handles(c) = Screen('OpenMovie', window, vid.paths{c});
        end

        chunk_idx = 1;
        % Screen('SetMovieTimeIndex', movie_handles(chunk_idx), 0);
        % Screen('PlayMovie', movie_handles(chunk_idx), 1);

        first_pass = must_watch_all;
        chunks_watched = false(1, n_chunks); % 3 chunks

        while true
            % movie = Screen('OpenMovie', window, vid.paths{chunk_idx});
            % if movie <= 0, error('Could not open movie: %s', vid.paths{chunk_idx}); end
            % Screen('SetMovieTimeIndex', movie, 0);
            % Screen('PlayMovie', movie, 1);
            Screen('SetMovieTimeIndex', movie_handles(chunk_idx), 0);
            Screen('PlayMovie', movie_handles(chunk_idx), 1);

            chunk_finished = false;
            while ~chunk_finished
                tex = Screen('GetMovieImage', window, movie_handles(chunk_idx));
                if tex <= 0
                    chunk_finished = true;
                    chunks_watched(chunk_idx) = true;
                    % disp('Test chunk: first_pass, all(chunks_watched)');
                    % disp(first_pass);
                    % disp(all(chunks_watched));
                    break;
                end
                Screen('DrawTexture', window, tex, [], windowRect);
                % Screen('FrameRect', window, vid.color, windowRect, 8);
                Screen('TextSize', window, 70);
                Screen('DrawText', window, vid.fps, 20, 20, vid.color);
                Screen('Flip', window);
                Screen('Close', tex);

                [keyIsDown, ~, keyCode] = KbCheck;
                if first_pass && ~all(chunks_watched)
                    continue;  % Block keys until all chunks watched
                end
                if keyIsDown
                    if keyCode(KbName('ESCAPE'))
                        quit = true; next_state = ''; chunk_finished = true; break;
                    elseif keyCode(KbName('LeftArrow'))
                        show_noisy_screen(window, windowRect, 500);
                        watched_test1 = true;
                        next_state = 'test1'; chunk_finished = true; break;
                    elseif keyCode(KbName('RightArrow'))
                        show_noisy_screen(window, windowRect, 500);
                        watched_test2 = true;
                        next_state = 'test2'; chunk_finished = true; break;
                    elseif keyCode(KbName('UpArrow'))
                        show_noisy_screen(window, windowRect, 500);
                        next_state = 'reference'; chunk_finished = true; break;
                    elseif keyCode(KbName('SPACE'))
                        if watched_test1 && watched_test2
                            show_trial_screen(window, windowRect, trial_num, num_tests, 600);
                            disp('trial screen');
                            quit = false; next_state = 'next_trial'; chunk_finished = true; selection_made = true; break;
                        else
                            disp('warning');
                            warnmsg = 'Please view both videos before choosing!';
                            show_warning(window, windowRect, warnmsg, 500);
                        end
                    end
                end
            end
            Screen('PlayMovie', movie_handles(chunk_idx), 0); % stops the playback, 0 means stop
            % Screen('CloseMovie', movie); % closes the movie file associated with the handle movie and frees up all related system resource
            % KbReleaseWait; % disable to make the video player smoother
            % while KbCheck; end 

            if quit || ~isempty(next_state)
                break;
            end

            chunk_idx = chunk_idx + 1;
            % disp('chunk_idx increase to');
            % disp(chunk_idx);
            if chunk_idx > numel(vid.paths)
                chunk_idx = 1; % Loop to first chunk if all chunks done
                if first_pass
                    if all(chunks_watched)
                        first_pass = false;  % Now allow keys
                        % disp('Test play finished: first_pass, all(chunks_watched)');
                        % disp(first_pass);
                        % disp(all(chunks_watched));
                    end
                end
            end
        end
        for c = 1:n_chunks
            Screen('CloseMovie', movie_handles(c));
        end
    end
end


function write_to_csv(filename, result_row)
    if ~exist(filename, 'file')
        fid = fopen(filename, 'w');
        fprintf(fid, 'selection,reference path,test1 path,test2 path\n'); % csv header
    else
        fid = fopen(filename, 'a');
    end
    fprintf(fid, '%d,%s,%s,%s\n', result_row{:});
    fclose(fid);
end


function show_warning(window, windowRect, warnmsg, duration_s)
    Screen('FillRect', window, 0, windowRect); % Black background
    Screen('TextSize', window, 80);           % Set font size
    DrawFormattedText(window, warnmsg, 'center', 'center', [255 100 100]); % Red-ish
    Screen('Flip', window);
    WaitSecs(duration_s / 1000); % Display for duration_s seconds
end


function show_trial_screen(window, windowRect, trial_num, num_tests, duration_s)
    % Clear the screen to black
    Screen('FillRect', window, 0, windowRect);
    % Prepare text
    msg = sprintf('Trial %d / %d', trial_num, num_tests);
    Screen('TextSize', window, 70);
    % Draw centered text
    DrawFormattedText(window, msg, 'center', 'center', [255 255 255]);
    Screen('Flip', window);
    WaitSecs(duration_s / 1000);
end


function show_noisy_screen(window, windowRect, duration_ms)
    [w, h] = RectSize(windowRect);
    % Create a random noise image (uint8, 3 channels for RGB)
    noise_img = uint8(randi([0, 255], [h, w, 3]));
    noise_tex = Screen('MakeTexture', window, noise_img);
    Screen('DrawTexture', window, noise_tex, [], windowRect);
    Screen('Flip', window);
    WaitSecs(duration_ms / 1000); % duration in seconds
    Screen('Close', noise_tex);
end


function condition_table = build_condition_table(all_data)
% build_condition_table   Convert all_data into a table for ASAP scheduler
% condition_table = build_condition_table(all_data)
%
%   all_data: output from collect_all_reference_and_tests()
%   Returns: condition_table (table)
    rows = [];
    for k = 1:numel(all_data)
        scene = all_data(k).scene;
        path  = all_data(k).path;
        ref   = all_data(k).ref;
        tests = all_data(k).tests;

        for t = 1:numel(tests)
            newrow  = table( string(scene),        ...
                             string(path),         ...
                             {ref},                ...
                             {tests{t}.paths},     ...
                             'VariableNames', ...
                             {'scene','vidpath','reference','testpaths'});
            rows = [rows; newrow];
        end
    end
    condition_table = rows;
end
