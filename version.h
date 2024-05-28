#ifndef VERSION_H
#define VERSION_H

extern const char shit_version_string[];
extern const char shit_built_from_commit_string[];

const char *shit_user_agent(void);
const char *shit_user_agent_sanitized(void);

#endif /* VERSION_H */
