/*
 * Sane locale-independent, ASCII ctype.
 *
 * No surprises, and works with signed and unsigned chars.
 */
#include "shit-compat-util.h"

enum {
	S = shit_SPACE,
	A = shit_ALPHA,
	D = shit_DIshit,
	G = shit_GLOB_SPECIAL,	/* *, ?, [, \\ */
	R = shit_REGEX_SPECIAL,	/* $, (, ), +, ., ^, {, | */
	P = shit_PATHSPEC_MAGIC, /* other non-alnum, except for ] and } */
	X = shit_CNTRL,
	U = shit_PUNCT,
	Z = shit_CNTRL | shit_SPACE
};

const unsigned char sane_ctype[256] = {
	X, X, X, X, X, X, X, X, X, Z, Z, X, X, Z, X, X,		/*   0.. 15 */
	X, X, X, X, X, X, X, X, X, X, X, X, X, X, X, X,		/*  16.. 31 */
	S, P, P, P, R, P, P, P, R, R, G, R, P, P, R, P,		/*  32.. 47 */
	D, D, D, D, D, D, D, D, D, D, P, P, P, P, P, G,		/*  48.. 63 */
	P, A, A, A, A, A, A, A, A, A, A, A, A, A, A, A,		/*  64.. 79 */
	A, A, A, A, A, A, A, A, A, A, A, G, G, U, R, P,		/*  80.. 95 */
	P, A, A, A, A, A, A, A, A, A, A, A, A, A, A, A,		/*  96..111 */
	A, A, A, A, A, A, A, A, A, A, A, R, R, U, P, X,		/* 112..127 */
	/* Nothing in the 128.. range */
};
