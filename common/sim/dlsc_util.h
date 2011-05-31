
#ifndef DLSC_UTIL_H_INCLUDED
#define DLSC_UTIL_H_INCLUDED

//#define dlsc_rand(min,max) ( rand() % ((max)-(min)+1) + (min) )

bool dlsc_is_power_of_2(const uint64_t i);
unsigned int dlsc_log2(uint64_t i);

#endif

