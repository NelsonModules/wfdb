# wfdb

A PhysioNet WFDB toolbox for [Nelson](https://nelson-lang.github.io/nelson-website/).

WFDB is the record format the PhysioNet databases are published in: a text
header (`.hea`) that describes the signals, a binary signal file (`.dat`) that
packs their samples, and optional MIT annotation files (`.atr` and the like)
that mark the beats and events.

## Load

```matlab
run('/path/to/wfdb/loader.m')
```

## Functions

All functions live in the `wfdb` package (call them as `wfdb.read`, `wfdb.write`, ...).

| Function | Purpose |
|---|---|
| `wfdb.read(name, ...)` | Read a record (header, signals, annotations) into the neutral struct. Options: `'Physical'`, `'Signals'`, `'Annotations'`, `'Data'`. |
| `wfdb.write(name, r, ...)` / `wfdb.write(name, samples, rate, ...)` | Write the neutral struct, or a plain matrix. Options: `'Format'`, `'Physical'`, `'Gain'`, `'Baseline'`, `'Leads'`, `'Units'`, `'Annotations'`, `'Segments'`. |
| `wfdb.header(name)` | Read only the header, no samples and no annotations, fast. |
| `wfdb.info(name)` | A compact human-readable summary (header only). |
| `wfdb.iswfdb(name)` | Probe a record; true when its header parses, never throws. |
| `wfdb.annotations(file, ...)` | Read a MIT annotation file, or write one back. |
| `wfdb.validate(name)` | Check a record: header, signal-file length and the stored checksums. |
| `wfdb.matrix(r)` | Turn the per-signal struct into one aligned matrix, a column per signal. |
| `wfdb.select(r, which)` | Keep a subset of signals, by label or index, in the order asked. |
| `wfdb.crop(r, [t0 t1], ...)` | Keep a time (or `'Frames'`) window; the annotations in it come along. |

`wfdb.read` options: `'Physical', true` returns physical units
(`(raw - baseline) / gain`) instead of the raw ADC integers the file holds (raw
is the default, so a read followed by `wfdb.write` is lossless, with the gain,
baseline and unit of every signal on the struct); `'Signals', which` keeps a
subset by label or index; `'Annotations'` chooses the annotation file (`'auto'`
reads `name.atr` when present and skips it when absent, an extension such as
`'qrs'` reads `name.qrs`, a path reads that file, `false` reads none); and
`'Data', false` reads the header only.

Signal formats read: 8, 16, 24, 32, 61, 80, 160, 212, 310 and 311. Every one of
these except the first-difference format 8 is also written. MIT annotations
round-trip in full: `sample`, `time`, `code`, `symbol`, `num`, `subtype`,
`chan` and `aux`.

## The neutral struct

`wfdb.read` returns one struct with no domain assumptions:

```
r.kind            % 'wfdb.record'
r.name, r.path
r.rate            % the base sampling frequency (Hz)
r.counterFrequency, r.baseCounter, r.declaredFrames
r.startTime, r.startTimeKnown, r.startDate, r.comments
r.multiSegment, r.multiFrequency, r.segments
r.signals(k)      % .file .format .spf .offset .skew .gain .baseline .unit
                  % .adcres .adczero .initial .checksum .blocksize
                  % .description .label .rate .data
r.annotations     % .sample .time .code .symbol .num .subtype .chan .aux
```

`wfdb.write` accepts the same shape, or a plain matrix (one column per signal)
with a rate; the gains, baselines, labels and units are used when present and
defaulted when not. With `'Segments', lengths` it writes a fixed-layout
multi-segment record (the signals cut into consecutive pieces, each an ordinary
record, named by a master header); `lengths` is a vector of per-segment frame
counts or a scalar chunk size, and `wfdb.read` stitches the pieces back into the
one record that went in.

## Example

A ready-to-run tour is in [`examples/read_write_demo.m`](examples/read_write_demo.m).

```matlab
% Round-trip a two-lead record and read it back in physical units.
rate = 250;
t = (0:5 * rate - 1)' / rate;
wfdb.write('demo', [sin(2*pi*1.3*t), 0.5*cos(2*pi*1.3*t)], rate, ...
  'Leads', {'I', 'II'}, 'Units', {'mV', 'mV'});
r = wfdb.read('demo', 'Physical', true);
m = wfdb.matrix(r);
```

## Dependencies

This module depends on no other Nelson module.

## License

LGPL-3.0-or-later.
