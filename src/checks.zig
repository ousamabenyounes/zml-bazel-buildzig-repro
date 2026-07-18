const std = @import("std");

const c = @cImport({
    @cInclude("zml_repro_cabi.h");
});

const EXPECTED_KIB: usize = 1024;
const EXPECTED_MIB: usize = EXPECTED_KIB * EXPECTED_KIB;
const EXPECTED_F32_SIZE: u16 = 4;
const EXPECTED_SHAPE_DIM_0: i64 = 2;
const EXPECTED_SHAPE_DIM_1: i64 = 3;
const EXPECTED_SHAPE_DIM_2: i64 = 5;
const EXPECTED_SHAPE_BYTES: usize = @as(usize, @intCast(EXPECTED_SHAPE_DIM_0 * EXPECTED_SHAPE_DIM_1 * EXPECTED_SHAPE_DIM_2)) * EXPECTED_F32_SIZE;

pub fn validateZmlFacade() !void {
    try std.testing.expectEqual(EXPECTED_KIB, c.zml_repro_kib());
    try std.testing.expectEqual(EXPECTED_MIB, c.zml_repro_mib());
    try std.testing.expect(c.zml_repro_logo_block_count() > 0);
    try std.testing.expect(c.zml_repro_logo_shine_ascii_a());
    try std.testing.expect(!c.zml_repro_logo_plain_ascii_z());
    try std.testing.expectEqual(EXPECTED_F32_SIZE, c.zml_repro_dtype_f32_size());
    try std.testing.expectEqual(c.zml_repro_dtype_f32_tag(), c.zml_repro_dtype_peer_f16_f32());
    try std.testing.expectEqual(
        EXPECTED_SHAPE_BYTES,
        c.zml_repro_shape_f32_bytes(EXPECTED_SHAPE_DIM_0, EXPECTED_SHAPE_DIM_1, EXPECTED_SHAPE_DIM_2),
    );
}

pub fn printSummary() void {
    std.debug.print(
        "ZML C ABI consumer OK: KiB={d}, MiB={d}, logo_blocks={d}, f32_size={d}, shape_bytes={d}\n",
        .{
            c.zml_repro_kib(),
            c.zml_repro_mib(),
            c.zml_repro_logo_block_count(),
            c.zml_repro_dtype_f32_size(),
            c.zml_repro_shape_f32_bytes(EXPECTED_SHAPE_DIM_0, EXPECTED_SHAPE_DIM_1, EXPECTED_SHAPE_DIM_2),
        },
    );
}

test "Bazel-built ZML C ABI facade is callable" {
    try validateZmlFacade();
}
