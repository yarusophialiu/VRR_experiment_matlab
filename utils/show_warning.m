function show_warning(window, windowRect, warnmsg, duration_s)
    Screen('FillRect', window, 0, windowRect); % Black background
    Screen('TextSize', window, 80);           % Set font size
    DrawFormattedText(window, warnmsg, 'center', 'center', [255 100 100]); % Red-ish
    Screen('Flip', window);
    WaitSecs(duration_s / 1000); % Display for duration_s seconds
end

