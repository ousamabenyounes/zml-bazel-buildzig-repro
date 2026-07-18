# ZML Bazel artifact from `build.zig`

Minimal repro for consuming a Bazel-built ZML artifact from an external Zig
project that uses `build.zig`.

This is not native `build.zig.zon` package integration. It demonstrates an
explicit C ABI boundary:

1. install a tiny Bazel package into a local ZML checkout;
2. let this external `build.zig` invoke Bazel;
3. discover the produced shared library with `bazel cquery --output=files`;
4. stage the shared library and header into `.zig-cache`;
5. link and run/test a Zig consumer against the staged artifact;
6. build, stage, and run a Bazel-produced executable boundary as a second path.

## Prerequisites

- A local ZML checkout.
- The same Zig toolchain used by that checkout, or a compatible Zig on `PATH`.
- Bazel or Bazelisk.

The versions used for the published validation are recorded in `repro.lock`.

## Usage

From this repository:

```sh
scripts/prepare-zml.sh .work/zml
zig build install-facade -Dzml-root=/path/to/zml
zig build run -Dzml-root=/path/to/zml -Dbazel=/path/to/bazel
zig build test -Dzml-root=/path/to/zml -Dbazel=/path/to/bazel --summary all
zig build test-discovery-failure
zig build run-bazel-exe -Dzml-root=/path/to/zml -Dbazel=/path/to/bazel
```

The `install-facade` step copies `facade/repro/cabi` into
`$ZML_ROOT/repro/cabi`. Use a disposable or topic-branch ZML checkout.
The `prepare-zml.sh` helper can create that disposable checkout for you at the
commit recorded in `repro.lock`.

Expected output:

```text
ZML C ABI consumer OK: KiB=1024, MiB=1048576, logo_blocks=3, f32_size=4, shape_bytes=120
Build Summary: 4/4 steps succeeded; 1/1 tests passed
strict cquery discovery rejects missing and duplicate artifacts
ZML Bazel executable OK: KiB=1024, MiB=1048576, logo_blocks=3, f32_size=4, shape_bytes=120
```

## What this proves

- `build.zig` can invoke Bazel.
- `build.zig` can use Bazel query output to locate a produced artifact.
- A Zig consumer can link a staged Bazel-built C ABI facade.
- The linked facade can call lightweight ZML APIs: constants, logo helpers,
  `DataType`, and `Shape`.
- The staged directories include small manifests describing the discovered
  artifacts and the runtime files this repro can observe.
- The artifact discovery logic rejects missing or duplicate `.so` candidates.
- A separate Bazel-built executable can also be staged and run from `build.zig`,
  which demonstrates the executable boundary documented in the ZML PR.
- The executable staging also preserves Bazel runfiles/runfiles manifest when
  Bazel produces them.

## What this does not prove

- It does not provide native `build.zig.zon` integration.
- It only stages runtime files that Bazel exposes next to this executable
  target. It is not a general runtime dependency manifest generator.
- It does not exercise a real model execution path or PJRT runtime loading.
- It is a repro for an explicit artifact/C ABI boundary, not a maintained ZML
  packaging format.
