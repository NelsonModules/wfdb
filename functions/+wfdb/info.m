%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the wfdb module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function text = info(name)
  % wfdb.info(NAME) prints a short human-readable summary of a WFDB record: its
  % name, rate, length and the label, format, gain and unit of every signal.
  % TEXT = wfdb.info(NAME) returns that summary as text instead of printing it.
  % It reads the header only, so it is cheap on a long record.
  %
  % See also wfdb.header, wfdb.read.
  narginchk(1, 1);
  nargoutchk(0, 1);
  r = wfdb.header(name);
  lines = {};
  lines{end + 1} = sprintf('Record %s', r.name);
  lines{end + 1} = sprintf('  rate       : %g Hz', r.rate);
  if r.declaredFrames > 0
    lines{end + 1} = sprintf('  length     : %d frames (%.3f s)', ...
    r.declaredFrames, r.declaredFrames / r.rate);
  end
  if r.startTimeKnown
    when = r.startTime;
    if ~isempty(r.startDate)
      when = [when, ' ', r.startDate];
    end
    lines{end + 1} = sprintf('  start      : %s', when);
  end
  if r.multiSegment
    lines{end + 1} = sprintf('  segments   : %d', numel(r.segments));
  end
  lines{end + 1} = sprintf('  signals    : %d', numel(r.signals));
  for k = 1:numel(r.signals)
    s = r.signals(k);
    lines{end + 1} = sprintf('    %2d %-12s format %-4d gain %g/%s', k, ...
    s.label, s.format, s.gain, s.unit);
  end
  for k = 1:numel(r.comments)
    lines{end + 1} = sprintf('  # %s', r.comments{k});
  end
  joined = wfdbJoinLines(lines);
  if nargout == 0
    disp(joined);
  else
    text = joined;
  end
end
%=============================================================================
function joined = wfdbJoinLines(lines)
  joined = '';
  for k = 1:numel(lines)
    if k == 1
      joined = lines{k};
    else
      joined = [joined, char(10), lines{k}];
    end
  end
end
%=============================================================================
