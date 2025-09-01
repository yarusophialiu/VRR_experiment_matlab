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