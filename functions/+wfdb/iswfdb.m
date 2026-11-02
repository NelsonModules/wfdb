%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the wfdb module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function tf = iswfdb(name)
  % TF = wfdb.iswfdb(NAME) is true when NAME names a WFDB record whose header is
  % on disk and parses: the record line and one signal (or segment) line per
  % signal it announces. It reads no samples, so it is cheap to ask before
  % trying to read a file of an unknown kind.
  %
  % See also wfdb.read, wfdb.header.
  narginchk(1, 1);
  nargoutchk(0, 1);
  tf = false;
  if ~ischar(name) && ~isStringScalar(name)
    return;
  end
  base = wfdbBaseName(char(name));
  if ~isfile([base, '.hea'])
    return;
  end
  try
    wfdbReadHeader([base, '.hea']);
    tf = true;
  catch
    tf = false;
  end
end
%=============================================================================
