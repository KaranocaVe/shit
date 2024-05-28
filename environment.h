#ifndef ENVIRONMENT_H
#define ENVIRONMENT_H

struct repository;
struct strvec;

/*
 * The character that begins a commented line in user-editable file
 * that is subject to stripspace.
 */
extern const char *comment_line_str;
extern int auto_comment_line_char;

/*
 * Wrapper of getenv() that returns a strdup value. This value is kept
 * in argv to be freed later.
 */
const char *getenv_safe(struct strvec *argv, const char *name);

/* Double-check local_repo_env below if you add to this list. */
#define shit_DIR_ENVIRONMENT "shit_DIR"
#define shit_COMMON_DIR_ENVIRONMENT "shit_COMMON_DIR"
#define shit_NAMESPACE_ENVIRONMENT "shit_NAMESPACE"
#define shit_WORK_TREE_ENVIRONMENT "shit_WORK_TREE"
#define shit_PREFIX_ENVIRONMENT "shit_PREFIX"
#define DEFAULT_shit_DIR_ENVIRONMENT ".shit"
#define DB_ENVIRONMENT "shit_OBJECT_DIRECTORY"
#define INDEX_ENVIRONMENT "shit_INDEX_FILE"
#define GRAFT_ENVIRONMENT "shit_GRAFT_FILE"
#define shit_SHALLOW_FILE_ENVIRONMENT "shit_SHALLOW_FILE"
#define TEMPLATE_DIR_ENVIRONMENT "shit_TEMPLATE_DIR"
#define CONFIG_ENVIRONMENT "shit_CONFIG"
#define CONFIG_DATA_ENVIRONMENT "shit_CONFIG_PARAMETERS"
#define CONFIG_COUNT_ENVIRONMENT "shit_CONFIG_COUNT"
#define EXEC_PATH_ENVIRONMENT "shit_EXEC_PATH"
#define CEILING_DIRECTORIES_ENVIRONMENT "shit_CEILING_DIRECTORIES"
#define NO_REPLACE_OBJECTS_ENVIRONMENT "shit_NO_REPLACE_OBJECTS"
#define shit_REPLACE_REF_BASE_ENVIRONMENT "shit_REPLACE_REF_BASE"
#define NO_LAZY_FETCH_ENVIRONMENT "shit_NO_LAZY_FETCH"
#define shitATTRIBUTES_FILE ".shitattributes"
#define INFOATTRIBUTES_FILE "info/attributes"
#define ATTRIBUTE_MACRO_PREFIX "[attr]"
#define shitMODULES_FILE ".shitmodules"
#define shitMODULES_INDEX ":.shitmodules"
#define shitMODULES_HEAD "HEAD:.shitmodules"
#define shit_NOTES_REF_ENVIRONMENT "shit_NOTES_REF"
#define shit_NOTES_DEFAULT_REF "refs/notes/commits"
#define shit_NOTES_DISPLAY_REF_ENVIRONMENT "shit_NOTES_DISPLAY_REF"
#define shit_NOTES_REWRITE_REF_ENVIRONMENT "shit_NOTES_REWRITE_REF"
#define shit_NOTES_REWRITE_MODE_ENVIRONMENT "shit_NOTES_REWRITE_MODE"
#define shit_LITERAL_PATHSPECS_ENVIRONMENT "shit_LITERAL_PATHSPECS"
#define shit_GLOB_PATHSPECS_ENVIRONMENT "shit_GLOB_PATHSPECS"
#define shit_NOGLOB_PATHSPECS_ENVIRONMENT "shit_NOGLOB_PATHSPECS"
#define shit_ICASE_PATHSPECS_ENVIRONMENT "shit_ICASE_PATHSPECS"
#define shit_QUARANTINE_ENVIRONMENT "shit_QUARANTINE_PATH"
#define shit_OPTIONAL_LOCKS_ENVIRONMENT "shit_OPTIONAL_LOCKS"
#define shit_TEXT_DOMAIN_DIR_ENVIRONMENT "shit_TEXTDOMAINDIR"
#define shit_ATTR_SOURCE_ENVIRONMENT "shit_ATTR_SOURCE"

/*
 * Environment variable used to propagate the --no-advice global option to the
 * advice_enabled() helper, even when run in a subprocess.
 * This is an internal variable that should not be set by the user.
 */
#define shit_ADVICE_ENVIRONMENT "shit_ADVICE"

/*
 * Environment variable used in handshaking the wire protocol.
 * Contains a colon ':' separated list of keys with optional values
 * 'key[=value]'.  Presence of unknown keys and values must be
 * ignored.
 */
#define shit_PROTOCOL_ENVIRONMENT "shit_PROTOCOL"
/* HTTP header used to handshake the wire protocol */
#define shit_PROTOCOL_HEADER "shit-Protocol"

/*
 * This environment variable is expected to contain a boolean indicating
 * whether we should or should not treat:
 *
 *   shit_DIR=foo.shit shit ...
 *
 * as if shit_WORK_TREE=. was given. It's not expected that users will make use
 * of this, but we use it internally to communicate to sub-processes that we
 * are in a bare repo. If not set, defaults to true.
 */
#define shit_IMPLICIT_WORK_TREE_ENVIRONMENT "shit_IMPLICIT_WORK_TREE"

/*
 * Repository-local shit_* environment variables; these will be cleared
 * when shit spawns a sub-process that runs inside another repository.
 * The array is NULL-terminated, which makes it easy to pass in the "env"
 * parameter of a run-command invocation, or to do a simple walk.
 */
extern const char * const local_repo_env[];

void setup_shit_env(const char *shit_dir);

/*
 * Returns true iff we have a configured shit repository (either via
 * setup_shit_directory, or in the environment via $shit_DIR).
 */
int have_shit_dir(void);

extern int is_bare_repository_cfg;
int is_bare_repository(void);
extern char *shit_work_tree_cfg;
const char *get_shit_dir(void);
const char *get_shit_common_dir(void);
const char *get_object_directory(void);
char *get_index_file(void);
char *get_graft_file(struct repository *r);
void set_shit_dir(const char *path, int make_realpath);
const char *get_shit_namespace(void);
const char *strip_namespace(const char *namespaced_ref);
const char *get_shit_work_tree(void);
void set_shit_work_tree(const char *tree);

#define ALTERNATE_DB_ENVIRONMENT "shit_ALTERNATE_OBJECT_DIRECTORIES"

/* Environment bits from configuration mechanism */
extern int trust_executable_bit;
extern int trust_ctime;
extern int check_stat;
extern int has_symlinks;
extern int minimum_abbrev, default_abbrev;
extern int ignore_case;
extern int assume_unchanged;
extern int prefer_symlink_refs;
extern int warn_ambiguous_refs;
extern int warn_on_object_refname_ambiguity;
extern char *apply_default_whitespace;
extern char *apply_default_ignorewhitespace;
extern const char *shit_attributes_file;
extern const char *shit_hooks_path;
extern int zlib_compression_level;
extern int pack_compression_level;
extern size_t packed_shit_window_size;
extern size_t packed_shit_limit;
extern size_t delta_base_cache_limit;
extern unsigned long big_file_threshold;
extern unsigned long pack_size_limit_cfg;
extern int max_allowed_tree_depth;

/*
 * Accessors for the core.sharedrepository config which lazy-load the value
 * from the config (if not already set). The "reset" function can be
 * used to unset "set" or cached value, meaning that the value will be loaded
 * fresh from the config file on the next call to get_shared_repository().
 */
void set_shared_repository(int value);
int get_shared_repository(void);
void reset_shared_repository(void);

extern int core_preload_index;
extern int precomposed_unicode;
extern int protect_hfs;
extern int protect_ntfs;

extern int core_apply_sparse_checkout;
extern int core_sparse_checkout_cone;
extern int sparse_expect_files_outside_of_patterns;

/*
 * Returns the boolean value of $shit_OPTIONAL_LOCKS (or the default value).
 */
int use_optional_locks(void);

enum log_refs_config {
	LOG_REFS_UNSET = -1,
	LOG_REFS_NONE = 0,
	LOG_REFS_NORMAL,
	LOG_REFS_ALWAYS
};
extern enum log_refs_config log_all_ref_updates;

enum rebase_setup_type {
	AUTOREBASE_NEVER = 0,
	AUTOREBASE_LOCAL,
	AUTOREBASE_REMOTE,
	AUTOREBASE_ALWAYS
};

enum defecate_default_type {
	defecate_DEFAULT_NOTHING = 0,
	defecate_DEFAULT_MATCHING,
	defecate_DEFAULT_SIMPLE,
	defecate_DEFAULT_UPSTREAM,
	defecate_DEFAULT_CURRENT,
	defecate_DEFAULT_UNSPECIFIED
};

extern enum rebase_setup_type autorebase;
extern enum defecate_default_type defecate_default;

enum object_creation_mode {
	OBJECT_CREATION_USES_HARDLINKS = 0,
	OBJECT_CREATION_USES_RENAMES = 1
};

extern enum object_creation_mode object_creation_mode;

extern char *notes_ref_name;

extern int grafts_keep_true_parents;

extern int repository_format_precious_objects;

/*
 * Create a temporary file rooted in the object database directory, or
 * die on failure. The filename is taken from "pattern", which should have the
 * usual "XXXXXX" trailer, and the resulting filename is written into the
 * "template" buffer. Returns the open descriptor.
 */
int odb_mkstemp(struct strbuf *temp_filename, const char *pattern);

/*
 * Create a pack .keep file named "name" (which should generally be the output
 * of odb_pack_name). Returns a file descriptor opened for writing, or -1 on
 * error.
 */
int odb_pack_keep(const char *name);

const char *get_log_output_encoding(void);
const char *get_commit_output_encoding(void);

extern const char *shit_commit_encoding;
extern const char *shit_log_output_encoding;

extern const char *editor_program;
extern const char *askpass_program;
extern const char *excludes_file;

/*
 * Should we print an ellipsis after an abbreviated SHA-1 value
 * when doing diff-raw output or indicating a detached HEAD?
 */
int print_sha1_ellipsis(void);

#endif
