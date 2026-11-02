%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the wfdb module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function info = write(varargin)
  % wfdb.write(NAME, R) writes a WFDB record: NAME.hea and NAME.dat, with every
  % signal interleaved in the one signal file, and (when R carries annotations)
  % NAME.atr. R is the neutral struct wfdb.read returns, or one built by hand.
  % What wfdb.read reads back equals what went in to the step the chosen format
  % quantises to; with raw integer samples (the default) it is exact.
  %
  % wfdb.write(NAME, SAMPLES, RATE) writes a plain matrix, one column per
  % signal, at RATE hertz. SAMPLES is taken as physical and quantised with the
  % gain (200 adu per unit by default); pass 'Gain' and 'Baseline' to set the
  % scaling, 'Leads' and 'Units' to name the signals.
  %
  % Options:
  %   'Format'       the signal packing for the whole file: 16 (the default for
  %                  a plain matrix), 61, 80, 160, 212, 24, 32, 310 or 311. A
  %                  struct keeps each signal's own format unless this overrides.
  %   'Physical'     true means the samples are physical and are quantised with
  %                  each signal's gain and baseline; false (the default for a
  %                  struct from wfdb.read) means they are already raw integers.
  %   'Gain'/'Baseline'  the scaling for a plain matrix, a scalar or one per
  %                  signal.
  %   'Leads'/'Units'    the labels and units for a plain matrix.
  %   'Annotations'  'auto' (the default) writes NAME.atr when R has
  %                  annotations; an extension writes NAME.extension; false
  %                  writes none.
  %   'Segments'     write a fixed-layout multi-segment record: the signals cut
  %                  into consecutive pieces, each an ordinary record, named by a
  %                  master header NAME.hea. Give a vector of per-segment frame
  %                  counts (summing to the record length) or a scalar chunk
  %                  size. wfdb.read stitches the pieces back into one record.
  %
  % INFO returns name, format, signals, frames and the files written (and the
  % segment count when a multi-segment record was written).
  %
  % See also wfdb.read, wfdb.annotations.
  narginchk(2, inf);
  nargoutchk(0, 1);
  name = varargin{1};
  if ~ischar(name) && ~isStringScalar(name)
    error('wfdb:badName', 'The record name must be text.');
  end
  second = varargin{2};
  if isstruct(second)
    [signals, meta, annotations, rest] = wfdbFromStruct(second, varargin(3:end));
    physicalDefault = false;
  elseif isnumeric(second)
    narginchk(3, inf);
    [signals, meta, annotations, rest] = wfdbFromMatrix(second, varargin{3}, ...
    varargin(4:end));
    physicalDefault = true;
  else
    error('wfdb:badRecord', 'The second argument must be a struct from wfdb.read or a numeric matrix.');
  end
  opts = wfdbWriteOptions(rest, physicalDefault);
  if isempty(opts.segments)
    info = wfdbWriteRecord(char(name), signals, meta, annotations, opts);
  else
    info = wfdbWriteMultiSegment(char(name), signals, meta, annotations, opts);
  end
end
%=============================================================================
function [signals, meta, annotations, rest] = wfdbFromStruct(r, rest)
  if ~isfield(r, 'signals')
    error('wfdb:badWriteStruct', 'The struct must have a signals field.');
  end
  signals = r.signals;
  meta = wfdbMeta(r);
  annotations = [];
  if isfield(r, 'annotations')
    annotations = r.annotations;
  end
end
%=============================================================================
function [signals, meta, annotations, rest] = wfdbFromMatrix(samples, rate, rest)
  if ~isscalar(rate) || ~(rate > 0)
    error('wfdb:badRate', 'The rate must be one positive number of hertz.');
  end
  count = size(samples, 2);
  signals = struct('data', {}, 'label', {}, 'unit', {}, 'gain', {}, ...
  'baseline', {}, 'spf', {}, 'format', {});
  for k = 1:count
    entry = struct('data', samples(:, k), 'label', sprintf('sig%d', k), ...
    'unit', 'mV', 'gain', 200, 'baseline', 0, 'spf', 1, 'format', []);
    signals(k) = entry;
  end
  meta = struct('rate', rate, 'startTime', '00.00.00', ...
  'startTimeKnown', false, 'startDate', '', 'comments', {{}}, 'name', '');
  annotations = [];
end
%=============================================================================
function meta = wfdbMeta(r)
  meta = struct('rate', 250, 'startTime', '00.00.00', ...
  'startTimeKnown', false, 'startDate', '', 'comments', {{}}, 'name', '');
  if isfield(r, 'rate')
    meta.rate = r.rate;
  end
  if isfield(r, 'startTime')
    meta.startTime = r.startTime;
  end
  if isfield(r, 'startTimeKnown')
    meta.startTimeKnown = logical(r.startTimeKnown);
  end
  if isfield(r, 'startDate')
    meta.startDate = r.startDate;
  end
  if isfield(r, 'comments')
    meta.comments = r.comments;
  end
  if isfield(r, 'name')
    meta.name = r.name;
  end
end
%=============================================================================
function opts = wfdbWriteOptions(args, physicalDefault)
  opts = struct('format', [], 'physical', physicalDefault, 'gain', [], ...
  'baseline', [], 'leads', [], 'units', [], 'annotations', 'auto', ...
  'segments', []);
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
      case 'format'
        opts.format = round(value);
      case 'physical'
        opts.physical = logical(value);
      case 'gain'
        opts.gain = value;
      case 'baseline'
        opts.baseline = value;
      case 'leads'
        opts.leads = value;
      case 'units'
        opts.units = value;
      case 'annotations'
        opts.annotations = value;
      case 'segments'
        opts.segments = value;
      otherwise
        error('wfdb:unknownOption', 'Unknown option %s.', char(name));
    end
  end
end
%=============================================================================
function prep = wfdbPrepare(signals, opts)
  % The common preparation of the signals before any byte is written: spread
  % the plain-matrix options, pick one format for the file, and quantise
  % physical samples to the raw integers the format stores (raw samples pass
  % through). The round is the only place the signal loses what the format
  % cannot hold. Both the single-record and the multi-segment writers start
  % here, so they agree on the samples.
  count = numel(signals);
  if count == 0
    error('wfdb:noSignal', 'The record carries no signal.');
  end
  signals = wfdbApplyOverrides(signals, opts, count);
  format = wfdbChooseFormat(signals, opts);
  spf = zeros(1, count);
  frames = zeros(1, count);
  raw = cell(1, count);
  for k = 1:count
    spf(k) = max(round(signals(k).spf), 1);
    data = double(signals(k).data(:));
    if opts.physical
      data = round(data * signals(k).gain + signals(k).baseline);
    end
    raw{k} = data;
    frames(k) = numel(data) / spf(k);
  end
  if any(frames ~= round(frames))
    error('wfdb:raggedFrames', 'A signal length is not a whole number of frames.');
  end
  if any(frames ~= frames(1))
    error('wfdb:raggedLengths', 'The signals do not all hold the same number of frames.');
  end
  prep = struct('signals', signals, 'raw', {raw}, 'spf', spf, ...
  'nframes', frames(1), 'format', format, 'count', count);
end
%=============================================================================
function info = wfdbWriteRecord(name, signals, meta, annotations, opts)
  prep = wfdbPrepare(signals, opts);
  base = wfdbBaseName(name);
  [~, stem] = fileparts(base);
  datName = [stem, '.dat'];
  wfdbWriteSignals([base, '.dat'], prep.raw, prep.spf, prep.nframes, prep.format);
  wfdbWriteHeader([base, '.hea'], stem, datName, prep.signals, prep.raw, ...
  prep.spf, meta, prep.format, prep.nframes);
  files = {[base, '.hea'], [base, '.dat']};
  extension = wfdbAnnotationExtension(opts.annotations, annotations);
  if ~isempty(extension)
    wfdbWriteAnnotations([base, '.', extension], annotations);
    files{end + 1} = [base, '.', extension];
  end
  info = struct('name', stem, 'format', prep.format, 'signals', prep.count, ...
  'frames', prep.nframes, 'files', {files});
end
%=============================================================================
function info = wfdbWriteMultiSegment(name, signals, meta, annotations, opts)
  % Write the record as a fixed-layout multi-segment record: the same signals
  % cut into consecutive pieces, each piece an ordinary record of its own, and
  % a master header that names the pieces and their lengths. This is what a long
  % recording stored in bounded files is, and wfdb.read stitches it back into
  % the one record that went in. The clock and the comments go on the master;
  % a segment carries only its samples.
  prep = wfdbPrepare(signals, opts);
  base = wfdbBaseName(name);
  [folder, stem] = fileparts(base);
  lengths = wfdbSegmentLengths(opts.segments, prep.nframes);
  nseg = numel(lengths);
  segMeta = meta;
  segMeta.startTimeKnown = false;
  segMeta.startDate = '';
  segMeta.comments = {};
  segNames = cell(1, nseg);
  files = {};
  startFrame = 0;
  for s = 1:nseg
    len = lengths(s);
    segName = sprintf('%s_%d', stem, s);
    segNames{s} = segName;
    segBase = segName;
    if ~isempty(folder)
      segBase = fullfile(folder, segName);
    end
    segRaw = cell(1, prep.count);
    for k = 1:prep.count
      from = startFrame * prep.spf(k) + 1;
      to = (startFrame + len) * prep.spf(k);
      segRaw{k} = prep.raw{k}(from:to);
    end
    wfdbWriteSignals([segBase, '.dat'], segRaw, prep.spf, len, prep.format);
    wfdbWriteHeader([segBase, '.hea'], segName, [segName, '.dat'], ...
    prep.signals, segRaw, prep.spf, segMeta, prep.format, len);
    files{end + 1} = [segBase, '.hea'];
    files{end + 1} = [segBase, '.dat'];
    startFrame = startFrame + len;
  end
  wfdbWriteMasterHeader([base, '.hea'], stem, segNames, lengths, prep.count, ...
  meta.rate, prep.nframes, meta);
  files = [{[base, '.hea']}, files];
  extension = wfdbAnnotationExtension(opts.annotations, annotations);
  if ~isempty(extension)
    wfdbWriteAnnotations([base, '.', extension], annotations);
    files{end + 1} = [base, '.', extension];
  end
  info = struct('name', stem, 'format', prep.format, 'signals', prep.count, ...
  'frames', prep.nframes, 'segments', nseg, 'files', {files});
end
%=============================================================================
function lengths = wfdbSegmentLengths(spec, nframes)
  % The per-segment lengths in frames, from a vector that must sum to the record
  % length, or from a scalar chunk size that cuts the record into pieces of that
  % many frames with a shorter last piece.
  spec = double(spec(:)');
  if isscalar(spec)
    if spec < 1 || spec ~= round(spec)
      error('wfdb:badSegments', 'A segment length must be a positive whole number of frames.');
    end
    nseg = max(1, ceil(nframes / spec));
    lengths = repmat(spec, 1, nseg);
    lengths(end) = nframes - spec * (nseg - 1);
    lengths = lengths(lengths > 0);
    return;
  end
  if any(spec < 1) || any(spec ~= round(spec))
    error('wfdb:badSegments', 'A segment length must be a positive whole number of frames.');
  end
  if sum(spec) ~= nframes
    error('wfdb:badSegmentsSum', 'The segment lengths must sum to the record length (%d frames).', nframes);
  end
  lengths = spec;
end
%=============================================================================
function wfdbWriteMasterHeader(path, stem, segNames, lengths, nsig, rate, ...
  nsamp, meta)
  fid = fopen(path, 'wt');
  if fid < 0
    error('wfdb:cannotWriteHeaderFile', 'The file %s cannot be written.', path);
  end
  % The record line names the record, the segment count after a slash, the
  % signal count, the rate and the total length; then the clock and date when
  % the record knew them.
  fprintf(fid, '%s/%d %d %g %d', stem, numel(segNames), nsig, rate, nsamp);
  if meta.startTimeKnown
    fprintf(fid, ' %s', strrep(meta.startTime, '.', ':'));
    if ~isempty(meta.startDate)
      fprintf(fid, ' %s', meta.startDate);
    end
  end
  fprintf(fid, '\n');
  for s = 1:numel(segNames)
    fprintf(fid, '%s %d\n', segNames{s}, lengths(s));
  end
  for index = 1:numel(meta.comments)
    fprintf(fid, '# %s\n', meta.comments{index});
  end
  fclose(fid);
end
%=============================================================================
function signals = wfdbApplyOverrides(signals, opts, count)
  % Spread the plain-matrix options (gain, baseline, leads, units) across the
  % signals; a scalar is given to every signal, a vector one per signal.
  if ~isempty(opts.gain)
    g = wfdbPerSignal(opts.gain, count, 'Gain');
    for k = 1:count
      signals(k).gain = g(k);
    end
  end
  if ~isempty(opts.baseline)
    b = wfdbPerSignal(opts.baseline, count, 'Baseline');
    for k = 1:count
      signals(k).baseline = b(k);
    end
  end
  if ~isempty(opts.leads)
    leads = opts.leads;
    if ischar(leads) || isStringScalar(leads)
      leads = cellstr(leads);
    end
    if numel(leads) ~= count
      error('wfdb:badLeads', 'Leads must be one label per signal (%d expected).', count);
    end
    for k = 1:count
      signals(k).label = char(leads{k});
    end
  end
  if ~isempty(opts.units)
    units = opts.units;
    if ischar(units) || isStringScalar(units)
      units = cellstr(units);
    end
    if numel(units) ~= count
      error('wfdb:badUnits', 'Units must be one unit per signal (%d expected).', count);
    end
    for k = 1:count
      signals(k).unit = char(units{k});
    end
  end
end
%=============================================================================
function value = wfdbPerSignal(given, count, label)
  given = double(given(:)');
  if isscalar(given)
    value = given * ones(1, count);
    return;
  end
  if numel(given) ~= count
    error('wfdb:badPerSignal', '%s must be one value per signal (%d expected).', label, count);
  end
  value = given;
end
%=============================================================================
function format = wfdbChooseFormat(signals, opts)
  % One packing for the whole signal file. The option wins; otherwise the
  % signals' own format is kept when they agree, and 16 is the fallback.
  if ~isempty(opts.format)
    format = opts.format;
    return;
  end
  formats = [];
  for k = 1:numel(signals)
    if isfield(signals(k), 'format') && ~isempty(signals(k).format)
      formats(end + 1) = signals(k).format;
    end
  end
  if isempty(formats)
    format = 16;
    return;
  end
  if any(formats ~= formats(1))
    error('wfdb:mixedFormat', 'The signals have different formats; give one Format for the file.');
  end
  format = formats(1);
end
%=============================================================================
function wfdbWriteSignals(path, raw, spf, nframes, format)
  % Every signal in one file, interleaved frame by frame: a frame holds each
  % signal's samples-per-frame in turn, so the reader de-interleaves by the same
  % layout. Built as one block and encoded in one pass.
  perFrame = sum(spf);
  block = zeros(perFrame, nframes);
  row = 1;
  for k = 1:numel(raw)
    rows = row:(row + spf(k) - 1);
    row = row + spf(k);
    block(rows, :) = reshape(raw{k}, spf(k), nframes);
  end
  flat = reshape(block, 1, []);
  bytes = wfdbEncode(flat, format);
  fid = fopen(path, 'wb');
  if fid < 0
    error('wfdb:cannotWriteSignalFile', 'The file %s cannot be written.', path);
  end
  fwrite(fid, bytes, 'uint8');
  fclose(fid);
end
%=============================================================================
function wfdbWriteHeader(path, recordName, datName, signals, raw, spf, meta, ...
  format, nframes)
  count = numel(signals);
  fid = fopen(path, 'wt');
  if fid < 0
    error('wfdb:cannotWriteHeaderFile', 'The file %s cannot be written.', path);
  end
  fprintf(fid, '%s %d %g %d', recordName, count, meta.rate, nframes);
  if meta.startTimeKnown
    fprintf(fid, ' %s', strrep(meta.startTime, '.', ':'));
    if ~isempty(meta.startDate)
      fprintf(fid, ' %s', meta.startDate);
    end
  end
  fprintf(fid, '\n');
  resolution = wfdbResolution(format);
  for k = 1:count
    series = raw{k};
    checksum = mod(sum(series), 65536);
    if checksum > 32767
      checksum = checksum - 65536;
    end
    initial = 0;
    if ~isempty(series)
      initial = series(1);
    end
    gain = signals(k).gain;
    baseline = round(signals(k).baseline);
    unit = strrep(char(signals(k).unit), ' ', '_');
    if isempty(unit)
      unit = 'mV';
    end
    label = char(signals(k).label);
    formatField = sprintf('%d', format);
    if spf(k) > 1
      formatField = sprintf('%dx%d', format, spf(k));
    end
    % file format gain(baseline)/units adcres adczero initial checksum block
    % description. The baseline is written both in the bracket and as the ADC
    % zero, so a reader that trusts either reads the same value.
    fprintf(fid, '%s %s %g(%d)/%s %d %d %d %d 0 %s\n', datName, formatField, ...
    gain, baseline, unit, resolution, baseline, initial, checksum, label);
  end
  for index = 1:numel(meta.comments)
    fprintf(fid, '# %s\n', meta.comments{index});
  end
  fclose(fid);
end
%=============================================================================
function bits = wfdbResolution(format)
  switch format
    case 80
      bits = 8;
    case {310, 311}
      bits = 10;
    case 212
      bits = 12;
    case {16, 61, 160}
      bits = 16;
    case {24, 32}
      bits = 24;
    otherwise
      bits = 16;
  end
end
%=============================================================================
function extension = wfdbAnnotationExtension(which, annotations)
  has = ~isempty(annotations) && isstruct(annotations) && ...
  isfield(annotations, 'sample') && ~isempty(annotations.sample);
  if isequal(which, false)
    extension = '';
    return;
  end
  if ischar(which) || isStringScalar(which)
    which = char(which);
  else
    error('wfdb:badWriteAnnotationsOption', 'Annotations must be ''auto'', an extension or false.');
  end
  if strcmpi(which, 'auto')
    extension = '';
    if has
      extension = 'atr';
    end
    return;
  end
  if ~isempty(which) && which(1) == '.'
    which = which(2:end);
  end
  extension = which;
end
%=============================================================================
