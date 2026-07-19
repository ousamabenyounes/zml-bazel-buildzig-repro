const std = @import("std");

const DEFAULT_ZML_ROOT = "../zml";
const DEFAULT_BAZEL = "bazel";
const DEFAULT_ZML_STAGE_DIR = ".zig-cache/zml-repro";
const ZML_REPRO_TARGET = "//repro/cabi:zml_repro_cabi";
const ZML_REPRO_CLI_TARGET = "//repro/cabi:zml_repro_cli";
const ZML_REPRO_INCLUDE_REL = "repro/cabi";
const ZML_REPRO_LIBRARY = "zml_repro_cabi";
const ZML_REPRO_SHARED_LIBRARY = "libzml_repro_cabi.so";
const ZML_REPRO_CLI_BINARY = "zml_repro_cli";
const ZML_REPRO_HEADER = "zml_repro_cabi.h";
const ZML_REPRO_MANIFEST = "zml_repro_manifest.json";
const ZML_REPRO_CLI_MANIFEST = "zml_repro_cli_manifest.json";
const CONSUMER_EXE_NAME = "zml-cabi-consumer";
const CONSUMER_ROOT = "src/main.zig";
const CONSUMER_CHECKS = "src/checks.zig";
const FACADE_SOURCE_DIR = "facade/repro/cabi";
const FACADE_DEST_REL = "repro/cabi";

const INSTALL_FACADE_SCRIPT =
    \\set -eu
    \\source_dir="$1"
    \\zml_root="$2"
    \\dest_dir="$zml_root/repro/cabi"
    \\mkdir -p "$dest_dir"
    \\cp "$source_dir/BUILD.bazel" "$dest_dir/BUILD.bazel"
    \\cp "$source_dir/zml_repro_cabi.zig" "$dest_dir/zml_repro_cabi.zig"
    \\cp "$source_dir/zml_repro_cabi.h" "$dest_dir/zml_repro_cabi.h"
    \\cp "$source_dir/zml_repro_cli.zig" "$dest_dir/zml_repro_cli.zig"
    \\test -s "$dest_dir/BUILD.bazel"
    \\test -s "$dest_dir/zml_repro_cabi.zig"
    \\test -s "$dest_dir/zml_repro_cabi.h"
    \\test -s "$dest_dir/zml_repro_cli.zig"
;

const STAGE_BAZEL_ARTIFACT_SCRIPT =
    \\set -eu
    \\bazel="$1"
    \\target="$2"
    \\stage_dir="$3"
    \\zml_root="$4"
    \\library_name="$5"
    \\header_rel="$6"
    \\manifest_name="$7"
    \\case "$stage_dir" in
    \\  /*) ;;
    \\  *) stage_dir="$PWD/$stage_dir" ;;
    \\esac
    \\tmp_dir="$stage_dir.tmp.$$"
    \\rm -rf "$tmp_dir"
    \\trap 'rm -rf "$tmp_dir"' EXIT
    \\mkdir -p "$tmp_dir/lib" "$tmp_dir/include"
    \\cd "$zml_root"
    \\test -s "$header_rel" || { echo "missing facade; run: zig build install-facade -Dzml-root=$zml_root" >&2; exit 2; }
    \\"$bazel" build "$target"
    \\candidate_outputs=$("$bazel" cquery --output=files "$target")
    \\printf '%s\n' "$candidate_outputs" > "$tmp_dir/candidate_outputs.txt"
    \\matches=$(printf '%s\n' "$candidate_outputs" | awk -v name="$library_name" 'BEGIN { count=0 } $0 ~ "/" name "$" { print; count++ } END { if (count != 1) exit 42 }')
    \\artifact="$matches"
    \\bazel_bin=$("$bazel" info bazel-bin)
    \\execution_root=$("$bazel" info execution_root)
    \\needed_libraries_file=needed_libraries.txt
    \\cp "$artifact" "$tmp_dir/lib/$library_name"
    \\cp "$header_rel" "$tmp_dir/include/"
    \\command -v readelf >/dev/null 2>&1 || { echo "missing readelf; install binutils to inspect ELF dependencies" >&2; exit 2; }
    \\readelf -d "$artifact" | sed -n 's/.*Shared library: \[\(.*\)\].*/\1/p' | sort -u > "$tmp_dir/$needed_libraries_file"
    \\needed_libraries_json=$(awk 'BEGIN { printf "[" } { printf "%s\"%s\"", sep, $0; sep=", " } END { print "]" }' "$tmp_dir/$needed_libraries_file")
    \\runtime_dependencies_json="[\"$needed_libraries_file\"]"
    \\zml_commit=$(git rev-parse HEAD 2>/dev/null || printf unknown)
    \\cat > "$tmp_dir/$manifest_name" <<EOF
    \\{
    \\  "bazel_target": "$target",
    \\  "library": "lib/$library_name",
    \\  "header": "include/$(basename "$header_rel")",
    \\  "needed_libraries_file": "$needed_libraries_file",
    \\  "needed_libraries": $needed_libraries_json,
    \\  "source_artifact": "$artifact",
    \\  "candidate_outputs_file": "candidate_outputs.txt",
    \\  "bazel_bin": "$bazel_bin",
    \\  "execution_root": "$execution_root",
    \\  "zml_root": "$zml_root",
    \\  "zml_commit": "$zml_commit",
    \\  "runtime_dependencies": $runtime_dependencies_json
    \\}
    \\EOF
    \\test -s "$tmp_dir/lib/$library_name"
    \\test -s "$tmp_dir/include/$(basename "$header_rel")"
    \\test -s "$tmp_dir/$needed_libraries_file"
    \\test -s "$tmp_dir/$manifest_name"
    \\test -s "$tmp_dir/candidate_outputs.txt"
    \\grep -q "zml_repro_shape_f32_bytes" "$tmp_dir/include/$(basename "$header_rel")"
    \\grep -q "\"needed_libraries_file\"" "$tmp_dir/$manifest_name"
    \\grep -q "\"needed_libraries\": \[" "$tmp_dir/$manifest_name"
    \\grep -q "\"candidate_outputs_file\"" "$tmp_dir/$manifest_name"
    \\grep -q "\"runtime_dependencies\"" "$tmp_dir/$manifest_name"
    \\grep -q "\"runtime_dependencies\": \\[" "$tmp_dir/$manifest_name"
    \\! grep -q "\"runtime_dependencies\": \\[\\]" "$tmp_dir/$manifest_name"
    \\rm -rf "$stage_dir"
    \\mv "$tmp_dir" "$stage_dir"
    \\trap - EXIT
;

const TEST_DISCOVERY_FAILURE_SCRIPT =
    \\set -eu
    \\library_name="$1"
    \\duplicate=$(printf '%s\n%s\n' "bazel-bin/a/$library_name" "bazel-bin/b/$library_name")
    \\missing=$(printf '%s\n' "bazel-bin/a/libother.so")
    \\if printf '%s\n' "$duplicate" | awk -v name="$library_name" 'BEGIN { count=0 } $0 ~ "/" name "$" { print; count++ } END { if (count != 1) exit 42 }' >/dev/null; then
    \\  echo "duplicate discovery unexpectedly succeeded" >&2
    \\  exit 1
    \\fi
    \\if printf '%s\n' "$missing" | awk -v name="$library_name" 'BEGIN { count=0 } $0 ~ "/" name "$" { print; count++ } END { if (count != 1) exit 42 }' >/dev/null; then
    \\  echo "missing discovery unexpectedly succeeded" >&2
    \\  exit 1
    \\fi
    \\echo "strict cquery discovery rejects missing and duplicate artifacts"
;

const STAGE_BAZEL_EXECUTABLE_SCRIPT =
    \\set -eu
    \\bazel="$1"
    \\target="$2"
    \\stage_dir="$3"
    \\zml_root="$4"
    \\binary_name="$5"
    \\manifest_name="$6"
    \\case "$stage_dir" in
    \\  /*) ;;
    \\  *) stage_dir="$PWD/$stage_dir" ;;
    \\esac
    \\tmp_dir="$stage_dir.tmp.$$"
    \\rm -rf "$tmp_dir"
    \\trap 'rm -rf "$tmp_dir"' EXIT
    \\mkdir -p "$tmp_dir/bin"
    \\cd "$zml_root"
    \\"$bazel" build "$target"
    \\candidate_outputs=$("$bazel" cquery --output=files "$target")
    \\printf '%s\n' "$candidate_outputs" > "$tmp_dir/candidate_outputs.txt"
    \\matches=$(printf '%s\n' "$candidate_outputs" | awk -v name="$binary_name" 'BEGIN { count=0 } $0 ~ "/" name "$" { print; count++ } END { if (count != 1) exit 42 }')
    \\artifact="$matches"
    \\bazel_bin=$("$bazel" info bazel-bin)
    \\execution_root=$("$bazel" info execution_root)
    \\cp "$artifact" "$tmp_dir/bin/$binary_name"
    \\chmod +x "$tmp_dir/bin/$binary_name"
    \\runfiles_json=null
    \\runfiles_manifest_json=null
    \\runtime_dependencies_json="[]"
    \\if [ -d "$artifact.runfiles" ]; then
    \\  cp -R "$artifact.runfiles" "$tmp_dir/runfiles"
    \\  runfiles_json="\"runfiles\""
    \\  runtime_dependencies_json="[\"runfiles\"]"
    \\fi
    \\if [ -s "$artifact.runfiles_manifest" ]; then
    \\  cp "$artifact.runfiles_manifest" "$tmp_dir/runfiles_manifest"
    \\  runfiles_manifest_json="\"runfiles_manifest\""
    \\  if [ "$runtime_dependencies_json" = "[]" ]; then
    \\    runtime_dependencies_json="[\"runfiles_manifest\"]"
    \\  else
    \\    runtime_dependencies_json="[\"runfiles\", \"runfiles_manifest\"]"
    \\  fi
    \\fi
    \\zml_commit=$(git rev-parse HEAD 2>/dev/null || printf unknown)
    \\cat > "$tmp_dir/$manifest_name" <<EOF
    \\{
    \\  "bazel_target": "$target",
    \\  "executable": "bin/$binary_name",
    \\  "source_artifact": "$artifact",
    \\  "candidate_outputs_file": "candidate_outputs.txt",
    \\  "bazel_bin": "$bazel_bin",
    \\  "execution_root": "$execution_root",
    \\  "runfiles": $runfiles_json,
    \\  "runfiles_manifest": $runfiles_manifest_json,
    \\  "zml_root": "$zml_root",
    \\  "zml_commit": "$zml_commit",
    \\  "runtime_dependencies": $runtime_dependencies_json
    \\}
    \\EOF
    \\test -x "$tmp_dir/bin/$binary_name"
    \\test -s "$tmp_dir/$manifest_name"
    \\test -s "$tmp_dir/candidate_outputs.txt"
    \\grep -q "\"executable\"" "$tmp_dir/$manifest_name"
    \\grep -q "\"runtime_dependencies\"" "$tmp_dir/$manifest_name"
    \\rm -rf "$stage_dir"
    \\mv "$tmp_dir" "$stage_dir"
    \\trap - EXIT
;

const RUN_STAGED_EXECUTABLE_SCRIPT =
    \\set -eu
    \\stage_dir="$1"
    \\binary_name="$2"
    \\case "$stage_dir" in
    \\  /*) ;;
    \\  *) stage_dir="$PWD/$stage_dir" ;;
    \\esac
    \\if [ -d "$stage_dir/runfiles" ]; then
    \\  export RUNFILES_DIR="$stage_dir/runfiles"
    \\fi
    \\if [ -s "$stage_dir/runfiles_manifest" ]; then
    \\  export RUNFILES_MANIFEST_FILE="$stage_dir/runfiles_manifest"
    \\fi
    \\"$stage_dir/bin/$binary_name"
;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const zml_root = b.option([]const u8, "zml-root", "Path to the ZML checkout") orelse DEFAULT_ZML_ROOT;
    const bazel = b.option([]const u8, "bazel", "Path to bazel or bazelisk") orelse DEFAULT_BAZEL;
    const zml_stage_dir = b.option([]const u8, "zml-stage-dir", "Directory where Bazel artifacts are staged") orelse DEFAULT_ZML_STAGE_DIR;
    const zml_exe_stage_dir = b.option([]const u8, "zml-exe-stage-dir", "Directory where Bazel executable artifacts are staged") orelse ".zig-cache/zml-repro-exe";
    const zml_header_rel = b.pathJoin(&.{ ZML_REPRO_INCLUDE_REL, ZML_REPRO_HEADER });

    const install_facade = b.addSystemCommand(&.{
        "sh",
        "-c",
        INSTALL_FACADE_SCRIPT,
        "install-zml-facade",
        b.pathJoin(&.{ b.build_root.path.?, FACADE_SOURCE_DIR }),
        zml_root,
    });

    const install_step = b.step("install-facade", "Copy the Bazel C ABI facade into the ZML checkout");
    install_step.dependOn(&install_facade.step);

    const stage_zml_artifact = b.addSystemCommand(&.{
        "sh",
        "-c",
        STAGE_BAZEL_ARTIFACT_SCRIPT,
        "stage-zml-artifact",
        bazel,
        ZML_REPRO_TARGET,
        zml_stage_dir,
        zml_root,
        ZML_REPRO_SHARED_LIBRARY,
        zml_header_rel,
        ZML_REPRO_MANIFEST,
    });

    const zml_include_dir = b.pathJoin(&.{ zml_stage_dir, "include" });
    const zml_library_dir = b.pathJoin(&.{ zml_stage_dir, "lib" });

    const root_module = createConsumerModule(b, target, optimize, zml_include_dir, zml_library_dir, CONSUMER_ROOT);
    const exe = b.addExecutable(.{
        .name = CONSUMER_EXE_NAME,
        .root_module = root_module,
    });
    exe.step.dependOn(&stage_zml_artifact.step);

    b.installArtifact(exe);

    const run = b.addRunArtifact(exe);
    run.setEnvironmentVariable("LD_LIBRARY_PATH", zml_library_dir);

    const run_step = b.step("run", "Build ZML with Bazel, then run the Zig consumer");
    run_step.dependOn(&run.step);

    const test_module = createConsumerModule(b, target, optimize, zml_include_dir, zml_library_dir, CONSUMER_CHECKS);
    const tests = b.addTest(.{
        .root_module = test_module,
    });
    tests.step.dependOn(&stage_zml_artifact.step);

    const run_tests = b.addRunArtifact(tests);
    run_tests.setEnvironmentVariable("LD_LIBRARY_PATH", zml_library_dir);

    const test_step = b.step("test", "Build ZML with Bazel, then test the Zig consumer");
    test_step.dependOn(&run_tests.step);

    const test_discovery_failure = b.addSystemCommand(&.{
        "sh",
        "-c",
        TEST_DISCOVERY_FAILURE_SCRIPT,
        "test-discovery-failure",
        ZML_REPRO_SHARED_LIBRARY,
    });

    const test_discovery_failure_step = b.step("test-discovery-failure", "Verify strict artifact discovery rejects bad cquery output");
    test_discovery_failure_step.dependOn(&test_discovery_failure.step);

    const stage_zml_executable = b.addSystemCommand(&.{
        "sh",
        "-c",
        STAGE_BAZEL_EXECUTABLE_SCRIPT,
        "stage-zml-executable",
        bazel,
        ZML_REPRO_CLI_TARGET,
        zml_exe_stage_dir,
        zml_root,
        ZML_REPRO_CLI_BINARY,
        ZML_REPRO_CLI_MANIFEST,
    });

    const run_staged_executable = b.addSystemCommand(&.{
        "sh",
        "-c",
        RUN_STAGED_EXECUTABLE_SCRIPT,
        "run-staged-zml-executable",
        zml_exe_stage_dir,
        ZML_REPRO_CLI_BINARY,
    });
    run_staged_executable.step.dependOn(&stage_zml_executable.step);

    const run_bazel_exe_step = b.step("run-bazel-exe", "Build a ZML executable with Bazel, stage it, then run it from build.zig");
    run_bazel_exe_step.dependOn(&run_staged_executable.step);
}

fn createConsumerModule(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    zml_include_dir: []const u8,
    zml_library_dir: []const u8,
    root_source_file: []const u8,
) *std.Build.Module {
    const root_module = b.createModule(.{
        .root_source_file = b.path(root_source_file),
        .target = target,
        .optimize = optimize,
    });
    root_module.addIncludePath(.{ .cwd_relative = zml_include_dir });
    root_module.addLibraryPath(.{ .cwd_relative = zml_library_dir });
    root_module.linkSystemLibrary(ZML_REPRO_LIBRARY, .{});
    root_module.link_libc = true;
    return root_module;
}
