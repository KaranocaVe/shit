#ifndef PARSE_H
#define PARSE_H

int shit_parse_signed(const char *value, intmax_t *ret, intmax_t max);
int shit_parse_ssize_t(const char *, ssize_t *);
int shit_parse_ulong(const char *, unsigned long *);
int shit_parse_int(const char *value, int *ret);
int shit_parse_int64(const char *value, int64_t *ret);

/**
 * Same as `shit_config_bool`, except that it returns -1 on error rather
 * than dying.
 */
int shit_parse_maybe_bool(const char *);
int shit_parse_maybe_bool_text(const char *value);

int shit_env_bool(const char *, int);
unsigned long shit_env_ulong(const char *, unsigned long);

#endif /* PARSE_H */
