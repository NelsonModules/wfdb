%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the wfdb module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function r = read(varargin)
  % R = wfdb.read(NAME) reads a PhysioNet WFDB record into the neutral struct
  % this module returns. NAME is the record, with or without its .hea
  % extension; the header is read, then the signal files it names, then (when
  % NAME.atr is on disk) the annotations. Nothing in R assumes a domain: it is
  % the header, one entry per signal with its samples at its own rate, and the
  % annotations. A reader that gets the gain field, the sample packing or the
  % annotation gap arithmetic wrong returns a signal that looks plausible and
  % is wrong, so the format is read in one place, here.
  %
  % R = wfdb.read(NAME, 'Physical', true) returns each signal's samples in
  % physical units, (raw - baseline) / gain. By default the samples are the raw
  % ADC integers the file holds, so a read followed by wfdb.write is lossless;
  % the gain, baseline and unit of every signal are on R so physical units are
  % one step away.
  %
  % R = wfdb.read(NAME, 'Signals', WHICH) keeps only some signals, by label (a
  % char or cellstr) or by index, in the order asked.
  %
  % R = wfdb.read(NAME, 'Annotations', WHICH) chooses the annotation file:
  % 'auto' (the default) reads NAME.atr when present and skips it when absent;
  % an extension such as 'qrs' reads NAME.qrs; a path reads that file; false
  % reads none.
  %
  % R = wfdb.read(NAME, 'Data', false) reads the header only and returns no
  % samples; wfdb.header is the shorthand for that.
  %
  % R has fields: kind, name, path, rate (the base sampling frequency),
  % counterFrequency, baseCounter, declaredFrames, startTime, startTimeKnown,
  % startDate, comments, multiSegment, multiFrequency, segments, signals (a
  % struct array with file, format, spf, offset, skew, gain, baseline, unit,
  % adcres, adczero, initial, checksum, blocksize, description, label, rate and
  % data) and annotations (sample, time, code, symbol, num, subtype, chan, aux).
  %
  % Example:
  %   r = wfdb.read('100');
  %   plot((0:numel(r.signals(1).data) - 1) / r.signals(1).rate, r.signals(1).data);
  %
  % See also wfdb.write, wfdb.header, wfdb.matrix, wfdb.annotations.
  narginchk(1, inf);
  nargoutchk(0, 1);
  name = varargin{1};
  if ~ischar(name) && ~isStringScalar(name)
    error('wfdb:badName', 'The record name must be text.');
  end
  opts = wfdbReadOptions(varargin(2:end));
  base = wfdbBaseName(char(name));
  header = [base, '.hea'];
  described = wfdbReadHeader(header);
  folder = fileparts(header);
  if described.multiSegment
    signals = wfdbReadSegments(described, folder, opts.data);
  else
    signals = wfdbReadSignals(described, folder, opts.data);
  end
  if ~isempty(opts.signals)
    signals = signals(wfdbChooseSignals(opts.signals, {signals.label}));
  end
  multiFrequency = any([signals.spf] > 1);
  if opts.physical
    for k = 1:numel(signals)
      signals(k).data = (signals(k).data - signals(k).baseline) / ...
      signals(k).gain;
    end
  end
  rate = described.rate;
  r = struct();
  r.kind = 'wfdb.record';
  r.name = described.name;
  r.path = header;
  r.rate = rate;
  r.counterFrequency = described.counterFrequency;
  r.baseCounter = described.baseCounter;
  r.declaredFrames = described.samples;
  r.startTime = described.startTime;
  r.startTimeKnown = described.startTimeKnown;
  r.startDate = described.startDate;
  r.comments = described.comments;
  r.multiSegment = described.multiSegment;
  r.multiFrequency = multiFrequency;
  r.segments = described.segments;
  r.signals = signals;
  r.annotations = wfdbMaybeAnnotations(opts.annotations, base, rate);
end
%=============================================================================
function opts = wfdbReadOptions(args)
  opts = struct('annotations', 'auto', 'physical', false, 'signals', [], ...
  'data', true);
  if mod(numel(args), 2) ~= 0
    error('wfdb:badOptions', 'Options come in name-value pairs.');
  end
  for k = 1:2:numel(args)
    name = args{k};
    if ~ischar(name) && ~isStringScalar(name)
      error('wfdb:badOptionName', 'An option name must be text.');
    end
    value = args{k + 1};
    switch lower(char(name))
      case 'annotations'
        opts.annotations = value;
      case 'physical'
        opts.physical = logical(value);
      case 'signals'
        opts.signals = value;
      case 'data'
        opts.data = logical(value);
      otherwise
        error('wfdb:unknownOption', 'Unknown option %s.', char(name));
    end
  end
end
%=============================================================================
function keep = wfdbChooseSignals(want, labels)
  % Names or indices, turned into positions in the order asked. A name that is
  % not a signal, or an index out of range, is refused rather than read as a
  % silent empty.
  if isnumeric(want)
    keep = round(want(:)');
    if any(keep < 1) || any(keep > numel(labels))
      error('wfdb:badSignalIndex', 'A signal index is outside the range 1 to %d.', numel(labels));
    end
    return;
  end
  if ischar(want) || isStringScalar(want)
    want = cellstr(want);
  end
  keep = zeros(1, numel(want));
  for index = 1:numel(want)
    match = find(strcmp(char(want{index}), labels), 1);
    if isempty(match)
      error('wfdb:noSuchSignal', 'No signal is labelled %s.', char(want{index}));
    end
    keep(index) = match;
  end
end
%=============================================================================
function annotations = wfdbMaybeAnnotations(which, base, rate)
  annotations = wfdbAnnotationStruct([], [], [], [], [], [], [], rate);
  if isequal(which, false)
    return;
  end
  if ischar(which) || isStringScalar(which)
    which = char(which);
  else
    error('wfdb:badAnnotationsOption', 'Annotations must be ''auto'', an extension, a file path or false.');
  end
  if strcmpi(which, 'auto')
    candidate = [base, '.atr'];
    if isfile(candidate)
      annotations = wfdbReadAnnotations(candidate, rate);
    end
    return;
  end
  path = which;
  if ~isempty(which) && which(1) == '.'
    which = which(2:end);
  end
  if isempty(strfind(path, '/')) && isempty(strfind(path, char(92))) && ...
    ~isfile(path)
    path = [base, '.', which];
  end
  annotations = wfdbReadAnnotations(path, rate);
end
%=============================================================================
