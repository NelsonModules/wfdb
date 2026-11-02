%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the wfdb module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function r = header(name)
  % R = wfdb.header(NAME) reads only the header of a WFDB record: the same
  % neutral struct wfdb.read returns, but with no samples and no annotations, so
  % the signals, their formats, gains and rates can be inspected without lifting
  % a long record off the disk.
  %
  % See also wfdb.read, wfdb.info.
  narginchk(1, 1);
  nargoutchk(0, 1);
  r = wfdb.read(name, 'Data', false, 'Annotations', false);
end
%=============================================================================
