function [next_state, aborted, watched_ref, choice] = play_reference(window, windowRect, ref_path, trial_num, num_trials, video_index, first_pass, must_watch_all, watched_ref, watched_test)
% REFERENCE: loops continuously.
% Left  -> replay reference
% Right -> switch to test
% SPACE -> choose reference (only if must_watch_all satisfied)
% Esc   -> abort
watched_ref = true;
aborted     = false;
next_state  = '';
choice      = '';

movie = Screen('OpenMovie', window, ref_path);
Screen('SetMovieTimeIndex', movie, 0);
Screen('PlayMovie', movie, 1);

while true
    tex = Screen('GetMovieImage', window, movie);
    if tex <= 0
        % loop
        Screen('SetMovieTimeIndex', movie, 0);
        Screen('PlayMovie', movie, 1);
        if first_pass
            first_pass = false;
            watched_ref = true;
            disp("watched ref is true");
        end
        continue;
    end

    Screen('DrawTexture', window, tex, [], windowRect);
    Screen('TextSize', window, 70);
    Screen('DrawText', window, char(sprintf('Test  (Video%d)', video_index)), 20, 20, [250 128 114]);
    % DrawFormattedText(window, sprintf('Trial %d/%d\nReference\n((←/→ switch, Esc quit))', trial_num, num_trials), ...
    %                   'center', windowRect(4)-100, [255 255 255]);
    Screen('Flip', window);
    Screen('Close', tex);

    [keyIsDown,~,keyCode] = KbCheck;
    if keyIsDown
        if keyCode(KbName('ESCAPE'))
            disp('reference escape');
            aborted = true; break;
        elseif keyCode(KbName('LeftArrow'))
            % replay current reference: seek to 0 and keep playing
            Screen('SetMovieTimeIndex', movie, 0);
            Screen('PlayMovie', movie, 1);
            % stay in 'reference' (no state change)
        elseif keyCode(KbName('RightArrow'))
            show_noisy_screen(window, windowRect, 500);
            next_state = 'test'; break;
        elseif keyCode(KbName('SPACE'))
            if watched_ref && watched_test
                show_trial_screen(window, windowRect, trial_num, num_trials, 600);
                choice = 'reference'; break;
            else
                disp('Reference: Please view both videos before choosing!');
                warnmsg = 'Please view both videos before choosing!';
                show_warning(window, windowRect, warnmsg, 500);
            end
        end
    end
end
Screen('PlayMovie', movie, 0);
Screen('CloseMovie', movie);
end
