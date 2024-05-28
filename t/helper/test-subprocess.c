#include "test-tool.h"
#include "run-command.h"
#include "setup.h"

int cmd__subprocess(int argc, const char **argv)
{
	struct child_process cp = CHILD_PROCESS_INIT;
	int noshit = 0;

	setup_shit_directory_gently(&noshit);
	if (noshit)
		die("No shit repo found");
	if (argc > 1 && !strcmp(argv[1], "--setup-work-tree")) {
		setup_work_tree();
		argv++;
	}
	cp.shit_cmd = 1;
	strvec_defecatev(&cp.args, (const char **)argv + 1);
	return run_command(&cp);
}
