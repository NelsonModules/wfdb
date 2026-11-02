%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the wfdb module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function r = crop(r, window, varargin)
  % R = wfdb.crop(R, [T0 T1]) keeps only the window from T0 to T1 seconds of the
  % struct R from wfdb.read: every signal is cut to that span (at its own rate),
  % and the annotations in it are kept and shifted to start at zero. The window
  % is measured at the base rate, so all signals are cut at the same instant.
  %
  % R = wfdb.crop(R, [I J], 'Frames', true) takes the window as frame indices
  % (one based, inclusive) instead of seconds.
  %
  % See also wfdb.read, wfdb.select.
  narginchk(2, inf);
  nargoutchk(0, 1);
  if ~isstruct(r) || ~isfield(r, 'signals')
    error('wfdb:badStruct', 'The first argument must be a struct from wfdb.read.');
  end
  if numel(window) ~= 2 || ~(window(2) > window(1))
    error('wfdb:badWindow', 'The window must be two values with the second greater than the first.');
  end
  byFrames = wfdbCropByFrames(varargin);
  if byFrames
    firstFrame = max(1, round(window(1)));
    lastFrame = round(window(2));
  else
    firstFrame = floor(window(1) * r.rate) + 1;
    lastFrame = floor(window(2) * r.rate);
  end
  firstFrame = max(1, firstFrame);
  for k = 1:numel(r.signals)
    spf = max(r.signals(k).spf, 1);
    data = r.signals(k).data;
    nframes = floor(numel(data) / spf);
    last = min(lastFrame, nframes);
    if last < firstFrame
      r.signals(k).data = zeros(0, 1);
      continue;
    end
    from = (firstFrame - 1) * spf + 1;
    to = last * spf;
    r.signals(k).data = data(from:to);
  end
  % The annotations are at the base rate: keep those inside the window and move
  % their sample index so the cropped record starts at sample one.
  if isfield(r, 'annotations') && isfield(r.annotations, 'sample') && ...
    ~isempty(r.annotations.sample)
    r.annotations = wfdbCropAnnotations(r.annotations, firstFrame, lastFrame);
  end
end
%=============================================================================
function byFrames = wfdbCropByFrames(args)
  byFrames = false;
  if mod(numel(args), 2) ~= 0
    error('wfdb:badOptions', 'Options come in name-value pairs.');
  end
  for k = 1:2:numel(args)
    name = args{k};
    if ~ischar(name) && ~isStringScalar(name)
      error('wfdb:badOptionName', 'An option name must be text.');
    end
    if strcmpi(char(name), 'frames')
      byFrames = logical(args{k + 1});
    else
      error('wfdb:unknownOption', 'Unknown option %s.', char(name));
    end
  end
end
%=============================================================================
function a = wfdbCropAnnotations(a, firstFrame, lastFrame)
  keep = a.sample >= firstFrame & a.sample <= lastFrame;
  a.sample = a.sample(keep) - (firstFrame - 1);
  a.time = (a.sample - 1) / a.rate;
  a.code = a.code(keep);
  a.symbol = a.symbol(keep);
  a.num = a.num(keep);
  a.subtype = a.subtype(keep);
  a.chan = a.chan(keep);
  a.aux = a.aux(keep);
end
%=============================================================================
