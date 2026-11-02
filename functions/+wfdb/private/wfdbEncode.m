%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the wfdb module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function bytes = wfdbEncode(values, format)
  % Pack a flat stream of integer samples (already interleaved frame by frame)
  % into the bytes of a WFDB signal file. This is the exact inverse of the
  % decoder: the same two's-complement and offset-binary conventions, so a
  % record written here and read back is the record that went in. Every
  % non-differential format the decoder reads can also be written, so a record
  % keeps its on-disk packing across a round trip; the differential format 8 is
  % a legacy compression a writer has no reason to produce and is refused.
  values = double(reshape(values, 1, numel(values)));
  switch format
    case 16
      word = mod(values, 65536);
      bytes = zeros(1, 2 * numel(word));
      bytes(1:2:end) = mod(word, 256);
      bytes(2:2:end) = floor(word / 256);
    case 61
      % Sixteen bit, most significant byte first.
      word = mod(values, 65536);
      bytes = zeros(1, 2 * numel(word));
      bytes(1:2:end) = floor(word / 256);
      bytes(2:2:end) = mod(word, 256);
    case 80
      % Eight bit offset binary: the stored zero is 128.
      bytes = mod(values + 128, 256);
    case 160
      % Sixteen bit offset binary, least significant byte first.
      word = mod(values + 32768, 65536);
      bytes = zeros(1, 2 * numel(word));
      bytes(1:2:end) = mod(word, 256);
      bytes(2:2:end) = floor(word / 256);
    case 212
      % Two twelve bit samples in three bytes; an odd count is padded with a
      % zero so the last pair is whole, and the reader stops at the sample
      % count the header declares, so the pad is never returned.
      values = wfdbPad(values, 2);
      word = mod(values, 4096);
      one = word(1:2:end);
      two = word(2:2:end);
      bytes = zeros(1, 3 * numel(one));
      bytes(1:3:end) = mod(one, 256);
      bytes(2:3:end) = floor(one / 256) + 16 * floor(two / 256);
      bytes(3:3:end) = mod(two, 256);
    case 24
      word = mod(values, 16777216);
      bytes = zeros(1, 3 * numel(word));
      bytes(1:3:end) = mod(word, 256);
      bytes(2:3:end) = mod(floor(word / 256), 256);
      bytes(3:3:end) = floor(word / 65536);
    case 32
      word = mod(values, 4294967296);
      bytes = zeros(1, 4 * numel(word));
      bytes(1:4:end) = mod(word, 256);
      bytes(2:4:end) = mod(floor(word / 256), 256);
      bytes(3:4:end) = mod(floor(word / 65536), 256);
      bytes(4:4:end) = floor(word / 16777216);
    case 310
      % Three ten bit samples in four bytes as two little-endian words, the low
      % bit of each word unused; a count not a multiple of three is padded.
      values = wfdbPad(values, 3);
      word = mod(values, 1024);
      s0 = word(1:3:end);
      s1 = word(2:3:end);
      s2 = word(3:3:end);
      w0 = s0 * 2 + mod(s2, 32) * 2048;
      w1 = s1 * 2 + mod(floor(s2 / 32), 32) * 2048;
      bytes = zeros(1, 4 * numel(s0));
      bytes(1:4:end) = mod(w0, 256);
      bytes(2:4:end) = floor(w0 / 256);
      bytes(3:4:end) = mod(w1, 256);
      bytes(4:4:end) = floor(w1 / 256);
    case 311
      % Three ten bit samples in four bytes as one little-endian value, the two
      % highest bits unused; a count not a multiple of three is padded.
      values = wfdbPad(values, 3);
      word = mod(values, 1024);
      s0 = word(1:3:end);
      s1 = word(2:3:end);
      s2 = word(3:3:end);
      value = s0 + 1024 * s1 + 1048576 * s2;
      bytes = zeros(1, 4 * numel(s0));
      bytes(1:4:end) = mod(value, 256);
      bytes(2:4:end) = mod(floor(value / 256), 256);
      bytes(3:4:end) = mod(floor(value / 65536), 256);
      bytes(4:4:end) = floor(value / 16777216);
    case 8
      error('wfdb:differentialFormat', 'Format 8 (first differences) is a legacy compression and is not written.');
    otherwise
      error('wfdb:badWriteFormat', 'Format %d is not a WFDB signal format this writer knows.', format);
  end
end
%=============================================================================
function values = wfdbPad(values, group)
  % Pad the stream with trailing zeros so its length is a whole number of
  % GROUP samples; the reader stops at the header's declared sample count, so
  % the pad is never returned.
  extra = mod(numel(values), group);
  if extra ~= 0
    values(end + 1:end + group - extra) = 0;
  end
end
%=============================================================================
