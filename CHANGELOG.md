# Changelog

All notable changes to the `wfdb` module are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-10-02

### Added

- Initial release: read and write PhysioNet WFDB records.
- `wfdb.read` reads the header, the signal files and (when present) the MIT
  annotations into one domain-free struct, in raw ADC integers or physical
  units.
- `wfdb.write` writes a struct from `wfdb.read` or a plain matrix, with the
  signal format, gains, baselines, labels and units chosen or defaulted; its
  `'Segments'` option writes a fixed-layout multi-segment record (a master
  header plus one ordinary record per piece) that `wfdb.read` stitches back.
- Signal formats read: 8, 16, 24, 32, 61, 80, 160, 212, 310 and 311; all of
  these except the first-difference format 8 are also written.
- MIT annotation files round-trip in full (`sample`, `time`, `code`, `symbol`,
  `num`, `subtype`, `chan`, `aux`), read and written by `wfdb.annotations`.
- `wfdb.header` and `wfdb.info` inspect a record without lifting its samples;
  `wfdb.iswfdb` probes a file without throwing.
- `wfdb.validate` checks the header, the signal-file length and the stored
  checksums.
- `wfdb.matrix` builds one aligned matrix across rates; `wfdb.select` keeps a
  subset of signals; `wfdb.crop` keeps a time or frame window with its
  annotations.
- Multi-segment and multi-frequency records are read, and fixed-layout
  multi-segment records are written.
