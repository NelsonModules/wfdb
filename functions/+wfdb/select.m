%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the wfdb module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function r = select(r, which)
  % R = wfdb.select(R, WHICH) keeps only some signals of the struct R from
  % wfdb.read, by label (a char or cellstr) or by index, in the order asked. The
  % header, the annotations and everything else are left as they are; only the
  % signals array is narrowed, so a record read once can be cut down without
  % reading it again.
  %
  % See also wfdb.read, wfdb.crop.
  narginchk(2, 2);
  nargoutchk(0, 1);
  if ~isstruct(r) || ~isfield(r, 'signals')
    error('wfdb:badStruct', 'The first argument must be a struct from wfdb.read.');
  end
  labels = {r.signals.label};
  if isnumeric(which)
    keep = round(which(:)');
    if any(keep < 1) || any(keep > numel(labels))
      error('wfdb:badSignalIndex', 'A signal index is outside the range 1 to %d.', numel(labels));
    end
  else
    if ischar(which) || isStringScalar(which)
      which = cellstr(which);
    end
    keep = zeros(1, numel(which));
    for index = 1:numel(which)
      match = find(strcmp(char(which{index}), labels), 1);
      if isempty(match)
        error('wfdb:noSuchSignal', 'No signal is labelled %s.', char(which{index}));
      end
      keep(index) = match;
    end
  end
  r.signals = r.signals(keep);
  if isfield(r, 'multiFrequency')
    r.multiFrequency = any([r.signals.spf] > 1);
  end
end
%=============================================================================
