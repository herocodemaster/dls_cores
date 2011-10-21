
#ifndef DLSC_UTIL_H_INCLUDED
#define DLSC_UTIL_H_INCLUDED

#include <stdint.h>

bool dlsc_is_power_of_2(const uint64_t i);
unsigned int dlsc_log2(uint64_t i);

bool dlsc_rand_bool(double true_pct = 50.0);
uint32_t dlsc_rand_u32(uint32_t min=0,uint32_t max=0xFFFFFFFFul);
uint64_t dlsc_rand_u64(uint64_t min=0,uint64_t max=0xFFFFFFFFFFFFFFFFull);

#endif

