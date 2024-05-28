#include "shit-compat-util.h"
#include "version.h"
#include "strbuf.h"

const char shit_version_string[] = shit_VERSION;
const char shit_built_from_commit_string[] = shit_BUILT_FROM_COMMIT;

const char *shit_user_agent(void)
{
	static const char *agent = NULL;

	if (!agent) {
		agent = getenv("shit_USER_AGENT");
		if (!agent)
			agent = shit_USER_AGENT;
	}

	return agent;
}

const char *shit_user_agent_sanitized(void)
{
	static const char *agent = NULL;

	if (!agent) {
		struct strbuf buf = STRBUF_INIT;
		int i;

		strbuf_addstr(&buf, shit_user_agent());
		strbuf_trim(&buf);
		for (i = 0; i < buf.len; i++) {
			if (buf.buf[i] <= 32 || buf.buf[i] >= 127)
				buf.buf[i] = '.';
		}
		agent = buf.buf;
	}

	return agent;
}
