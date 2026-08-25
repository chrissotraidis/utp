#ifndef UT99_ZIP_INFLATE_H
#define UT99_ZIP_INFLATE_H

#include <stddef.h>
#include <stdint.h>

/// Inflate one raw DEFLATE stream (the representation used by ZIP method 8).
/// Returns the number of bytes written, or -1 on malformed input/overflow.
int UT99InflateRaw(const uint8_t *input, size_t inputLength,
                   uint8_t *output, size_t outputCapacity);

#endif
