# Validation evidence

[validation-1.2.0.json](validation-1.2.0.json) records FSR GPU/settings/resize
checks and matched forest flight frame times, including the rejected terrain-starving
upload budget. Portable checks are in [loader-1.2.0.txt](loader-1.2.0.txt) and
[tests-1.2.0.txt](tests-1.2.0.txt).

[validation-1.1.1.json](validation-1.1.1.json) records the GitHub native-mod
installation correction, actual trait API compilation, archive/payload checks
and private installer tests. Portable checks are in
[loader-1.1.1.txt](loader-1.1.1.txt) and [tests-1.1.1.txt](tests-1.1.1.txt).

[validation-1.1.0.json](validation-1.1.0.json) records the native shader conversion,
real shader/registry checks and isolated GPU tests. Its portable output is in
[loader-1.1.0.txt](loader-1.1.0.txt) and [tests-1.1.0.txt](tests-1.1.0.txt).

[validation-1.0.1.json](validation-1.0.1.json) records the earlier GLSL fix's official client,
loader checks, camera regression coverage and summarized runtime results.
[loader-1.0.1.txt](loader-1.0.1.txt) and [tests-1.0.1.txt](tests-1.0.1.txt) contain
the portable check output. [documentation.json](documentation.json) is generated
by `python3 tools/check_docs.py`.

Runtime tests use isolated, newly generated worlds. Versions through 1.1.1 used
a visual frame cap and made no performance measurements. Version 1.2.0 includes
explicit uncapped flight benchmarks on the documented Intel machine. No BC250
benchmark or sustained 60 FPS claim is made.

Raw captures, player state, machine paths, installation backups and historical
Radiance evidence stay in ignored local storage. Do not publish those files here.
For a new release, add a sanitized summary only after running the stated checks.
