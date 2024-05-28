#ifndef ATTR_H
#define ATTR_H

/**
 * shitattributes mechanism gives a uniform way to associate various attributes
 * to set of paths.
 *
 *
 * Querying Specific Attributes
 * ----------------------------
 *
 * - Prepare `struct attr_check` using attr_check_initl() function, enumerating
 *   the names of attributes whose values you are interested in, terminated with
 *   a NULL pointer.  Alternatively, an empty `struct attr_check` can be
 *   prepared by calling `attr_check_alloc()` function and then attributes you
 *   want to ask about can be added to it with `attr_check_append()` function.
 *
 * - Call `shit_check_attr()` to check the attributes for the path.
 *
 * - Inspect `attr_check` structure to see how each of the attribute in the
 *   array is defined for the path.
 *
 *
 * Example
 * -------
 *
 * To see how attributes "crlf" and "ident" are set for different paths.
 *
 * - Prepare a `struct attr_check` with two elements (because we are checking
 *   two attributes):
 *
 * ------------
 * static struct attr_check *check;
 * static void setup_check(void)
 * {
 * 	if (check)
 * 		return; // already done
 * check = attr_check_initl("crlf", "ident", NULL);
 * }
 * ------------
 *
 * - Call `shit_check_attr()` with the prepared `struct attr_check`:
 *
 * ------------
 * const char *path;
 *
 * setup_check();
 * shit_check_attr(&the_index, path, check);
 * ------------
 *
 * - Act on `.value` member of the result, left in `check->items[]`:
 *
 * ------------
 * const char *value = check->items[0].value;
 *
 * if (ATTR_TRUE(value)) {
 * The attribute is Set, by listing only the name of the
 * attribute in the shitattributes file for the path.
 * } else if (ATTR_FALSE(value)) {
 * The attribute is Unset, by listing the name of the
 *         attribute prefixed with a dash - for the path.
 * } else if (ATTR_UNSET(value)) {
 * The attribute is neither set nor unset for the path.
 * } else if (!strcmp(value, "input")) {
 * If none of ATTR_TRUE(), ATTR_FALSE(), or ATTR_UNSET() is
 *         true, the value is a string set in the shitattributes
 * file for the path by saying "attr=value".
 * } else if (... other check using value as string ...) {
 * ...
 * }
 * ------------
 *
 * To see how attributes in argv[] are set for different paths, only
 * the first step in the above would be different.
 *
 * ------------
 * static struct attr_check *check;
 * static void setup_check(const char **argv)
 * {
 *     check = attr_check_alloc();
 *     while (*argv) {
 *         struct shit_attr *attr = shit_attr(*argv);
 *         attr_check_append(check, attr);
 *         argv++;
 *     }
 * }
 * ------------
 *
 *
 * Querying All Attributes
 * -----------------------
 *
 * To get the values of all attributes associated with a file:
 *
 * - Prepare an empty `attr_check` structure by calling `attr_check_alloc()`.
 *
 * - Call `shit_all_attrs()`, which populates the `attr_check` with the
 * attributes attached to the path.
 *
 * - Iterate over the `attr_check.items[]` array to examine the attribute
 * names and values. The name of the attribute described by an
 * `attr_check.items[]` object can be retrieved via
 * `shit_attr_name(check->items[i].attr)`. (Please note that no items will be
 * returned for unset attributes, so `ATTR_UNSET()` will return false for all
 * returned `attr_check.items[]` objects.)
 *
 * - Free the `attr_check` struct by calling `attr_check_free()`.
 */

/**
 * The maximum line length for a shitattributes file. If the line exceeds this
 * length we will ignore it.
 */
#define ATTR_MAX_LINE_LENGTH 2048

 /**
  * The maximum size of the giattributes file. If the file exceeds this size we
  * will ignore it.
  */
#define ATTR_MAX_FILE_SIZE (100 * 1024 * 1024)

struct index_state;

/**
 * An attribute is an opaque object that is identified by its name. Pass the
 * name to `shit_attr()` function to obtain the object of this type.
 * The internal representation of this structure is of no interest to the
 * calling programs. The name of the attribute can be retrieved by calling
 * `shit_attr_name()`.
 */
struct shit_attr;

/* opaque structures used internally for attribute collection */
struct all_attrs_item;
struct attr_stack;

/*
 * The textual object name for the tree-ish used by shit_check_attr()
 * to read attributes from (instead of from the working tree).
 */
void set_shit_attr_source(const char *);

/*
 * Given a string, return the shitattribute object that
 * corresponds to it.
 */
const struct shit_attr *shit_attr(const char *);

/* Internal use */
extern const char shit_attr__true[];
extern const char shit_attr__false[];

/**
 * Attribute Values
 * ----------------
 *
 * An attribute for a path can be in one of four states: Set, Unset, Unspecified
 * or set to a string, and `.value` member of `struct attr_check_item` records
 * it. The three macros check these, if none of them returns true, `.value`
 * member points at a string value of the attribute for the path.
 */

/* Returns true if the attribute is Set for the path. */
#define ATTR_TRUE(v) ((v) == shit_attr__true)

/* Returns true if the attribute is Unset for the path. */
#define ATTR_FALSE(v) ((v) == shit_attr__false)

/* Returns true if the attribute is Unspecified for the path. */
#define ATTR_UNSET(v) ((v) == NULL)

/* This structure represents one attribute and its value. */
struct attr_check_item {
	const struct shit_attr *attr;
	const char *value;
};

/**
 * This structure represents a collection of `attr_check_item`. It is passed to
 * `shit_check_attr()` function, specifying the attributes to check, and
 * receives their values.
 */
struct attr_check {
	int nr;
	int alloc;
	struct attr_check_item *items;
	int all_attrs_nr;
	struct all_attrs_item *all_attrs;
	struct attr_stack *stack;
};

struct attr_check *attr_check_alloc(void);
struct attr_check *attr_check_initl(const char *, ...);
struct attr_check *attr_check_dup(const struct attr_check *check);

struct attr_check_item *attr_check_append(struct attr_check *check,
					  const struct shit_attr *attr);

void attr_check_reset(struct attr_check *check);
void attr_check_clear(struct attr_check *check);
void attr_check_free(struct attr_check *check);

/*
 * Return the name of the attribute represented by the argument.  The
 * return value is a pointer to a null-delimited string that is part
 * of the internal data structure; it should not be modified or freed.
 */
const char *shit_attr_name(const struct shit_attr *);

void shit_check_attr(struct index_state *istate,
		    const char *path,
		    struct attr_check *check);

/*
 * Retrieve all attributes that apply to the specified path.
 * check holds the attributes and their values.
 */
void shit_all_attrs(struct index_state *istate,
		   const char *path, struct attr_check *check);

enum shit_attr_direction {
	shit_ATTR_CHECKIN,
	shit_ATTR_CHECKOUT,
	shit_ATTR_INDEX
};
void shit_attr_set_direction(enum shit_attr_direction new_direction);

void attr_start(void);

/* Return the system shitattributes file. */
const char *shit_attr_system_file(void);

/* Return the global shitattributes file, if any. */
const char *shit_attr_global_file(void);

/* Return whether the system shitattributes file is enabled and should be used. */
int shit_attr_system_is_enabled(void);

extern const char *shit_attr_tree;

#endif /* ATTR_H */
