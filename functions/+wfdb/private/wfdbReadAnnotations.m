%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the wfdb module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function annotations = wfdbReadAnnotations(path, rate)
  % Read a MIT-format annotation file into the module's annotation struct.
  % Each annotation is a sixteen bit word, least significant byte first: the
  % top six bits are the code and the low ten are the samples since the last
  % mark. Five codes are not marks but instructions: 59 carries a long gap in
  % the two words after it, 60 a num, 61 a subtype, 62 a channel, 63 a text;
  % a zero word ends the file. Getting the gap arithmetic wrong shifts every
  % mark after it, which is why the count is rebuilt here exactly once.
  if ~isfile(path)
    error('wfdb:noAnnotationFile', 'The file %s is not on disk.', path);
  end
  fid = fopen(path, 'rb');
  if fid < 0
    error('wfdb:cannotReadAnnotationFile', 'The file %s cannot be read.', path);
  end
  bytes = double(fread(fid, inf, 'uint8'));
  fclose(fid);
  bytes = reshape(bytes, 1, numel(bytes));
  nwords = floor(numel(bytes) / 2);
  words = bytes(1:2:2 * nwords) + 256 * bytes(2:2:2 * nwords);
  % Each annotation is at least one word, so the word count is a safe upper
  % bound to preallocate to: a long-term record holds over a hundred thousand
  % marks and growing the vectors one mark at a time would be quadratic.
  sample = zeros(nwords, 1);
  code = zeros(nwords, 1);
  num = zeros(nwords, 1);
  subtype = zeros(nwords, 1);
  chan = zeros(nwords, 1);
  aux = cell(nwords, 1);
  count = 0;
  at = 0;
  currentNum = 0;
  currentChan = 0;
  nextSubtype = 0;
  index = 1;
  while index <= nwords
    word = words(index);
    annotationCode = floor(word / 1024);
    gap = word - 1024 * annotationCode;
    index = index + 1;
    if annotationCode == 0 && gap == 0
      break;
    end
    if annotationCode == 59
      % The gap did not fit in ten bits: the next two words carry it, the
      % high half first, as a SIGNED thirty two bit number. A record that
      % opens with a gap of minus one and a mark one sample on lands that mark
      % at sample one; read unsigned, minus one is four billion samples away.
      if index + 1 > nwords
        break;
      end
      longGap = 65536 * words(index) + words(index + 1);
      if longGap >= 2147483648
        longGap = longGap - 4294967296;
      end
      index = index + 2;
      at = at + longGap;
      continue;
    end
    if annotationCode == 60
      % Num sets this mark and every one after it, until changed.
      value = wfdbSigned10(gap);
      currentNum = value;
      if count > 0
        num(count) = value;
      end
      continue;
    end
    if annotationCode == 61
      % Subtype touches only the next mark.
      nextSubtype = wfdbSigned10(gap);
      continue;
    end
    if annotationCode == 62
      % Channel sets this mark and every one after it, until changed.
      value = wfdbSigned10(gap);
      currentChan = value;
      if count > 0
        chan(count) = value;
      end
      continue;
    end
    if annotationCode == 63
      % A text of the low ten bits' byte count, padded to an even length, and
      % the name the recorder gave the mark it follows. It begins at the byte
      % after this word and is stepped over by its own length rounded up to a
      % whole word, so the clock is not moved by a letter.
      first = 2 * index - 1;
      piece = bytes(first:min(numel(bytes), first + gap - 1));
      text = char(piece);
      while ~isempty(text) && text(end) == 0
        text(end) = [];
      end
      if count > 0
        aux{count} = text;
      end
      index = index + ceil(gap / 2);
      continue;
    end
    % An ordinary mark: its gap advances the clock, and it takes the sticky
    % num and channel and the one-shot subtype.
    at = at + gap;
    count = count + 1;
    sample(count) = at + 1;
    code(count) = annotationCode;
    num(count) = currentNum;
    chan(count) = currentChan;
    subtype(count) = nextSubtype;
    nextSubtype = 0;
    aux{count} = '';
  end
  sample = sample(1:count);
  code = code(1:count);
  num = num(1:count);
  subtype = subtype(1:count);
  chan = chan(1:count);
  aux = aux(1:count);
  symbol = repmat('?', count, 1);
  for index = 1:count
    symbol(index) = wfdbCodes(code(index));
  end
  annotations = wfdbAnnotationStruct(sample, code, symbol, num, subtype, ...
  chan, aux, rate);
end
%=============================================================================
function value = wfdbSigned10(value)
  % The num, subtype and channel words carry a signed char in their low ten
  % bits: a value written with the top bit of the byte set reads back negative.
  if value >= 512
    value = value - 1024;
  end
end
%=============================================================================
