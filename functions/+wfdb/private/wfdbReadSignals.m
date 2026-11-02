%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the wfdb module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function signals = wfdbReadSignals(described, folder, wantData)
  % Read every signal file of a single-segment record once and return one
  % neutral entry per signal, its samples at its OWN rate (base rate times the
  % signal's samples per frame). Signals that share a file are interleaved
  % frame by frame, so a file is read once and its columns handed to the
  % signals that came from it. Nothing here is scaled to physical units or held
  % to a common rate: that is the caller's choice, so the neutral read stays
  % lossless and a round trip keeps the on-disk integers.
  spec = described.signals;
  count = numel(spec);
  baseRate = described.rate;
  signals = wfdbSignalArray();
  if count == 0
    return;
  end
  files = {};
  for index = 1:count
    if ~any(strcmp(files, spec(index).file))
      files{end + 1} = spec(index).file;
    end
  end
  native = cell(1, count);
  for choice = 1:numel(files)
    mine = find(strcmp({spec.file}, files{choice}));
    format = spec(mine(1)).format;
    offset = spec(mine(1)).offset;
    path = files{choice};
    if ~isempty(folder)
      path = fullfile(folder, files{choice});
    end
    if ~wantData
      % A header-only read still needs the frame count for the signal rate and
      % length, which the file size gives without decoding every sample.
      for k = mine
        native{k} = zeros(0, 1);
      end
      continue;
    end
    values = wfdbReadFile(path, format, offset);
    perFrame = 0;
    for k = mine
      perFrame = perFrame + spec(k).spf;
    end
    frames = floor(numel(values) / perFrame);
    if described.samples > 0
      frames = min(frames, described.samples);
    end
    values = values(1:frames * perFrame);
    block = reshape(values, perFrame, frames);
    row = 1;
    for k = mine
      rows = row:(row + spec(k).spf - 1);
      row = row + spec(k).spf;
      series = reshape(block(rows, :), 1, []);
      if format == 8
        % First differences: the running sum starts at the header's initial
        % value, so the first sample is the initial value plus the first step.
        series = spec(k).initial + cumsum(series);
      end
      series = wfdbApplySkew(series(:), spec(k).skew, spec(k).spf);
      native{k} = series;
    end
  end
  for index = 1:count
    entry = wfdbSignalEntry(spec(index), baseRate, index);
    entry.data = native{index};
    signals(index) = entry;
  end
end
%=============================================================================
function signals = wfdbSignalArray()
  signals = struct('file', {}, 'format', {}, 'spf', {}, 'offset', {}, ...
  'skew', {}, 'gain', {}, 'baseline', {}, 'unit', {}, 'adcres', {}, ...
  'adczero', {}, 'initial', {}, 'checksum', {}, 'blocksize', {}, ...
  'description', {}, 'label', {}, 'rate', {}, 'data', {});
end
%=============================================================================
function entry = wfdbSignalEntry(spec, baseRate, index)
  entry = struct();
  entry.file = spec.file;
  entry.format = spec.format;
  entry.spf = spec.spf;
  entry.offset = spec.offset;
  entry.skew = spec.skew;
  entry.gain = spec.gain;
  entry.baseline = spec.baseline;
  entry.unit = spec.unit;
  entry.adcres = spec.adcres;
  entry.adczero = spec.adczero;
  entry.initial = spec.initial;
  entry.checksum = spec.checksum;
  entry.blocksize = spec.blocksize;
  entry.description = spec.description;
  entry.label = wfdbLeadName(spec.description, index);
  entry.rate = baseRate * spec.spf;
  entry.data = zeros(0, 1);
end
%=============================================================================
function series = wfdbApplySkew(series, skew, spf)
  % A signal declared with a skew lags the others by that many frames: its
  % sample for frame t was stored at frame t + skew. Advancing it by skew
  % frames (skew * spf samples) puts it back in step, the exposed tail held at
  % the last real value so the column keeps its length. Skew is rare (almost
  % every record has none) so the common path does nothing.
  if skew <= 0 || isempty(series)
    return;
  end
  shift = skew * spf;
  n = numel(series);
  if shift >= n
    series = repmat(series(end), n, 1);
    return;
  end
  tail = repmat(series(end), shift, 1);
  series = [series(shift + 1:end); tail];
end
%=============================================================================
function name = wfdbLeadName(description, index)
  name = strtrim(description);
  if isempty(name)
    name = sprintf('sig%d', index);
  end
end
%=============================================================================
