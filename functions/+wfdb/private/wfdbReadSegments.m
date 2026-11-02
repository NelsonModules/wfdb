%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the wfdb module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function signals = wfdbReadSegments(described, folder, wantData)
  % A multi-segment record names its pieces and the reader stitches them back
  % into one entry per signal. A fixed layout repeats the same signals in every
  % segment and they are concatenated; a variable layout opens with a
  % zero-length layout header that names the full set of signals, and each data
  % segment is placed into the signals whose names it carries, the rest left
  % NaN. A null segment (~) is a stretch with no samples and becomes NaN of its
  % length, so the record's timeline is not shortened by the gap.
  segments = described.segments;
  baseRate = described.rate;
  variable = ~isempty(segments) && segments(1).length == 0;
  if variable
    layout = wfdbReadHeader(wfdbSegmentPath(folder, segments(1).name));
    signals = wfdbLayoutEntries(layout, baseRate);
    first = 2;
  else
    layout = wfdbFirstReal(segments, folder);
    signals = wfdbLayoutEntries(layout, baseRate);
    first = 1;
  end
  if ~wantData
    return;
  end
  count = numel(signals);
  pieces = cell(count, 1);
  for s = first:numel(segments)
    if strcmp(segments(s).name, '~')
      for k = 1:count
        gap = nan(segments(s).length * signals(k).spf, 1);
        pieces{k}{end + 1} = gap;
      end
      continue;
    end
    head = wfdbReadHeader(wfdbSegmentPath(folder, segments(s).name));
    segSignals = wfdbReadSignals(head, folder, true);
    segLabels = {segSignals.label};
    segFrames = segments(s).length;
    for k = 1:count
      match = find(strcmp(signals(k).label, segLabels), 1);
      if isempty(match)
        pieces{k}{end + 1} = nan(segFrames * signals(k).spf, 1);
      else
        pieces{k}{end + 1} = segSignals(match).data;
      end
    end
  end
  for k = 1:count
    if isempty(pieces{k})
      signals(k).data = zeros(0, 1);
    else
      signals(k).data = cat(1, pieces{k}{:});
    end
  end
end
%=============================================================================
function entries = wfdbLayoutEntries(layout, baseRate)
  % One neutral entry per signal of the layout (or of the first real segment),
  % carrying the metadata every stitched column shares; the data is filled in
  % by the caller.
  entries = wfdbSignalArray();
  for index = 1:layout.count
    spec = layout.signals(index);
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
    entries(index) = entry;
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
function layout = wfdbFirstReal(segments, folder)
  % The leads of a fixed-layout record come from the first segment that has
  % samples; a leading null segment names no signals.
  for s = 1:numel(segments)
    if ~strcmp(segments(s).name, '~')
      layout = wfdbReadHeader(wfdbSegmentPath(folder, segments(s).name));
      return;
    end
  end
  error('wfdb:multiSegmentNoSignals', 'A multi-segment record has no segment with signals.');
end
%=============================================================================
function name = wfdbLeadName(description, index)
  name = strtrim(description);
  if isempty(name)
    name = sprintf('sig%d', index);
  end
end
%=============================================================================
function path = wfdbSegmentPath(folder, name)
  path = [name, '.hea'];
  if ~isempty(folder)
    path = fullfile(folder, [name, '.hea']);
  end
end
%=============================================================================
