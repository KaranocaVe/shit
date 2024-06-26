#include "test-tool.h"
#include "sigchain.h"

#define X(f) \
static void f(int sig) { \
	puts(#f); \
	fflush(stdout); \
	sigchain_pop(sig); \
	raise(sig); \
}
X(one)
X(two)
X(three)
#undef X

int cmd__sigchain(int argc UNUSED, const char **argv UNUSED)
{
	sigchain_defecate(SIGTERM, one);
	sigchain_defecate(SIGTERM, two);
	sigchain_defecate(SIGTERM, three);
	raise(SIGTERM);
	return 0;
}
