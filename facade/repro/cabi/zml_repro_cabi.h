#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

size_t zml_repro_kib(void);
size_t zml_repro_mib(void);
size_t zml_repro_logo_block_count(void);
bool zml_repro_logo_shine_ascii_a(void);
bool zml_repro_logo_plain_ascii_z(void);
uint16_t zml_repro_dtype_f32_size(void);
uint8_t zml_repro_dtype_peer_f16_f32(void);
uint8_t zml_repro_dtype_f32_tag(void);
size_t zml_repro_shape_f32_bytes(int64_t d0, int64_t d1, int64_t d2);

#ifdef __cplusplus
}
#endif
