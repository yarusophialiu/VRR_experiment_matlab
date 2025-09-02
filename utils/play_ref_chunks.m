function [next_state, aborted, watched_ref, choice] = play_ref_chunks(window, windowRect, test_chunks, trial_num, num_trials, video_index, first_pass, must_watch_all, watched_ref, watched_test)
% TEST: play chunks sequentially, looping.
% Left  -> replay test from chunk0
% Right -> switch to reference
% SPACE -> choose test (only if must_watch_all satisfied)
% Esc   -> abort
watched_ref = true;
aborted     = false;
choice      = '';
next_state  = '';

n_chunks    = numel(test_chunks);
movie_handles = zeros(1,n_chunks);
for c = 1:n_chunks
    movie_handles(c) = Screen('OpenMovie', window, test_chunks{c});
end

restart_requested = false;
chunk_idx = 1;
chunks_watched = false(1,n_chunks);

while true
    % If restart requested, reset sequence to chunk 1
    if restart_requested
        restart_requested = false;
        chunk_idx = 1;
        chunks_watched(:) = false;
    end

    Screen('SetMovieTimeIndex', movie_handles(chunk_idx), 0);
    Screen('PlayMovie', movie_handles(chunk_idx), 1);

    chunk_finished = false;
    while ~chunk_finished
        tex = Screen('GetMovieImage', window, movie_handles(chunk_idx));
        if tex <= 0
            chunk_finished = true;
            chunks_watched(chunk_idx) = true;
            if all(chunks_watched)
                watched_ref = true;
                first_pass = false;
                disp("watched test is true");
            end
            break;
        end

        Screen('DrawTexture', window, tex, [], windowRect);
        Screen('TextSize', window, 70);
        Screen('DrawText', window, video_index, 20, 20, [250 128 114]);
        % DrawFormattedText(window, sprintf('Trial %d/%d\nTest\n((←/→ switch, Esc quit))', trial_num, num_trials), ...
        %                   'center', windowRect(4)-100, [255 255 255]);
        Screen('Flip', window);
        Screen('Close', tex);

        [keyIsDown,~,keyCode] = KbCheck;
        if keyIsDown
            % if must_watch_all && (first_pass || ~watched_ref)
            %     continue;  % block until first watch complete
            % end
            
            if keyCode(KbName('ESCAPE'))
                aborted = true; chunk_finished = true; break;
            elseif keyCode(KbName('LeftArrow'))
                % replay test: request restart of full sequence from chunk0
                restart_requested = true;
                chunk_finished    = true; % break inner loop; outer handles reset
            elseif keyCode(KbName('RightArrow'))
                show_noisy_screen(window, windowRect, 500);
                next_state = 'test'; chunk_finished = true; break;
            elseif keyCode(KbName('SPACE'))
                if watched_ref && watched_test
                    show_trial_screen(window, windowRect, trial_num, num_trials, 600);
                    choice = 'ref'; chunk_finished = true; break;
                else
                    disp('Ref: Please view both videos before choosing!');
                    warnmsg = 'Please view both videos before choosing!';
                    show_warning(window, windowRect, warnmsg, 500);
                end
            end
        end
    end
    Screen('PlayMovie', movie_handles(chunk_idx), 0);

    if aborted || ~isempty(next_state) || ~isempty(choice)
        break;
    end

    if restart_requested
        % Outer loop will reset indices
        continue;
    end

    chunk_idx = chunk_idx + 1;
    if chunk_idx > n_chunks
        chunk_idx = 1; % loop back
    end
end

for c = 1:n_chunks
    Screen('CloseMovie', movie_handles(c));
end
end
