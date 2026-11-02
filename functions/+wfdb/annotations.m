%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the wfdb module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function a = annotations(varargin)
  % A = wfdb.annotations(FILE) reads a MIT-format annotation file (NAME.atr and
  % the like) into the module's annotation struct: column vectors of sample,
  % time, code, symbol, num, subtype, chan and aux. The sample index is what the
  % file stores; the time in seconds needs the sampling rate, which is taken
  % from the record's header when a sibling NAME.hea is on disk, or from the
  % 'Rate' option, or is left at one sample per second.
  %
  % A = wfdb.annotations(FILE, 'Rate', R) reads with the rate R hertz.
  %
  % wfdb.annotations(FILE, A) writes the annotation struct A to FILE, so that
  % wfdb.annotations(FILE) reads it back unchanged.
  %
  % See also wfdb.read, wfdb.write.
  narginchk(1, inf);
  nargoutchk(0, 1);
  file = varargin{1};
  if ~ischar(file) && ~isStringScalar(file)
    error('wfdb:badFileName', 'The file name must be text.');
  end
  file = char(file);
  if nargin >= 2 && isstruct(varargin{2})
    wfdbWriteAnnotations(file, varargin{2});
    return;
  end
  rate = wfdbAnnotationRate(file, varargin(2:end));
  a = wfdbReadAnnotations(file, rate);
end
%=============================================================================
function rate = wfdbAnnotationRate(file, args)
  rate = [];
  if mod(numel(args), 2) ~= 0
    error('wfdb:badOptions', 'Options come in name-value pairs.');
  end
  for k = 1:2:numel(args)
    name = args{k};
    if ~ischar(name) && ~isStringScalar(name)
      error('wfdb:badOptionName', 'An option name must be text.');
    end
    if strcmpi(char(name), 'rate')
      rate = args{k + 1};
    else
      error('wfdb:unknownOption', 'Unknown option %s.', char(name));
    end
  end
  if ~isempty(rate)
    if ~isscalar(rate) || ~(rate > 0)
      error('wfdb:badRate', 'The rate must be one positive number of hertz.');
    end
    return;
  end
  % No rate was given: find the record's rate from a sibling header, so the
  % annotation times are seconds rather than samples; fall back to one hertz
  % when no header is beside the file.
  [folder, stem] = fileparts(file);
  candidate = fullfile(folder, [stem, '.hea']);
  if isfile(candidate)
    described = wfdbReadHeader(candidate);
    rate = described.rate;
  else
    rate = 1;
  end
end
%=============================================================================
