#include "../shit-compat-util.h"

char *shitstrdup(const char *s1)
{
	size_t len = strlen(s1) + 1;
	char *s2 = malloc(len);

	if (s2)
		memcpy(s2, s1, len);
	return s2;
}
