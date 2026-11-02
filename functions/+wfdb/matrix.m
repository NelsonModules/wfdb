%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the wfdb module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function m = matrix(r)
  % M = wfdb.matrix(R) turns the per-signal struct R from wfdb.read into one
  % matrix, one column per signal, every column at the same rate. A signal
  % recorded slower than the fastest (a multi-frequency record) is held sample
  % by sample across the frame so the columns line up; a single-rate record is
  % just stacked. The samples are whatever R holds, raw or physical, so the
  % physical choice is made once, at the read.
  %
  % M has fields: samples (N x L), rate (the top rate), leads (1 x L cellstr of
  % the signal labels), units (1 x L cellstr), gain and baseline (1 x L), and
  % spf (1 x L samples per frame). Reading a record and taking its matrix is
  % the common case; a caller that needs the native rate of a slow signal keeps
  % R.signals instead.
  narginchk(1, 1);
  nargoutchk(0, 1);
  if ~isstruct(r) || ~isfield(r, 'signals')
    error('wfdb:badStruct', 'The first argument must be a struct from wfdb.read.');
  end
  signals = r.signals;
  count = numel(signals);
  if isfield(r, 'rate')
    baseRate = r.rate;
  else
    baseRate = 1;
  end
  m = struct();
  if count == 0
    m.samples = zeros(0, 0);
    m.rate = baseRate;
    m.leads = {};
    m.units = {};
    m.gain = [];
    m.baseline = [];
    m.spf = [];
    return;
  end
  spf = [signals.spf];
  maxspf = max(spf);
  frames = zeros(1, count);
  for k = 1:count
    frames(k) = floor(numel(signals(k).data) / max(spf(k), 1));
  end
  nframes = max(frames);
  rows = nframes * maxspf;
  samples = nan(rows, count);
  for k = 1:count
    samples(:, k) = wfdbHold(signals(k).data, spf(k), maxspf, nframes);
  end
  m.samples = samples;
  m.rate = baseRate * maxspf;
  m.leads = {signals.label};
  m.units = {signals.unit};
  m.gain = [signals.gain];
  m.baseline = [signals.baseline];
  m.spf = spf;
end
%=============================================================================
function column = wfdbHold(series, spf, maxspf, nframes)
  % Hold each sample of a slower signal so it spans the whole frame: output
  % position j sits in frame f and slot p and takes the native sample whose
  % place in the frame is ceil(p * spf / maxspf), the last sample at or before
  % j. A signal already at the top rate is returned unchanged. A signal shorter
  % than the record (a stitched gap) is padded with NaN so its column keeps the
  % record's length.
  series = series(:);
  need = nframes * spf;
  if numel(series) < need
    series = [series; nan(need - numel(series), 1)];
  end
  if spf == maxspf
    column = series(1:nframes * maxspf);
    return;
  end
  position = (0:nframes * maxspf - 1)';
  frame = floor(position / maxspf);
  slot = mod(position, maxspf) + 1;
  within = ceil(slot * spf / maxspf);
  source = frame * spf + within;
  column = series(source);
end
%=============================================================================
