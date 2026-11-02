%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the wfdb module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
addpath([modulepath('wfdb'), '/functions'], '-frozen');
if isdir([modulepath('wfdb'), '/locale'])
  [status, message] = i18nHelpers('register', 'wfdb', modulepath('wfdb'));
  if ~status
    warning(message);
  end
end
%=============================================================================
