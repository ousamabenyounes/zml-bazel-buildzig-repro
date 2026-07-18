const std = @import("std");
const zml = @import("zml");

const SHAPE_DIM_0: i64 = 2;
const SHAPE_DIM_1: i64 = 3;
const SHAPE_DIM_2: i64 = 5;

pub fn main() !void {
    const shape_bytes = zml.Shape.init(.{ SHAPE_DIM_0, SHAPE_DIM_1, SHAPE_DIM_2 }, .f32).byteSize();

    std.debug.print(
        "ZML Bazel executable OK: KiB={d}, MiB={d}, logo_blocks={d}, f32_size={d}, shape_bytes={d}\n",
        .{
            zml.KiB,
            zml.MiB,
            zml.logo.zml_art_blocks.len,
            zml.DataType.f32.sizeOf(),
            shape_bytes,
        },
    );
}
