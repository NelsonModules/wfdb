%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the wfdb module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function a = wfdbAnnotationStruct(sample, code, symbol, num, subtype, chan, aux, rate)
  % The one shape every annotation in this module takes: a struct of COLUMN
  % VECTORS of one length, never a struct array, because a long-term record
  % carries over a hundred thousand marks and a struct array of that many
  % elements is slow to build and slow to touch. Both the raw numeric code and
  % its one-character PhysioNet symbol are kept, so a reserved code a domain
  % does not name still round-trips.
  sample = double(sample(:));
  n = numel(sample);
  a = struct();
  a.kind = 'wfdb.annotations';
  a.sample = sample;
  if n == 0
    a.time = zeros(0, 1);
    a.code = zeros(0, 1);
    a.symbol = repmat(' ', 0, 1);
    a.num = zeros(0, 1);
    a.subtype = zeros(0, 1);
    a.chan = zeros(0, 1);
    a.aux = cell(0, 1);
    a.rate = rate;
    return;
  end
  a.time = (sample - 1) / rate;
  a.code = double(code(:));
  a.symbol = reshape(char(symbol), n, 1);
  a.num = double(num(:));
  a.subtype = double(subtype(:));
  a.chan = double(chan(:));
  if ischar(aux)
    aux = cellstr(aux);
  end
  a.aux = reshape(aux, n, 1);
  a.rate = rate;
end
%=============================================================================
