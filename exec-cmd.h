#ifndef shit_EXEC_CMD_H
#define shit_EXEC_CMD_H

struct strvec;

void shit_set_exec_path(const char *exec_path);
void shit_resolve_executable_dir(const char *path);
const char *shit_exec_path(void);
void setup_path(void);
const char **prepare_shit_cmd(struct strvec *out, const char **argv);
int execv_shit_cmd(const char **argv); /* NULL terminated */
LAST_ARG_MUST_BE_NULL
int execl_shit_cmd(const char *cmd, ...);
char *system_path(const char *path);

#endif /* shit_EXEC_CMD_H */
