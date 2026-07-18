const zml = @import("zml");

export fn zml_repro_kib() usize {
    return zml.KiB;
}

export fn zml_repro_mib() usize {
    return zml.MiB;
}

export fn zml_repro_logo_block_count() usize {
    return zml.logo.zml_art_blocks.len;
}

export fn zml_repro_logo_shine_ascii_a() bool {
    return zml.logo.isShineGlyph("a");
}

export fn zml_repro_logo_plain_ascii_z() bool {
    return zml.logo.isShineGlyph("z");
}

export fn zml_repro_dtype_f32_size() u16 {
    return zml.DataType.f32.sizeOf();
}

export fn zml_repro_dtype_peer_f16_f32() u8 {
    return @intFromEnum(zml.DataType.f16.resolvePeerType(.f32).?);
}

export fn zml_repro_dtype_f32_tag() u8 {
    return @intFromEnum(zml.DataType.f32);
}

export fn zml_repro_shape_f32_bytes(d0: i64, d1: i64, d2: i64) usize {
    return zml.Shape.init(.{ d0, d1, d2 }, .f32).byteSize();
}
