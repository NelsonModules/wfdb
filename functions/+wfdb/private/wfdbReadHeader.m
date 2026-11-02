%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the wfdb module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function described = wfdbReadHeader(path)
  % Parse one WFDB header: a record line, then either one line per signal or,
  % for a multi-segment record, one line per segment, and the hash lines the
  % writer left for a reader. The gain field is the one that carries a signal
  % back to physical units, so a reader that misreads it returns a plausible
  % wrong number; that is why it is pulled apart here, once, rather than in
  % every caller.
  if ~isfile(path)
    error('wfdb:noHeaderFile', 'The file %s is not on disk.', path);
  end
  [lines, comments] = wfdbLines(fileread(path));
  if isempty(lines)
    error('wfdb:emptyHeader', 'The header %s is empty.', path);
  end
  parts = wfdbWords(lines{1});
  if numel(parts) < 2
    error('wfdb:badHeaderSignals', 'The header %s does not name its signals.', path);
  end
  described = struct();
  described.comments = comments;
  % The record name may carry a segment count after a slash, which is how a
  % long record names the pieces it was cut into.
  nameToken = parts{1};
  cut = strfind(nameToken, '/');
  described.multiSegment = ~isempty(cut);
  described.segmentCount = 0;
  if described.multiSegment
    described.name = nameToken(1:cut(1) - 1);
    described.segmentCount = round(str2double(nameToken(cut(1) + 1:end)));
  else
    described.name = nameToken;
  end
  described.count = round(str2double(parts{2}));
  % The rate may carry a counter frequency and a base counter value, which
  % say how the recorder counted rather than how fast it sampled; the sampling
  % rate is the number before the slash.
  described.rate = 250;
  described.counterFrequency = NaN;
  described.baseCounter = 0;
  if numel(parts) >= 3
    [described.rate, described.counterFrequency, described.baseCounter] = ...
    wfdbRate(parts{3});
  end
  % The sample count may be absent, in which case the reader reads every frame
  % the signal file holds; zero here is the flag for that.
  described.samples = 0;
  if numel(parts) >= 4
    described.samples = round(wfdbNumber(parts{4}));
  end
  % A header need not carry a clock. The placeholder midnight keeps the info
  % struct one shape, and the flag says nothing downstream should print it.
  described.startTime = '00.00.00';
  described.startTimeKnown = numel(parts) >= 5;
  if described.startTimeKnown
    described.startTime = strrep(parts{5}, ':', '.');
  end
  described.startDate = '';
  if numel(parts) >= 6
    described.startDate = parts{6};
  end
  if described.multiSegment
    described.segments = wfdbSegments(lines, described.segmentCount, path);
    described.signals = wfdbSignalStruct();
    return;
  end
  described.segments = struct('name', {}, 'length', {});
  described.signals = wfdbSignalStruct();
  for index = 2:numel(lines)
    parts = wfdbWords(lines{index});
    if numel(parts) < 2
      continue;
    end
    described.signals(end + 1) = wfdbSignalLine(parts);
    if numel(described.signals) == described.count
      break;
    end
  end
  if numel(described.signals) ~= described.count
    error('wfdb:badHeaderSignalCount', 'The header %s announces %d signals and describes %d.', path, described.count, numel(described.signals));
  end
end
%=============================================================================
function signals = wfdbSignalStruct()
  signals = struct('file', {}, 'format', {}, 'spf', {}, 'offset', {}, ...
  'skew', {}, 'gain', {}, 'baseline', {}, 'unit', {}, 'adcres', {}, ...
  'adczero', {}, 'initial', {}, 'checksum', {}, 'blocksize', {}, ...
  'description', {});
end
%=============================================================================
function segments = wfdbSegments(lines, count, path)
  % One line per segment: a name and a length. A name of '~' is a null
  % segment, a stretch the record declares and has no samples for, kept as a
  % gap rather than dropped so the timing of everything after it stays true.
  segments = struct('name', {}, 'length', {});
  for index = 2:numel(lines)
    parts = wfdbWords(lines{index});
    if numel(parts) < 2
      continue;
    end
    entry = struct('name', parts{1}, 'length', round(wfdbNumber(parts{2})));
    segments(end + 1) = entry;
    if numel(segments) == count
      break;
    end
  end
  if numel(segments) ~= count
    error('wfdb:badHeaderSegmentCount', 'The header %s announces %d segments and describes %d.', path, count, numel(segments));
  end
end
%=============================================================================
function line = wfdbSignalLine(parts)
  % file format gain(baseline)/units adcres adczero initial checksum block
  % description. Only the file, the format and the gain field matter for a
  % physical read; the rest is kept for a round trip.
  line = struct('file', parts{1}, 'format', 16, 'spf', 1, 'offset', 0, ...
  'skew', 0, 'gain', 200, 'baseline', [], 'unit', 'mV', 'adcres', 0, ...
  'adczero', 0, 'initial', 0, 'checksum', 0, 'blocksize', 0, ...
  'description', '');
  [line.format, line.spf, line.offset, line.skew] = wfdbFormat(parts{2});
  if numel(parts) >= 3
    [line.gain, line.baseline, line.unit] = wfdbGain(parts{3});
  end
  if numel(parts) >= 4
    line.adcres = round(wfdbNumber(parts{4}));
  end
  if numel(parts) >= 5
    line.adczero = round(wfdbNumber(parts{5}));
  end
  if numel(parts) >= 6
    line.initial = round(wfdbNumber(parts{6}));
  end
  if numel(parts) >= 7
    line.checksum = round(wfdbNumber(parts{7}));
  end
  if numel(parts) >= 8
    line.blocksize = round(wfdbNumber(parts{8}));
  end
  if numel(parts) >= 9
    label = parts{9};
    for extra = 10:numel(parts)
      label = [label, ' ', parts{extra}];
    end
    line.description = label;
  end
  % The baseline defaults to the ADC zero when the gain field carries no
  % bracket, because that is the stored value a flat line sits at.
  if isempty(line.baseline)
    line.baseline = line.adczero;
  end
end
%=============================================================================
function [format, spf, offset, skew] = wfdbFormat(text)
  % The format field is the packing number, optionally xN for the samples per
  % frame of a multi-frequency signal, optionally :skew (samples this signal
  % lags the others), optionally +offset for a byte offset into the file.
  % Missing each one in turn is a different silent corruption, so each marker
  % is cut in the order it can appear.
  spf = 1;
  offset = 0;
  skew = 0;
  cut = strfind(text, '+');
  if ~isempty(cut)
    offset = round(str2double(text(cut(1) + 1:end)));
    if isnan(offset) || offset < 0
      offset = 0;
    end
    text = text(1:cut(1) - 1);
  end
  cut = strfind(text, ':');
  if ~isempty(cut)
    skew = round(str2double(text(cut(1) + 1:end)));
    if isnan(skew)
      skew = 0;
    end
    text = text(1:cut(1) - 1);
  end
  cut = strfind(text, 'x');
  if ~isempty(cut)
    spf = round(str2double(text(cut(1) + 1:end)));
    if isnan(spf) || spf < 1
      spf = 1;
    end
    text = text(1:cut(1) - 1);
  end
  format = round(str2double(text));
  if isnan(format)
    format = 16;
  end
end
%=============================================================================
function [gain, baseline, unit] = wfdbGain(text)
  % gain, an optional baseline in brackets, an optional unit after a slash.
  gain = 200;
  baseline = [];
  unit = 'mV';
  cut = strfind(text, '/');
  if ~isempty(cut)
    unit = text(cut(1) + 1:end);
    text = text(1:cut(1) - 1);
  end
  open = strfind(text, '(');
  close = strfind(text, ')');
  if ~isempty(open) && ~isempty(close) && close(end) > open(1)
    baseline = round(wfdbNumber(text(open(1) + 1:close(end) - 1)));
    text = text(1:open(1) - 1);
  end
  value = wfdbNumber(text);
  % A gain of zero is the format's way of saying the signal is uncalibrated;
  % the default 200 adu per unit keeps a number rather than dividing by zero.
  if ~isnan(value) && value ~= 0
    gain = value;
  end
end
%=============================================================================
function [rate, counter, base] = wfdbRate(text)
  rate = 250;
  counter = NaN;
  base = 0;
  open = strfind(text, '(');
  close = strfind(text, ')');
  if ~isempty(open) && ~isempty(close) && close(end) > open(1)
    base = wfdbNumber(text(open(1) + 1:close(end) - 1));
    text = text(1:open(1) - 1);
  end
  cut = strfind(text, '/');
  if ~isempty(cut)
    counter = wfdbNumber(text(cut(1) + 1:end));
    text = text(1:cut(1) - 1);
  end
  value = wfdbNumber(text);
  if ~isnan(value) && value > 0
    rate = value;
  end
end
%=============================================================================
function value = wfdbNumber(text)
  text = strtrim(text);
  value = str2double(text);
  if isnan(value)
    value = 0;
  end
end
%=============================================================================
function [lines, comments] = wfdbLines(text)
  % The data lines are the ones that do not begin with a hash; the hash lines
  % are the writer's comments and are handed back on their own, without the
  % hash, because a record often keeps the subject's age and the diagnosis
  % there and a reader that drops them loses the only context there is.
  lines = {};
  comments = {};
  pieces = strsplit(strrep(text, char(13), ''), char(10));
  for index = 1:numel(pieces)
    piece = pieces{index};
    trimmed = strtrim(piece);
    if isempty(trimmed)
      continue;
    end
    if trimmed(1) == '#'
      rest = trimmed(2:end);
      if ~isempty(rest) && rest(1) == ' '
        rest = rest(2:end);
      end
      comments{end + 1} = rest;
      continue;
    end
    lines{end + 1} = trimmed;
  end
end
%=============================================================================
function words = wfdbWords(line)
  % Tokens are whitespace separated. A tab is as good a separator as a space,
  % so a header that lines its fields up with tabs is read the same as one
  % that uses spaces.
  line = strrep(line, char(9), ' ');
  words = {};
  pieces = strsplit(line, ' ');
  for index = 1:numel(pieces)
    piece = strtrim(pieces{index});
    if ~isempty(piece)
      words{end + 1} = piece;
    end
  end
end
%=============================================================================
