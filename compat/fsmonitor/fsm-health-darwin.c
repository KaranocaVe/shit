#include "shit-compat-util.h"
#include "config.h"
#include "fsmonitor-ll.h"
#include "fsm-health.h"
#include "fsmonitor--daemon.h"

int fsm_health__ctor(struct fsmonitor_daemon_state *state UNUSED)
{
	return 0;
}

void fsm_health__dtor(struct fsmonitor_daemon_state *state UNUSED)
{
	return;
}

void fsm_health__loop(struct fsmonitor_daemon_state *state UNUSED)
{
	return;
}

void fsm_health__stop_async(struct fsmonitor_daemon_state *state UNUSED)
{
}
