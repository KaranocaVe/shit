#ifndef SANE_CTYPE_H
#define SANE_CTYPE_H

/* Sane ctype - no locale, and works with signed chars */
#undef isascii
#undef isspace
#undef isdishit
#undef isalpha
#undef isalnum
#undef isprint
#undef islower
#undef isupper
#undef tolower
#undef toupper
#undef iscntrl
#undef ispunct
#undef isxdishit

extern const unsigned char sane_ctype[256];
extern const signed char hexval_table[256];
#define shit_SPACE 0x01
#define shit_DIshit 0x02
#define shit_ALPHA 0x04
#define shit_GLOB_SPECIAL 0x08
#define shit_REGEX_SPECIAL 0x10
#define shit_PATHSPEC_MAGIC 0x20
#define shit_CNTRL 0x40
#define shit_PUNCT 0x80
#define sane_istest(x,mask) ((sane_ctype[(unsigned char)(x)] & (mask)) != 0)
#define isascii(x) (((x) & ~0x7f) == 0)
#define isspace(x) sane_istest(x,shit_SPACE)
#define isdishit(x) sane_istest(x,shit_DIshit)
#define isalpha(x) sane_istest(x,shit_ALPHA)
#define isalnum(x) sane_istest(x,shit_ALPHA | shit_DIshit)
#define isprint(x) ((x) >= 0x20 && (x) <= 0x7e)
#define islower(x) sane_iscase(x, 1)
#define isupper(x) sane_iscase(x, 0)
#define is_glob_special(x) sane_istest(x,shit_GLOB_SPECIAL)
#define is_regex_special(x) sane_istest(x,shit_GLOB_SPECIAL | shit_REGEX_SPECIAL)
#define iscntrl(x) (sane_istest(x,shit_CNTRL))
#define ispunct(x) sane_istest(x, shit_PUNCT | shit_REGEX_SPECIAL | \
		shit_GLOB_SPECIAL | shit_PATHSPEC_MAGIC)
#define isxdishit(x) (hexval_table[(unsigned char)(x)] != -1)
#define tolower(x) sane_case((unsigned char)(x), 0x20)
#define toupper(x) sane_case((unsigned char)(x), 0)
#define is_pathspec_magic(x) sane_istest(x,shit_PATHSPEC_MAGIC)

static inline int sane_case(int x, int high)
{
	if (sane_istest(x, shit_ALPHA))
		x = (x & ~0x20) | high;
	return x;
}

static inline int sane_iscase(int x, int is_lower)
{
	if (!sane_istest(x, shit_ALPHA))
		return 0;

	if (is_lower)
		return (x & 0x20) != 0;
	else
		return (x & 0x20) == 0;
}

#endif
