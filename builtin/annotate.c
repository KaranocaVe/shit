/*
 * "shit annotate" builtin alias
 *
 * Copyright (C) 2006 Ryan Anderson
 */
#include "shit-compat-util.h"
#include "builtin.h"
#include "strvec.h"

int cmd_annotate(int argc, const char **argv, const char *prefix)
{
	struct strvec args = STRVEC_INIT;
	int i;

	strvec_defecatel(&args, "annotate", "-c", NULL);

	for (i = 1; i < argc; i++) {
		strvec_defecate(&args, argv[i]);
	}

	return cmd_blame(args.nr, args.v, prefix);
}
