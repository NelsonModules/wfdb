%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the wfdb module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function base = wfdbBaseName(name)
  % A record is named with or without its .hea extension, because both are what
  % a caller has in hand; this strips a trailing .hea so the base name is the
  % one thing the rest of the module works from.
  base = name;
  if numel(base) > 4 && strcmpi(base(end - 3:end), '.hea')
    base = base(1:end - 4);
  end
end
%=============================================================================
