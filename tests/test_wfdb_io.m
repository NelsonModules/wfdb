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
% A writer is proved by the reader: a record of known integers is written in
% every packing the writer offers and read back, and the raw integers must come
% back unchanged. Every file here is written by the test, so nothing reaches the
% network.
%=============================================================================
folder = strrep(tempname(), char(92), '/');
mkdir(folder);
%=============================================================================
% Two signals of known integers, kept within the eight-bit offset format's
% range so that every format, down to format 80 and the ten-bit 310 and 311,
% holds them and the raw round-trip is exact for all of them.
n = 600;
d1 = round(100 * sin(2 * pi * (0:n - 1)' / 50));
d2 = round(60 * cos(2 * pi * (0:n - 1)' / 37)) - 5;
r = struct();
r.rate = 250;
r.name = 'rec';
r.signals = struct('data', {d1, d2}, 'label', {'MLII', 'V5'}, ...
  'unit', {'mV', 'mV'}, 'gain', {200, 200}, 'baseline', {0, 0}, ...
  'spf', {1, 1}, 'format', {16, 16});
%=============================================================================
% Every non-differential format the module reads can also be written, and the
% raw integers round-trip exactly.
formats = [16, 61, 80, 160, 212, 24, 32, 310, 311];
for f = formats
  path = [folder, '/rec'];
  info = wfdb.write(path, r, 'Format', f);
  assert_isequal(info.format, f);
  assert_isequal(info.frames, n);
  b = wfdb.read(path);
  assert_isequal(b.signals(1).data, d1);
  assert_isequal(b.signals(2).data, d2);
  assert_isequal(b.signals(1).label, 'MLII');
  assert_isequal(b.signals(2).label, 'V5');
  assert_isequal(b.rate, 250);
end
%=============================================================================
% The matrix view stacks the signals into one matrix at the common rate.
b = wfdb.read([folder, '/rec']);
m = wfdb.matrix(b);
assert_isequal(size(m.samples), [n, 2]);
assert_isequal(m.rate, 250);
assert_isequal(m.leads, {'MLII', 'V5'});
assert_isequal(m.samples(:, 1), d1);
%=============================================================================
% Physical samples: write millivolts with a gain, read them back within one
% quantisation step.
rp = r;
rp.signals(1).data = d1 / 200;
rp.signals(2).data = d2 / 200;
wfdb.write([folder, '/phys'], rp, 'Physical', true, 'Format', 16);
bp = wfdb.read([folder, '/phys'], 'Physical', true);
assert_istrue(max(abs(bp.signals(1).data - rp.signals(1).data)) <= 1 / 200);
%=============================================================================
% Header only: the signals and their rates are there, with no samples.
h = wfdb.header([folder, '/rec']);
assert_isequal(numel(h.signals), 2);
assert_isequal(numel(h.signals(1).data), 0);
assert_isequal(h.signals(1).rate, 250);
%=============================================================================
% A plain matrix, written and read back. The matrix is taken as physical, so a
% gain of one leaves the stored integers equal to the matrix.
samples = [d1, d2];
wfdb.write([folder, '/mat'], samples, 360, 'Leads', {'A', 'B'}, 'Gain', 1);
bm = wfdb.read([folder, '/mat']);
assert_isequal(bm.rate, 360);
assert_isequal(bm.signals(1).label, 'A');
assert_isequal(bm.signals(1).gain, 1);
assert_isequal(bm.signals(1).data, d1);
%=============================================================================
% A multi-frequency record: a signal at twice the frame rate keeps its own
% rate, and the matrix holds the slower one up to the faster.
rm = struct();
rm.rate = 100;
rm.signals = struct('data', {round(10 * (1:200)'), round(5 * (1:400)')}, ...
  'label', {'slow', 'fast'}, 'unit', {'mV', 'mV'}, 'gain', {100, 100}, ...
  'baseline', {0, 0}, 'spf', {1, 2}, 'format', {16, 16});
wfdb.write([folder, '/mf'], rm, 'Format', 16);
bmf = wfdb.read([folder, '/mf']);
assert_isequal(numel(bmf.signals(1).data), 200);
assert_isequal(numel(bmf.signals(2).data), 400);
assert_istrue(bmf.multiFrequency);
mmf = wfdb.matrix(bmf);
assert_isequal(size(mmf.samples, 1), 400);
assert_isequal(mmf.rate, 200);
%=============================================================================
% Signal selection by label and by index.
just = wfdb.read([folder, '/rec'], 'Signals', {'V5'});
assert_isequal(numel(just.signals), 1);
assert_isequal(just.signals(1).label, 'V5');
byIndex = wfdb.select(b, 2);
assert_isequal(byIndex.signals(1).label, 'V5');
%=============================================================================
% Crop keeps the window and the right number of samples.
c = wfdb.crop(b, [0, 1]);
assert_isequal(numel(c.signals(1).data), 250);
assert_isequal(c.signals(1).data, d1(1:250));
%=============================================================================
% A fixed-layout multi-segment record: the signals cut into pieces, a master
% header naming them, and wfdb.read stitches them back into the one record.
info = wfdb.write([folder, '/multi'], r, 'Segments', [200, 400], 'Format', 16);
assert_isequal(info.segments, 2);
assert_istrue(isfile([folder, '/multi_1.hea']));
assert_istrue(isfile([folder, '/multi_2.dat']));
ms = wfdb.read([folder, '/multi']);
assert_istrue(ms.multiSegment);
mm = wfdb.matrix(ms);
assert_isequal(size(mm.samples, 1), n);
assert_isequal(mm.samples(:, 1), d1);
assert_isequal(mm.samples(:, 2), d2);
% A scalar chunk size cuts the record into pieces of that many frames.
wfdb.write([folder, '/chunk'], r, 'Segments', 250, 'Format', 212);
chunk = wfdb.matrix(wfdb.read([folder, '/chunk']));
assert_isequal(size(chunk.samples, 1), n);
assert_isequal(chunk.samples(:, 1), d1);
% Segment lengths that do not sum to the record length are refused. The error
% is checked by its identifier, not its message, so the test holds whatever
% language the runtime translates the message into.
bad = struct('rate', 1, 'signals', struct('data', (1:10)', 'label', 'a', ...
  'unit', 'mV', 'gain', 1, 'baseline', 0, 'spf', 1, 'format', 16));
failed = false;
try
  wfdb.write([folder, '/bad'], bad, 'Segments', [3, 3]);
catch e
  failed = strcmp(e.identifier, 'wfdb:badSegmentsSum');
end
assert_istrue(failed);
%=============================================================================
% iswfdb and validate on a good record.
assert_istrue(wfdb.iswfdb([folder, '/rec']));
assert_isfalse(wfdb.iswfdb([folder, '/nope']));
report = wfdb.validate([folder, '/rec']);
assert_istrue(report.ok);
%=============================================================================
% Errors: a missing record, and a format the writer refuses. Checked by
% identifier so the test is independent of the runtime's language.
failed = false;
try
  wfdb.read([folder, '/nope']);
catch e
  failed = strcmp(e.identifier, 'wfdb:noHeaderFile');
end
assert_istrue(failed);
diff8 = struct('rate', 1, 'signals', struct('data', 1, 'label', 'a', ...
  'unit', 'mV', 'gain', 1, 'baseline', 0, 'spf', 1, 'format', 8));
failed = false;
try
  wfdb.write([folder, '/diff8'], diff8, 'Format', 8);
catch e
  failed = strcmp(e.identifier, 'wfdb:differentialFormat');
end
assert_istrue(failed);
%=============================================================================
rmdir(folder, 's');
%=============================================================================
