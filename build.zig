const std = @import("std");

const DEFAULT_ZML_ROOT = "../zml";
const DEFAULT_BAZEL = "bazel";
const DEFAULT_ZML_STAGE_DIR = ".zig-cache/zml-repro";
const ZML_REPRO_TARGET = "//repro/cabi:zml_repro_cabi";
const ZML_REPRO_INCLUDE_REL = "repro/cabi";
const ZML_REPRO_LIBRARY = "zml_repro_cabi";
const ZML_REPRO_SHARED_LIBRARY = "libzml_repro_cabi.so";
const ZML_REPRO_HEADER = "zml_repro_cabi.h";
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
    \\test -s "$dest_dir/BUILD.bazel"
    \\test -s "$dest_dir/zml_repro_cabi.zig"
    \\test -s "$dest_dir/zml_repro_cabi.h"
;

const STAGE_BAZEL_ARTIFACT_SCRIPT =
    \\set -eu
    \\bazel="$1"
    \\target="$2"
    \\stage_dir="$3"
    \\zml_root="$4"
    \\library_name="$5"
    \\header_rel="$6"
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
    \\matches=$("$bazel" cquery --output=files "$target" | awk -v name="$library_name" 'BEGIN { count=0 } $0 ~ "/" name "$" { print; count++ } END { if (count != 1) exit 42 }')
    \\artifact="$matches"
    \\cp "$artifact" "$tmp_dir/lib/$library_name"
    \\cp "$header_rel" "$tmp_dir/include/"
    \\test -s "$tmp_dir/lib/$library_name"
    \\test -s "$tmp_dir/include/$(basename "$header_rel")"
    \\grep -q "zml_repro_shape_f32_bytes" "$tmp_dir/include/$(basename "$header_rel")"
    \\rm -rf "$stage_dir"
    \\mv "$tmp_dir" "$stage_dir"
    \\trap - EXIT
;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const zml_root = b.option([]const u8, "zml-root", "Path to the ZML checkout") orelse DEFAULT_ZML_ROOT;
    const bazel = b.option([]const u8, "bazel", "Path to bazel or bazelisk") orelse DEFAULT_BAZEL;
    const zml_stage_dir = b.option([]const u8, "zml-stage-dir", "Directory where Bazel artifacts are staged") orelse DEFAULT_ZML_STAGE_DIR;
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
