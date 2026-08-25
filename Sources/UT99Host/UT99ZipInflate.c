#include "UT99ZipInflate.h"
#include <limits.h>
#include <zlib.h>

int UT99InflateRaw(const uint8_t *input, size_t inputLength,
                   uint8_t *output, size_t outputCapacity) {
    if (!input || !output || inputLength > UINT_MAX || outputCapacity > UINT_MAX) {
        return -1;
    }
    z_stream stream = {0};
    stream.next_in = (Bytef *)input;
    stream.avail_in = (uInt)inputLength;
    stream.next_out = output;
    stream.avail_out = (uInt)outputCapacity;
    if (inflateInit2(&stream, -MAX_WBITS) != Z_OK) {
        return -1;
    }
    const int result = inflate(&stream, Z_FINISH);
    const size_t written = stream.total_out;
    inflateEnd(&stream);
    if (result != Z_STREAM_END || written > outputCapacity) {
        return -1;
    }
    return (int)written;
}
