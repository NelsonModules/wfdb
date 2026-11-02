%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the wfdb module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function wfdbWriteAnnotations(path, annotations)
  % Write the module's annotations in the MIT format so that wfdb.read reads
  % them back unchanged. Each mark is a sixteen bit word, the code in the top
  % six bits and the gap from the last mark in the low ten; a gap that does not
  % fit in ten bits is carried by a skip word, a non-empty aux by a text word,
  % and a num, subtype or channel by their own words, emitted only when they
  % change so the file stays as small as the reference writer's.
  sample = annotations.sample(:);
  symbol = reshape(annotations.symbol, [], 1);
  num = annotations.num(:);
  subtype = annotations.subtype(:);
  chan = annotations.chan(:);
  aux = annotations.aux(:);
  count = numel(sample);
  % Each mark contributes a handful of byte chunks; collecting them in a cell
  % and joining once keeps the writer linear, since a long-term record holds
  % over a hundred thousand marks and growing one byte array would be
  % quadratic.
  chunks = cell(1, 0);
  at = 0;
  runningNum = 0;
  runningChan = 0;
  for index = 1:count
    fileTime = sample(index) - 1;
    gap = fileTime - at;
    interval = gap;
    if gap > 1023 || gap < 0
      % The gap is too large (or a rare step backwards): a skip word carries
      % it as a signed thirty two bit number, high half first, and the mark's
      % own interval is then zero.
      long = mod(gap, 4294967296);
      chunks{end + 1} = [wfdbWord(59 * 1024), ...
      wfdbWord(floor(long / 65536)), wfdbWord(mod(long, 65536))];
      interval = 0;
    end
    % The subtype touches only the next mark, so it is written before the mark
    % it belongs to; a zero subtype is the default and is not written.
    if subtype(index) ~= 0
      chunks{end + 1} = wfdbWord(61 * 1024 + mod(subtype(index), 1024));
    end
    code = wfdbCodes(symbol(index));
    chunks{end + 1} = wfdbWord(code * 1024 + interval);
    % The channel and the num stick until they change, so they are written
    % after the mark that first carries the new value.
    if chan(index) ~= runningChan
      chunks{end + 1} = wfdbWord(62 * 1024 + mod(chan(index), 1024));
      runningChan = chan(index);
    end
    if num(index) ~= runningNum
      chunks{end + 1} = wfdbWord(60 * 1024 + mod(num(index), 1024));
      runningNum = num(index);
    end
    text = aux{index};
    if ~isempty(text)
      % The text is null-terminated and its byte count padded to an even
      % length, the same shape the reference files carry, so a reader steps
      % over exactly the right number of bytes.
      payload = [double(char(text)), 0];
      written = payload;
      if mod(numel(written), 2) == 1
        written(end + 1) = 0;
      end
      chunks{end + 1} = [wfdbWord(63 * 1024 + numel(payload)), written];
    end
    at = fileTime;
  end
  % A zero word ends the file.
  chunks{end + 1} = wfdbWord(0);
  bytes = [chunks{:}];
  fid = fopen(path, 'wb');
  if fid < 0
    error('wfdb:cannotWriteAnnotationFile', 'The file %s cannot be written.', path);
  end
  fwrite(fid, bytes, 'uint8');
  fclose(fid);
end
%=============================================================================
function bytes = wfdbWord(value)
  value = mod(value, 65536);
  bytes = [mod(value, 256), floor(value / 256)];
end
%=============================================================================
