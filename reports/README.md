# Validation evidence

[validation-1.0.1.json](validation-1.0.1.json) records the tested official client,
loader checks, camera regression coverage and summarized runtime results.
[loader-1.0.1.txt](loader-1.0.1.txt) and [tests-1.0.1.txt](tests-1.0.1.txt) contain
the portable check output. [documentation.json](documentation.json) is generated
by `python3 tools/check_docs.py`.

Runtime tests used an isolated, newly generated world. The frame cap was for
visual correctness, not benchmarking. There is no 60 FPS or BC250 performance
claim in this release.

Raw captures, player state, machine paths, installation backups and historical
Radiance evidence stay in ignored local storage. Do not publish those files here.
For a new release, add a sanitized summary only after running the stated checks.
