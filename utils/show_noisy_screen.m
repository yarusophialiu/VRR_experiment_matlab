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