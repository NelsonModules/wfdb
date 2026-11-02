%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the wfdb module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
if ~ismodule('wfdb')
  run([fileparts(nfilename('fullpath')), '/../loader.m']);
end
% The annotation writer is proved by the reader: a set of marks with sticky
% num and channel, a one-shot subtype, an aux text and a gap too large for ten
% bits is written and read back unchanged.
%=============================================================================
folder = strrep(tempname(), char(92), '/');
mkdir(folder);
%=============================================================================
rate = 250;
sample = [1; 100; 2000; 2000000];
symbol = ['N'; 'V'; '+'; 'N'];
num = [0; 0; 3; 3];
subtype = [0; 2; 0; 0];
chan = [0; 0; 0; 1];
aux = {''; ''; '(N'; ''};
code = zeros(4, 1);
for k = 1:4
  code(k) = double('?');
end
ann = struct('kind', 'wfdb.annotations', 'sample', sample, ...
  'time', (sample - 1) / rate, 'code', code, 'symbol', symbol, 'num', num, ...
  'subtype', subtype, 'chan', chan, 'aux', {aux}, 'rate', rate);
%=============================================================================
% Written as a sidecar of a record, read back by the record reader.
r = struct();
r.rate = rate;
r.signals = struct('data', {round(100 * sin((1:4000)' / 10))}, ...
  'label', {'MLII'}, 'unit', {'mV'}, 'gain', {200}, 'baseline', {0}, ...
  'spf', {1}, 'format', {16});
r.annotations = ann;
wfdb.write([folder, '/rec'], r, 'Format', 16);
b = wfdb.read([folder, '/rec']);
assert_isequal(b.annotations.sample, sample);
assert_isequal(reshape(b.annotations.symbol, [], 1), symbol);
assert_isequal(b.annotations.num, num);
assert_isequal(b.annotations.subtype, subtype);
assert_isequal(b.annotations.chan, chan);
assert_isequal(b.annotations.aux, aux);
%=============================================================================
% The standalone annotation reader and writer, with the rate from the sibling
% header.
a = wfdb.annotations([folder, '/rec.atr']);
assert_isequal(a.sample, sample);
assert_isequal(a.rate, rate);
wfdb.annotations([folder, '/copy.atr'], a);
a2 = wfdb.annotations([folder, '/copy.atr'], 'Rate', rate);
assert_isequal(a2.sample, sample);
assert_isequal(reshape(a2.symbol, [], 1), symbol);
%=============================================================================
rmdir(folder, 's');
%=============================================================================
