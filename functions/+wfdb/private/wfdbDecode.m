%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the wfdb module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function values = wfdbDecode(bytes, format)
  % Turn a signal file's bytes into the flat stream of integer samples it
  % holds, in the order they were written (frame by frame for an interleaved
  % file). Every packing the open databases use is here: a misread of one
  % bit gives a signal that looks like a biosignal and is not, so each packing
  % is done in one vectorised pass (a record is 650000 samples long and a loop
  % over samples would take seconds) and each sign is taken once, explicitly.
  %
  % Format 8 is the exception that cannot be finished here: its bytes are
  % signed first differences and the running sum that rebuilds the signal must
  % start from the header's initial value, per signal, after the frames are
  % split apart; this returns the differences and the caller integrates them.
  bytes = double(reshape(bytes, 1, numel(bytes)));
  switch format
    case 8
      % Signed eight bit differences.
      values = bytes;
      values(values > 127) = values(values > 127) - 256;
    case 16
      values = wfdbWords16(bytes, true);
    case 61
      % Sixteen bit, most significant byte first.
      values = wfdbWords16(bytes, false);
    case 80
      % Eight bit offset binary: the stored zero is 128.
      whole = numel(bytes);
      values = bytes(1:whole) - 128;
    case 160
      % Sixteen bit offset binary, least significant byte first: zero is
      % 32768.
      whole = floor(numel(bytes) / 2);
      low = bytes(1:2:2 * whole);
      high = bytes(2:2:2 * whole);
      values = low + 256 * high - 32768;
    case 212
      values = wfdbTwelve(bytes);
    case 24
      % Signed twenty four bit, least significant byte first.
      whole = floor(numel(bytes) / 3);
      b0 = bytes(1:3:3 * whole);
      b1 = bytes(2:3:3 * whole);
      b2 = bytes(3:3:3 * whole);
      values = b0 + 256 * b1 + 65536 * b2;
      top = values > 8388607;
      values(top) = values(top) - 16777216;
    case 32
      % Signed thirty two bit, least significant byte first.
      whole = floor(numel(bytes) / 4);
      b0 = bytes(1:4:4 * whole);
      b1 = bytes(2:4:4 * whole);
      b2 = bytes(3:4:4 * whole);
      b3 = bytes(4:4:4 * whole);
      values = b0 + 256 * b1 + 65536 * b2 + 16777216 * b3;
      top = values > 2147483647;
      values(top) = values(top) - 4294967296;
    case 310
      values = wfdbTen310(bytes);
    case 311
      values = wfdbTen311(bytes);
    case {508, 516, 524}
      error('wfdb:compressedFormat', 'Format %d (FLAC) is compressed and is not read.', format);
    otherwise
      error('wfdb:unknownFormat', 'Format %d is not a WFDB signal format this reader knows.', format);
  end
end
%=============================================================================
function values = wfdbWords16(bytes, littleFirst)
  whole = floor(numel(bytes) / 2);
  if littleFirst
    low = bytes(1:2:2 * whole);
    high = bytes(2:2:2 * whole);
  else
    high = bytes(1:2:2 * whole);
    low = bytes(2:2:2 * whole);
  end
  values = low + 256 * high;
  values(values > 32767) = values(values > 32767) - 65536;
end
%=============================================================================
function values = wfdbTwelve(bytes)
  % Two twelve bit samples in three bytes: the first byte is the low eight
  % bits of the first sample, the low half of the second byte its top four,
  % the high half of the second byte the top four of the second sample, and
  % the third byte the second sample's low eight.
  whole = floor(numel(bytes) / 3);
  first = bytes(1:3:3 * whole);
  middle = bytes(2:3:3 * whole);
  last = bytes(3:3:3 * whole);
  one = first + 256 * mod(middle, 16);
  two = last + 256 * floor(middle / 16);
  one(one > 2047) = one(one > 2047) - 4096;
  two(two > 2047) = two(two > 2047) - 4096;
  values = zeros(1, 2 * whole);
  values(1:2:end) = one;
  values(2:2:end) = two;
end
%=============================================================================
function values = wfdbTen310(bytes)
  % Three ten bit samples in four bytes, as two little-endian sixteen bit
  % words: the low bit of each word is unused, the next ten bits are the first
  % and the second sample, and the top five bits of each word are the low and
  % the high half of the third sample.
  whole = floor(numel(bytes) / 4);
  b0 = bytes(1:4:4 * whole);
  b1 = bytes(2:4:4 * whole);
  b2 = bytes(3:4:4 * whole);
  b3 = bytes(4:4:4 * whole);
  w0 = b0 + 256 * b1;
  w1 = b2 + 256 * b3;
  s0 = mod(floor(w0 / 2), 1024);
  s1 = mod(floor(w1 / 2), 1024);
  s2 = mod(floor(w0 / 2048), 32) + 32 * mod(floor(w1 / 2048), 32);
  values = wfdbInterleave3(s0, s1, s2);
end
%=============================================================================
function values = wfdbTen311(bytes)
  % Three ten bit samples in four bytes, packed as one little-endian thirty
  % two bit value with the two highest bits unused: sample one is the low ten
  % bits, sample two the next ten, sample three the next ten.
  whole = floor(numel(bytes) / 4);
  b0 = bytes(1:4:4 * whole);
  b1 = bytes(2:4:4 * whole);
  b2 = bytes(3:4:4 * whole);
  b3 = bytes(4:4:4 * whole);
  value = b0 + 256 * b1 + 65536 * b2 + 16777216 * b3;
  s0 = mod(value, 1024);
  s1 = mod(floor(value / 1024), 1024);
  s2 = mod(floor(value / 1048576), 1024);
  values = wfdbInterleave3(s0, s1, s2);
end
%=============================================================================
function values = wfdbInterleave3(s0, s1, s2)
  % The three ten bit samples are signed, and the interleave puts them back in
  % the order they were stored.
  s0(s0 > 511) = s0(s0 > 511) - 1024;
  s1(s1 > 511) = s1(s1 > 511) - 1024;
  s2(s2 > 511) = s2(s2 > 511) - 1024;
  values = zeros(1, 3 * numel(s0));
  values(1:3:end) = s0;
  values(2:3:end) = s1;
  values(3:3:end) = s2;
end
%=============================================================================
