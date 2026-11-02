%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the wfdb module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function out = wfdbCodes(in)
  % The one table that maps an annotation code (1..41) to its PhysioNet
  % mnemonic and back, so the reader and the writer never disagree on what a
  % letter means. A numeric IN is a code and OUT is its one-character symbol;
  % a character IN is a symbol and OUT is its code. One table, read both ways,
  % is the only way to be sure a record written here reads back unchanged.
  %
  % The codes are the ones the format has carried since the arrhythmia
  % database was published: 1 normal, 5 premature ventricular, 28 rhythm
  % change, and so on. The gaps (15, 17, 42 and up) are codes the format
  % reserves and no open database uses; a code outside the table reads back as
  % '?', the learning mark, which is honest about not knowing rather than
  % inventing a beat.
  persistent symbols;
  if isempty(symbols)
    % Index i + 1 holds the symbol for code i, so code 0 (not a real
    % annotation) and every unmapped code fall through to '?'.
    symbols = repmat('?', 1, 50);
    symbols(1 + 1) = 'N';   % normal beat
    symbols(1 + 2) = 'L';   % left bundle branch block
    symbols(1 + 3) = 'R';   % right bundle branch block
    symbols(1 + 4) = 'a';   % aberrated atrial premature beat
    symbols(1 + 5) = 'V';   % premature ventricular contraction
    symbols(1 + 6) = 'F';   % fusion of ventricular and normal
    symbols(1 + 7) = 'J';   % nodal (junctional) premature beat
    symbols(1 + 8) = 'A';   % atrial premature beat
    symbols(1 + 9) = 'S';   % supraventricular premature beat
    symbols(1 + 10) = 'E';  % ventricular escape beat
    symbols(1 + 11) = 'j';  % nodal (junctional) escape beat
    symbols(1 + 12) = '/';  % paced beat
    symbols(1 + 13) = 'Q';  % unclassifiable beat
    symbols(1 + 14) = '~';  % signal quality change
    symbols(1 + 16) = '|';  % isolated QRS-like artifact
    symbols(1 + 18) = 's';  % ST change
    symbols(1 + 19) = 'T';  % T-wave change
    symbols(1 + 20) = '*';  % systole
    symbols(1 + 21) = 'D';  % diastole
    symbols(1 + 22) = '"';  % comment annotation
    symbols(1 + 23) = '=';  % measurement annotation
    symbols(1 + 24) = 'p';  % P-wave peak
    symbols(1 + 25) = 'B';  % bundle branch block, side unspecified
    symbols(1 + 26) = '^';  % non-conducted pacer spike
    symbols(1 + 27) = 't';  % T-wave peak
    symbols(1 + 28) = '+';  % rhythm change
    symbols(1 + 29) = 'u';  % U-wave peak
    symbols(1 + 30) = '?';  % learning
    symbols(1 + 31) = '!';  % ventricular flutter wave
    symbols(1 + 32) = '[';  % start of ventricular flutter or fibrillation
    symbols(1 + 33) = ']';  % end of ventricular flutter or fibrillation
    symbols(1 + 34) = 'e';  % atrial escape beat
    symbols(1 + 35) = 'n';  % supraventricular escape beat
    symbols(1 + 36) = '@';  % link to external data in the aux field
    symbols(1 + 37) = 'x';  % non-conducted P-wave (blocked APB)
    symbols(1 + 38) = 'f';  % fusion of paced and normal beat
    symbols(1 + 39) = '(';  % waveform onset
    symbols(1 + 40) = ')';  % waveform end
    symbols(1 + 41) = 'r';  % R-on-T premature ventricular contraction
  end
  if isnumeric(in)
    code = round(in);
    if code < 1 || code > 49
      out = '?';
      return;
    end
    out = symbols(code + 1);
    return;
  end
  % A symbol back to its code. Every letter the forward table assigns is
  % unique, so the first match is the one code that means it; '?' is the one
  % symbol that labels several reserved slots, so it is pinned to 30
  % (learning), the code whose mnemonic is '?', and any symbol not in the
  % table is treated the same way rather than invented into a beat.
  symbol = char(in);
  if symbol(1) == '?'
    out = 30;
    return;
  end
  code = find(symbols == symbol(1), 1) - 1;
  if isempty(code)
    code = 30;
  end
  out = code;
end
%=============================================================================
