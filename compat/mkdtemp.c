#include "../shit-compat-util.h"

char *shitmkdtemp(char *template)
{
	if (!*mktemp(template) || mkdir(template, 0700))
		return NULL;
	return template;
}
