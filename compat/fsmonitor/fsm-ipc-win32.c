#include "shit-compat-util.h"
#include "config.h"
#include "fsmonitor-ipc.h"
#include "path.h"

const char *fsmonitor_ipc__get_path(struct repository *r) {
	static char *ret;
	if (!ret)
		ret = repo_shit_path(r, "fsmonitor--daemon.ipc");
	return ret;
}
