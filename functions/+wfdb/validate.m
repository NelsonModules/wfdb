%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the wfdb module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function report = validate(name)
  % REPORT = wfdb.validate(NAME) checks a WFDB record for the faults a reader
  % cannot otherwise see: a header that does not parse, a signal file that is
  % missing or too short for the samples it promises, and a signal whose samples
  % do not sum to the checksum the header stores. The checksum is the format's
  % own guard against a file truncated on disk, and this is the one place it is
  % verified.
  %
  % REPORT has fields ok (true when nothing is wrong) and issues (a cellstr of
  % what is). A single-segment record is checked in full; a multi-segment record
  % is reported as not checked here (each segment is its own record to validate).
  %
  % See also wfdb.read, wfdb.header.
  narginchk(1, 1);
  nargoutchk(0, 1);
  if ~ischar(name) && ~isStringScalar(name)
    error('wfdb:badName', 'The record name must be text.');
  end
  base = wfdbBaseName(char(name));
  issues = {};
  if ~isfile([base, '.hea'])
    report = struct('ok', false, 'issues', {{sprintf('The header %s.hea is not on disk.', base)}});
    return;
  end
  try
    described = wfdbReadHeader([base, '.hea']);
  catch reason
    report = struct('ok', false, 'issues', {{reason.message}});
    return;
  end
  if described.multiSegment
    report = struct('ok', true, 'issues', {{'Multi-segment record; validate each segment on its own.'}});
    return;
  end
  try
    r = wfdb.read([base, '.hea'], 'Physical', false, 'Annotations', false);
  catch reason
    report = struct('ok', false, 'issues', {{reason.message}});
    return;
  end
  for k = 1:numel(r.signals)
    s = r.signals(k);
    stored = s.checksum;
    % A stored checksum of zero is the writer saying it computed none, so it is
    % not held against the signal.
    if stored == 0
      continue;
    end
    actual = mod(sum(s.data), 65536);
    if actual > 32767
      actual = actual - 65536;
    end
    if actual ~= stored
      issues{end + 1} = sprintf('Signal %d (%s) checksum is %d but the header says %d.', k, s.label, actual, stored);
    end
  end
  report = struct('ok', isempty(issues), 'issues', {issues});
end
%=============================================================================
