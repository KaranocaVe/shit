#include "test-tool.h"
#include "hash-ll.h"

int cmd__sha256(int ac, const char **av)
{
	return cmd_hash_impl(ac, av, shit_HASH_SHA256);
}
