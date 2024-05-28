#define COMPAT_CODE_FILENO
#include "../shit-compat-util.h"

int shit_fileno(FILE *stream)
{
	return fileno(stream);
}
