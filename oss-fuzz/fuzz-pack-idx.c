#include "shit-compat-util.h"
#include "object-store-ll.h"
#include "packfile.h"

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size);

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
	struct packed_shit p;

	load_idx("fuzz-input", shit_SHA1_RAWSZ, (void *)data, size, &p);

	return 0;
}
