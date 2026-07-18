# ZML Bazel artifact from `build.zig`

Minimal repro for consuming a Bazel-built ZML artifact from an external Zig
project that uses `build.zig`.

This is not native `build.zig.zon` package integration. It demonstrates an
explicit C ABI boundary:

1. install a tiny Bazel package into a local ZML checkout;
2. let this external `build.zig` invoke Bazel;
3. discover the produced shared library with `bazel cquery --output=files`;
4. stage the shared library and header into `.zig-cache`;
5. link and run/test a Zig consumer against the staged artifact.

## Prerequisites

- A local ZML checkout.
- The same Zig toolchain used by that checkout, or a compatible Zig on `PATH`.
- Bazel or Bazelisk.

## Usage

From this repository:

```sh
zig build install-facade -Dzml-root=/path/to/zml
zig build run -Dzml-root=/path/to/zml -Dbazel=/path/to/bazel
zig build test -Dzml-root=/path/to/zml -Dbazel=/path/to/bazel --summary all
```

The `install-facade` step copies `facade/repro/cabi` into
`$ZML_ROOT/repro/cabi`. Use a disposable or topic-branch ZML checkout.

Expected output:

```text
ZML C ABI consumer OK: KiB=1024, MiB=1048576, logo_blocks=3, f32_size=4, shape_bytes=120
Build Summary: 4/4 steps succeeded; 1/1 tests passed
```

## What this proves

- `build.zig` can invoke Bazel.
- `build.zig` can use Bazel query output to locate a produced artifact.
- A Zig consumer can link a staged Bazel-built C ABI facade.
- The linked facade can call lightweight ZML APIs: constants, logo helpers,
  `DataType`, and `Shape`.

## What this does not prove

- It does not provide native `build.zig.zon` integration.
- It does not discover or package all transitive runtime dependencies.
- It does not exercise a real model execution path or PJRT runtime loading.
- It is a repro for an explicit artifact/C ABI boundary, not a maintained ZML
  packaging format.
