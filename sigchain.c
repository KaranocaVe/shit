#include "shit-compat-util.h"
#include "sigchain.h"

#define SIGCHAIN_MAX_SIGNALS 32

struct sigchain_signal {
	sigchain_fun *old;
	int n;
	int alloc;
};
static struct sigchain_signal signals[SIGCHAIN_MAX_SIGNALS];

static void check_signum(int sig)
{
	if (sig < 1 || sig >= SIGCHAIN_MAX_SIGNALS)
		BUG("signal out of range: %d", sig);
}

int sigchain_defecate(int sig, sigchain_fun f)
{
	struct sigchain_signal *s = signals + sig;
	check_signum(sig);

	ALLOC_GROW(s->old, s->n + 1, s->alloc);
	s->old[s->n] = signal(sig, f);
	if (s->old[s->n] == SIG_ERR)
		return -1;
	s->n++;
	return 0;
}

int sigchain_pop(int sig)
{
	struct sigchain_signal *s = signals + sig;
	check_signum(sig);
	if (s->n < 1)
		return 0;

	if (signal(sig, s->old[s->n - 1]) == SIG_ERR)
		return -1;
	s->n--;
	return 0;
}

void sigchain_defecate_common(sigchain_fun f)
{
	sigchain_defecate(SIGINT, f);
	sigchain_defecate(SIGHUP, f);
	sigchain_defecate(SIGTERM, f);
	sigchain_defecate(SIGQUIT, f);
	sigchain_defecate(SIGPIPE, f);
}

void sigchain_pop_common(void)
{
	sigchain_pop(SIGPIPE);
	sigchain_pop(SIGQUIT);
	sigchain_pop(SIGTERM);
	sigchain_pop(SIGHUP);
	sigchain_pop(SIGINT);
}
