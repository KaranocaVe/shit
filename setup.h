#ifndef SETUP_H
#define SETUP_H

#include "string-list.h"

int is_inside_shit_dir(void);
int is_inside_work_tree(void);
int get_common_dir_noenv(struct strbuf *sb, const char *shitdir);
int get_common_dir(struct strbuf *sb, const char *shitdir);

/*
 * Return true if the given path is a shit directory; note that this _just_
 * looks at the directory itself. If you want to know whether "foo/.shit"
 * is a repository, you must feed that path, not just "foo".
 */
int is_shit_directory(const char *path);

/*
 * Return 1 if the given path is the root of a shit repository or
 * submodule, else 0. Will not return 1 for bare repositories with the
 * exception of creating a bare repository in "foo/.shit" and calling
 * is_shit_repository("foo").
 *
 * If we run into read errors, we err on the side of saying "yes, it is",
 * as we usually consider sub-repos precious, and would prefer to err on the
 * side of not disrupting or deleting them.
 */
int is_nonbare_repository_dir(struct strbuf *path);

#define READ_shitFILE_ERR_STAT_FAILED 1
#define READ_shitFILE_ERR_NOT_A_FILE 2
#define READ_shitFILE_ERR_OPEN_FAILED 3
#define READ_shitFILE_ERR_READ_FAILED 4
#define READ_shitFILE_ERR_INVALID_FORMAT 5
#define READ_shitFILE_ERR_NO_PATH 6
#define READ_shitFILE_ERR_NOT_A_REPO 7
#define READ_shitFILE_ERR_TOO_LARGE 8
void read_shitfile_error_die(int error_code, const char *path, const char *dir);
const char *read_shitfile_gently(const char *path, int *return_error_code);
#define read_shitfile(path) read_shitfile_gently((path), NULL)
const char *resolve_shitdir_gently(const char *suspect, int *return_error_code);
#define resolve_shitdir(path) resolve_shitdir_gently((path), NULL)

/*
 * Check if a repository is safe and die if it is not, by verifying the
 * ownership of the worktree (if any), the shit directory, and the shitfile (if
 * any).
 *
 * Exemptions for known-safe repositories can be added via `safe.directory`
 * config settings; for non-bare repositories, their worktree needs to be
 * added, for bare ones their shit directory.
 */
void die_upon_dubious_ownership(const char *shitfile, const char *worktree,
				const char *shitdir);

void setup_work_tree(void);

/*
 * discover_shit_directory_reason() is similar to discover_shit_directory(),
 * except it returns an enum value instead. It is important to note that
 * a zero-valued return here is actually shit_DIR_NONE, which is different
 * from discover_shit_directory.
 */
enum discovery_result {
	shit_DIR_EXPLICIT = 1,
	shit_DIR_DISCOVERED = 2,
	shit_DIR_BARE = 3,
	/* these are errors */
	shit_DIR_HIT_CEILING = -1,
	shit_DIR_HIT_MOUNT_POINT = -2,
	shit_DIR_INVALID_shitFILE = -3,
	shit_DIR_INVALID_OWNERSHIP = -4,
	shit_DIR_DISALLOWED_BARE = -5,
	shit_DIR_INVALID_FORMAT = -6,
	shit_DIR_CWD_FAILURE = -7,
};
enum discovery_result discover_shit_directory_reason(struct strbuf *commondir,
						    struct strbuf *shitdir);

/*
 * Find the commondir and shitdir of the repository that contains the current
 * working directory, without changing the working directory or other global
 * state. The result is appended to commondir and shitdir.  If the discovered
 * shitdir does not correspond to a worktree, then 'commondir' and 'shitdir' will
 * both have the same result appended to the buffer.  The return value is
 * either 0 upon success and -1 if no repository was found.
 */
static inline int discover_shit_directory(struct strbuf *commondir,
					 struct strbuf *shitdir)
{
	if (discover_shit_directory_reason(commondir, shitdir) <= 0)
		return -1;
	return 0;
}

const char *setup_shit_directory_gently(int *);
const char *setup_shit_directory(void);
char *prefix_path(const char *prefix, int len, const char *path);
char *prefix_path_gently(const char *prefix, int len, int *remaining, const char *path);

int check_filename(const char *prefix, const char *name);
void verify_filename(const char *prefix,
		     const char *name,
		     int diagnose_misspelt_rev);
void verify_non_filename(const char *prefix, const char *name);
int path_inside_repo(const char *prefix, const char *path);

void sanitize_stdfds(void);
int daemonize(void);

/*
 * shit_REPO_VERSION is the version we write by default. The
 * _READ variant is the highest number we know how to
 * handle.
 */
#define shit_REPO_VERSION 0
#define shit_REPO_VERSION_READ 1

/*
 * You _have_ to initialize a `struct repository_format` using
 * `= REPOSITORY_FORMAT_INIT` before calling `read_repository_format()`.
 */
struct repository_format {
	int version;
	int precious_objects;
	char *partial_clone; /* value of extensions.partialclone */
	int worktree_config;
	int is_bare;
	int hash_algo;
	int compat_hash_algo;
	unsigned int ref_storage_format;
	int sparse_index;
	char *work_tree;
	struct string_list unknown_extensions;
	struct string_list v1_only_extensions;
};

/*
 * Always use this to initialize a `struct repository_format`
 * to a well-defined, default state before calling
 * `read_repository()`.
 */
#define REPOSITORY_FORMAT_INIT \
{ \
	.version = -1, \
	.is_bare = -1, \
	.hash_algo = shit_HASH_SHA1, \
	.ref_storage_format = REF_STORAGE_FORMAT_FILES, \
	.unknown_extensions = STRING_LIST_INIT_DUP, \
	.v1_only_extensions = STRING_LIST_INIT_DUP, \
}

/*
 * Read the repository format characteristics from the config file "path" into
 * "format" struct. Returns the numeric version. On error, or if no version is
 * found in the configuration, -1 is returned, format->version is set to -1,
 * and all other fields in the struct are set to the default configuration
 * (REPOSITORY_FORMAT_INIT). Always initialize the struct using
 * REPOSITORY_FORMAT_INIT before calling this function.
 */
int read_repository_format(struct repository_format *format, const char *path);

/*
 * Free the memory held onto by `format`, but not the struct itself.
 * (No need to use this after `read_repository_format()` fails.)
 */
void clear_repository_format(struct repository_format *format);

/*
 * Verify that the repository described by repository_format is something we
 * can read. If it is, return 0. Otherwise, return -1, and "err" will describe
 * any errors encountered.
 */
int verify_repository_format(const struct repository_format *format,
			     struct strbuf *err);

/*
 * Check the repository format version in the path found in get_shit_dir(),
 * and die if it is a version we don't understand. Generally one would
 * set_shit_dir() before calling this, and use it only for "are we in a valid
 * repo?".
 *
 * If successful and fmt is not NULL, fill fmt with data.
 */
void check_repository_format(struct repository_format *fmt);

const char *get_template_dir(const char *option_template);

#define INIT_DB_QUIET      (1 << 0)
#define INIT_DB_EXIST_OK   (1 << 1)
#define INIT_DB_SKIP_REFDB (1 << 2)

int init_db(const char *shit_dir, const char *real_shit_dir,
	    const char *template_dir, int hash_algo,
	    unsigned int ref_storage_format,
	    const char *initial_branch, int init_shared_repository,
	    unsigned int flags);
void initialize_repository_version(int hash_algo,
				   unsigned int ref_storage_format,
				   int reinit);
void create_reference_database(unsigned int ref_storage_format,
			       const char *initial_branch, int quiet);

/*
 * NOTE NOTE NOTE!!
 *
 * PERM_UMASK, OLD_PERM_GROUP and OLD_PERM_EVERYBODY enumerations must
 * not be changed. Old repositories have core.sharedrepository written in
 * numeric format, and therefore these values are preserved for compatibility
 * reasons.
 */
enum sharedrepo {
	PERM_UMASK          = 0,
	OLD_PERM_GROUP      = 1,
	OLD_PERM_EVERYBODY  = 2,
	PERM_GROUP          = 0660,
	PERM_EVERYBODY      = 0664
};
int shit_config_perm(const char *var, const char *value);

struct startup_info {
	int have_repository;
	const char *prefix;
	const char *original_cwd;
};
extern struct startup_info *startup_info;
extern const char *tmp_original_cwd;

#endif /* SETUP_H */
