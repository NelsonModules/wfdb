%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the wfdb module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
% A tour of the wfdb toolbox: build a tiny two-lead record, write it, read it
% back and confirm the round trip, then look at the header, validate the
% checksums, and cut the record down.
%=============================================================================
if ~ismodule('wfdb')
  run([fileparts(nfilename('fullpath')), '/../loader.m']);
end
%=============================================================================
% Five seconds of two leads, in physical millivolts.
rate = 250;
t = (0:5 * rate - 1)' / rate;
samples = [sin(2 * pi * 1.3 * t), 0.5 * cos(2 * pi * 1.3 * t)];

% Write to a scratch record in the temporary folder. A plain matrix is taken as
% physical and quantised with the gain (200 adu per unit by default).
base = tempname();
info = wfdb.write(base, samples, rate, 'Leads', {'I', 'II'}, ...
  'Units', {'mV', 'mV'});
fprintf('Wrote %s: %d signal(s), %d frames, format %d.\n', ...
  info.name, info.signals, info.frames, info.format);

% A quick look at the header, without lifting the samples off the disk.
disp('--- wfdb.info ---');
wfdb.info(base);

% Read it back in physical units and check it matches what went in.
r = wfdb.read(base, 'Physical', true);
m = wfdb.matrix(r);
err = max(abs(m.samples(:) - samples(:)));
fprintf('\nRead %d signal(s) at %g Hz; max round-trip error %.2e mV.\n', ...
  numel(r.signals), r.rate, err);

% The checksum stored in the header is the format's guard against truncation.
report = wfdb.validate(base);
fprintf('Validate ok: %d (%d issue(s)).\n', report.ok, numel(report.issues));

% Keep only the first lead and the first two seconds.
clip = wfdb.crop(wfdb.select(r, {'I'}), [0, 2]);
fprintf('Cropped to lead %s, %g s.\n', clip.signals(1).label, ...
  numel(clip.signals(1).data) / clip.signals(1).rate);

% Clean up the scratch files.
rmfile([base, '.hea']);
rmfile([base, '.dat']);
%=============================================================================
