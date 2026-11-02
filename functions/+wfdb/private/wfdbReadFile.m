%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the wfdb module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function values = wfdbReadFile(path, format, offset)
  % Read one signal file in a single pass and decode its bytes into the flat
  % integer stream it holds. A compressed format is refused before the file is
  % even opened, so a reader is told the record is FLAC rather than handed raw
  % bytes it would misread as integers; the message names the format it saw.
  if format == 508 || format == 516 || format == 524
    error('wfdb:compressedFormat', 'Format %d (FLAC) is compressed and is not read.', format);
  end
  if ~isfile(path)
    error('wfdb:noSignalFile', 'The file %s is not on disk.', path);
  end
  fid = fopen(path, 'rb');
  if fid < 0
    error('wfdb:cannotReadSignalFile', 'The file %s cannot be read.', path);
  end
  bytes = double(fread(fid, inf, 'uint8'));
  fclose(fid);
  bytes = reshape(bytes, 1, numel(bytes));
  if offset > 0
    bytes = bytes(min(numel(bytes), offset) + 1:end);
  end
  values = wfdbDecode(bytes, format);
end
%=============================================================================
