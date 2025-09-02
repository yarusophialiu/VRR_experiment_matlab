function trials = discover_trials_with_adaptive_resolution(root)
% DISCOVER_TRIALS (simple): one trial per scene folder.
% All *.mp4 in res/ are reference chunks; all *.mp4 in fps_res/ are test chunks.

fprintf('[discover_trials] root = %s\n', root);
trials = struct('scene',{},'basename',{},'bitrate_str',{},'w',{},'h',{},'fps',{},'idx',{}, ...
                'ref_folder',{},'test_folder',{},'ref_chunks',{},'test_chunks',{});

if ~exist(root,'dir'), warning('Root does not exist: %s', root); return; end

scenes = dir(root);
scenes = scenes([scenes.isdir]);
scenes = scenes(~ismember({scenes.name},{'.','..'}));

for si = 1:numel(scenes)
    sname = scenes(si).name;               % e.g., cave1_1mbps
    sdir  = fullfile(root, sname);
    refRoot  = fullfile(sdir, 'res');
    testRoot = fullfile(sdir, 'fps_res');
    if ~exist(refRoot,'dir') || ~exist(testRoot,'dir'), continue; end

    ref_chunks  = collect_chunks_in_folder(refRoot);
    test_chunks = collect_chunks_in_folder(testRoot);
    if isempty(ref_chunks) || isempty(test_chunks)
        warning('Skipping %s (no chunks found in res/ or fps_res/)', sname);
        continue;
    end
    % --- parse basename + bitrate from folder name ---
    parts = regexp(sname, '^(.*)_([0-9]+mbps)$', 'tokens','once','ignorecase');
    if isempty(parts)
        basename     = sname;
    else
        basename     = parts{1};
    end

    % Parse display params from first chunk we see (fallback-safe)
    [sceneName, w, h, fps, mbps, idx] = parse_from_filename(ref_chunks{1});
    if isempty(sceneName)
        [sceneName, w, h, fps, mbps, idx] = parse_from_filename(test_chunks{1});
    end
    if isempty(sceneName), sceneName = sname; end
    bitrate_str = iff(isnan(mbps),'',sprintf('%dmbps',mbps));

    trials(end+1) = struct( ... %#ok<AGROW>
        'scene',       sceneName, ...
        'basename',    basename, ...
        'bitrate_str', bitrate_str, ...
        'w',           w, ...
        'h',           h, ...
        'fps',         fps, ...
        'idx',         idx, ...
        'ref_folder',  refRoot, ...
        'test_folder', testRoot, ...
        'ref_chunks',  {ref_chunks}, ...
        'test_chunks', {test_chunks});
end

fprintf('[discover_trials] total trials: %d\n', numel(trials));
end

% ---------- helpers ----------
function chunks = collect_chunks_in_folder(folder)
% Collect all *.mp4 and sort by numeric _chunkN if present
chunks = {};
L = dir(fullfile(folder, '*.mp4'));
if isempty(L), return; end
names = {L.name};
pat = '^(.*)_chunk(\d+)\.mp4$';
hasChunk = ~cellfun('isempty', regexp(names, pat, 'once'));
if any(hasChunk)
    idx = zeros(1,sum(hasChunk));
    nn = names(hasChunk);
    for i = 1:numel(nn)
        t = regexp(nn{i}, pat, 'tokens','once');
        idx(i) = str2double(t{2});
    end
    [~, ord] = sort(idx, 'ascend');
    names = [nn(ord), names(~hasChunk)]; % chunked first in order, then others
else
    names = sort(names); % no chunk suffixes—just alphabetic
end
chunks = fullfile(folder, names);
end

function [name,w,h,fps,mbps,idx] = parse_from_filename(p)
[name,w,h,fps,mbps,idx] = deal('',NaN,NaN,NaN,NaN,NaN);
[~,nm] = fileparts(p);
tk = regexp(nm, '^([^_]+)_(\d+)x(\d+)_(\d+)fps_(\d+)mbps_(\d+)_chunk(\d+)$', 'tokens','once','ignorecase');
if isempty(tk), return; end
name = tk{1}; w = str2double(tk{2}); h = str2double(tk{3});
fps  = str2double(tk{4}); mbps = str2double(tk{5}); idx = str2double(tk{6});
end

function out = iff(cond,a,b)
if cond, out = a; else, out = b; end
end
