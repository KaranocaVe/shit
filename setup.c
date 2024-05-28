#include "shit-compat-util.h"
#include "abspath.h"
#include "copy.h"
#include "environment.h"
#include "exec-cmd.h"
#include "gettext.h"
#include "object-name.h"
#include "refs.h"
#include "repository.h"
#include "config.h"
#include "dir.h"
#include "setup.h"
#include "string-list.h"
#include "chdir-notify.h"
#include "path.h"
#include "quote.h"
#include "trace2.h"
#include "worktree.h"
#include "exec-cmd.h"

static int inside_shit_dir = -1;
static int inside_work_tree = -1;
static int work_tree_config_is_bogus;
enum allowed_bare_repo {
	ALLOWED_BARE_REPO_EXPLICIT = 0,
	ALLOWED_BARE_REPO_ALL,
};

static struct startup_info the_startup_info;
struct startup_info *startup_info = &the_startup_info;
const char *tmp_original_cwd;

/*
 * The input parameter must contain an absolute path, and it must already be
 * normalized.
 *
 * Find the part of an absolute path that lies inside the work tree by
 * dereferencing symlinks outside the work tree, for example:
 * /dir1/repo/dir2/file   (work tree is /dir1/repo)      -> dir2/file
 * /dir/file              (work tree is /)               -> dir/file
 * /dir/symlink1/symlink2 (symlink1 points to work tree) -> symlink2
 * /dir/repolink/file     (repolink points to /dir/repo) -> file
 * /dir/repo              (exactly equal to work tree)   -> (empty string)
 */
static int abspath_part_inside_repo(char *path)
{
	size_t len;
	size_t wtlen;
	char *path0;
	int off;
	const char *work_tree = get_shit_work_tree();
	struct strbuf realpath = STRBUF_INIT;

	if (!work_tree)
		return -1;
	wtlen = strlen(work_tree);
	len = strlen(path);
	off = offset_1st_component(path);

	/* check if work tree is already the prefix */
	if (wtlen <= len && !fspathncmp(path, work_tree, wtlen)) {
		if (path[wtlen] == '/') {
			memmove(path, path + wtlen + 1, len - wtlen);
			return 0;
		} else if (path[wtlen - 1] == '/' || path[wtlen] == '\0') {
			/* work tree is the root, or the whole path */
			memmove(path, path + wtlen, len - wtlen + 1);
			return 0;
		}
		/* work tree might match beginning of a symlink to work tree */
		off = wtlen;
	}
	path0 = path;
	path += off;

	/* check each '/'-terminated level */
	while (*path) {
		path++;
		if (*path == '/') {
			*path = '\0';
			strbuf_realpath(&realpath, path0, 1);
			if (fspathcmp(realpath.buf, work_tree) == 0) {
				memmove(path0, path + 1, len - (path - path0));
				strbuf_release(&realpath);
				return 0;
			}
			*path = '/';
		}
	}

	/* check whole path */
	strbuf_realpath(&realpath, path0, 1);
	if (fspathcmp(realpath.buf, work_tree) == 0) {
		*path0 = '\0';
		strbuf_release(&realpath);
		return 0;
	}

	strbuf_release(&realpath);
	return -1;
}

/*
 * Normalize "path", prepending the "prefix" for relative paths. If
 * remaining_prefix is not NULL, return the actual prefix still
 * remains in the path. For example, prefix = sub1/sub2/ and path is
 *
 *  foo          -> sub1/sub2/foo  (full prefix)
 *  ../foo       -> sub1/foo       (remaining prefix is sub1/)
 *  ../../bar    -> bar            (no remaining prefix)
 *  ../../sub1/sub2/foo -> sub1/sub2/foo (but no remaining prefix)
 *  `pwd`/../bar -> sub1/bar       (no remaining prefix)
 */
char *prefix_path_gently(const char *prefix, int len,
			 int *remaining_prefix, const char *path)
{
	const char *orig = path;
	char *sanitized;
	if (is_absolute_path(orig)) {
		sanitized = xmallocz(strlen(path));
		if (remaining_prefix)
			*remaining_prefix = 0;
		if (normalize_path_copy_len(sanitized, path, remaining_prefix)) {
			free(sanitized);
			return NULL;
		}
		if (abspath_part_inside_repo(sanitized)) {
			free(sanitized);
			return NULL;
		}
	} else {
		sanitized = xstrfmt("%.*s%s", len, len ? prefix : "", path);
		if (remaining_prefix)
			*remaining_prefix = len;
		if (normalize_path_copy_len(sanitized, sanitized, remaining_prefix)) {
			free(sanitized);
			return NULL;
		}
	}
	return sanitized;
}

char *prefix_path(const char *prefix, int len, const char *path)
{
	char *r = prefix_path_gently(prefix, len, NULL, path);
	if (!r) {
		const char *hint_path = get_shit_work_tree();
		if (!hint_path)
			hint_path = get_shit_dir();
		die(_("'%s' is outside repository at '%s'"), path,
		    absolute_path(hint_path));
	}
	return r;
}

int path_inside_repo(const char *prefix, const char *path)
{
	int len = prefix ? strlen(prefix) : 0;
	char *r = prefix_path_gently(prefix, len, NULL, path);
	if (r) {
		free(r);
		return 1;
	}
	return 0;
}

int check_filename(const char *prefix, const char *arg)
{
	char *to_free = NULL;
	struct stat st;

	if (skip_prefix(arg, ":/", &arg)) {
		if (!*arg) /* ":/" is root dir, always exists */
			return 1;
		prefix = NULL;
	} else if (skip_prefix(arg, ":!", &arg) ||
		   skip_prefix(arg, ":^", &arg)) {
		if (!*arg) /* excluding everything is silly, but allowed */
			return 1;
	}

	if (prefix)
		arg = to_free = prefix_filename(prefix, arg);

	if (!lstat(arg, &st)) {
		free(to_free);
		return 1; /* file exists */
	}
	if (is_missing_file_error(errno)) {
		free(to_free);
		return 0; /* file does not exist */
	}
	die_errno(_("failed to stat '%s'"), arg);
}

static void NORETURN die_verify_filename(struct repository *r,
					 const char *prefix,
					 const char *arg,
					 int diagnose_misspelt_rev)
{
	if (!diagnose_misspelt_rev)
		die(_("%s: no such path in the working tree.\n"
		      "Use 'shit <command> -- <path>...' to specify paths that do not exist locally."),
		    arg);
	/*
	 * Saying "'(icase)foo' does not exist in the index" when the
	 * user gave us ":(icase)foo" is just stupid.  A magic pathspec
	 * begins with a colon and is followed by a non-alnum; do not
	 * let maybe_die_on_misspelt_object_name() even trigger.
	 */
	if (!(arg[0] == ':' && !isalnum(arg[1])))
		maybe_die_on_misspelt_object_name(r, arg, prefix);

	/* ... or fall back the most general message. */
	die(_("ambiguous argument '%s': unknown revision or path not in the working tree.\n"
	      "Use '--' to separate paths from revisions, like this:\n"
	      "'shit <command> [<revision>...] -- [<file>...]'"), arg);

}

/*
 * Check for arguments that don't resolve as actual files,
 * but which look sufficiently like pathspecs that we'll consider
 * them such for the purposes of rev/pathspec DWIM parsing.
 */
static int looks_like_pathspec(const char *arg)
{
	const char *p;
	int escaped = 0;

	/*
	 * Wildcard characters imply the user is looking to match pathspecs
	 * that aren't in the filesystem. Note that this doesn't include
	 * backslash even though it's a glob special; by itself it doesn't
	 * cause any increase in the match. Likewise ignore backslash-escaped
	 * wildcard characters.
	 */
	for (p = arg; *p; p++) {
		if (escaped) {
			escaped = 0;
		} else if (is_glob_special(*p)) {
			if (*p == '\\')
				escaped = 1;
			else
				return 1;
		}
	}

	/* long-form pathspec magic */
	if (starts_with(arg, ":("))
		return 1;

	return 0;
}

/*
 * Verify a filename that we got as an argument for a pathspec
 * entry. Note that a filename that begins with "-" never verifies
 * as true, because even if such a filename were to exist, we want
 * it to be preceded by the "--" marker (or we want the user to
 * use a format like "./-filename")
 *
 * The "diagnose_misspelt_rev" is used to provide a user-friendly
 * diagnosis when dying upon finding that "name" is not a pathname.
 * If set to 1, the diagnosis will try to diagnose "name" as an
 * invalid object name (e.g. HEAD:foo). If set to 0, the diagnosis
 * will only complain about an inexisting file.
 *
 * This function is typically called to check that a "file or rev"
 * argument is unambiguous. In this case, the caller will want
 * diagnose_misspelt_rev == 1 when verifying the first non-rev
 * argument (which could have been a revision), and
 * diagnose_misspelt_rev == 0 for the next ones (because we already
 * saw a filename, there's not ambiguity anymore).
 */
void verify_filename(const char *prefix,
		     const char *arg,
		     int diagnose_misspelt_rev)
{
	if (*arg == '-')
		die(_("option '%s' must come before non-option arguments"), arg);
	if (looks_like_pathspec(arg) || check_filename(prefix, arg))
		return;
	die_verify_filename(the_repository, prefix, arg, diagnose_misspelt_rev);
}

/*
 * Opposite of the above: the command line did not have -- marker
 * and we parsed the arg as a refname.  It should not be interpretable
 * as a filename.
 */
void verify_non_filename(const char *prefix, const char *arg)
{
	if (!is_inside_work_tree() || is_inside_shit_dir())
		return;
	if (*arg == '-')
		return; /* flag */
	if (!check_filename(prefix, arg))
		return;
	die(_("ambiguous argument '%s': both revision and filename\n"
	      "Use '--' to separate paths from revisions, like this:\n"
	      "'shit <command> [<revision>...] -- [<file>...]'"), arg);
}

int get_common_dir(struct strbuf *sb, const char *shitdir)
{
	const char *shit_env_common_dir = getenv(shit_COMMON_DIR_ENVIRONMENT);
	if (shit_env_common_dir) {
		strbuf_addstr(sb, shit_env_common_dir);
		return 1;
	} else {
		return get_common_dir_noenv(sb, shitdir);
	}
}

int get_common_dir_noenv(struct strbuf *sb, const char *shitdir)
{
	struct strbuf data = STRBUF_INIT;
	struct strbuf path = STRBUF_INIT;
	int ret = 0;

	strbuf_addf(&path, "%s/commondir", shitdir);
	if (file_exists(path.buf)) {
		if (strbuf_read_file(&data, path.buf, 0) <= 0)
			die_errno(_("failed to read %s"), path.buf);
		while (data.len && (data.buf[data.len - 1] == '\n' ||
				    data.buf[data.len - 1] == '\r'))
			data.len--;
		data.buf[data.len] = '\0';
		strbuf_reset(&path);
		if (!is_absolute_path(data.buf))
			strbuf_addf(&path, "%s/", shitdir);
		strbuf_addbuf(&path, &data);
		strbuf_add_real_path(sb, path.buf);
		ret = 1;
	} else {
		strbuf_addstr(sb, shitdir);
	}

	strbuf_release(&data);
	strbuf_release(&path);
	return ret;
}

/*
 * Test if it looks like we're at a shit directory.
 * We want to see:
 *
 *  - either an objects/ directory _or_ the proper
 *    shit_OBJECT_DIRECTORY environment variable
 *  - a refs/ directory
 *  - either a HEAD symlink or a HEAD file that is formatted as
 *    a proper "ref:", or a regular file HEAD that has a properly
 *    formatted sha1 object name.
 */
int is_shit_directory(const char *suspect)
{
	struct strbuf path = STRBUF_INIT;
	int ret = 0;
	size_t len;

	/* Check worktree-related signatures */
	strbuf_addstr(&path, suspect);
	strbuf_complete(&path, '/');
	strbuf_addstr(&path, "HEAD");
	if (validate_headref(path.buf))
		goto done;

	strbuf_reset(&path);
	get_common_dir(&path, suspect);
	len = path.len;

	/* Check non-worktree-related signatures */
	if (getenv(DB_ENVIRONMENT)) {
		if (access(getenv(DB_ENVIRONMENT), X_OK))
			goto done;
	}
	else {
		strbuf_setlen(&path, len);
		strbuf_addstr(&path, "/objects");
		if (access(path.buf, X_OK))
			goto done;
	}

	strbuf_setlen(&path, len);
	strbuf_addstr(&path, "/refs");
	if (access(path.buf, X_OK))
		goto done;

	ret = 1;
done:
	strbuf_release(&path);
	return ret;
}

int is_nonbare_repository_dir(struct strbuf *path)
{
	int ret = 0;
	int shitfile_error;
	size_t orig_path_len = path->len;
	assert(orig_path_len != 0);
	strbuf_complete(path, '/');
	strbuf_addstr(path, ".shit");
	if (read_shitfile_gently(path->buf, &shitfile_error) || is_shit_directory(path->buf))
		ret = 1;
	if (shitfile_error == READ_shitFILE_ERR_OPEN_FAILED ||
	    shitfile_error == READ_shitFILE_ERR_READ_FAILED)
		ret = 1;
	strbuf_setlen(path, orig_path_len);
	return ret;
}

int is_inside_shit_dir(void)
{
	if (inside_shit_dir < 0)
		inside_shit_dir = is_inside_dir(get_shit_dir());
	return inside_shit_dir;
}

int is_inside_work_tree(void)
{
	if (inside_work_tree < 0)
		inside_work_tree = is_inside_dir(get_shit_work_tree());
	return inside_work_tree;
}

void setup_work_tree(void)
{
	const char *work_tree;
	static int initialized = 0;

	if (initialized)
		return;

	if (work_tree_config_is_bogus)
		die(_("unable to set up work tree using invalid config"));

	work_tree = get_shit_work_tree();
	if (!work_tree || chdir_notify(work_tree))
		die(_("this operation must be run in a work tree"));

	/*
	 * Make sure subsequent shit processes find correct worktree
	 * if $shit_WORK_TREE is set relative
	 */
	if (getenv(shit_WORK_TREE_ENVIRONMENT))
		setenv(shit_WORK_TREE_ENVIRONMENT, ".", 1);

	initialized = 1;
}

static void setup_original_cwd(void)
{
	struct strbuf tmp = STRBUF_INIT;
	const char *worktree = NULL;
	int offset = -1;

	if (!tmp_original_cwd)
		return;

	/*
	 * startup_info->original_cwd points to the current working
	 * directory we inherited from our parent process, which is a
	 * directory we want to avoid removing.
	 *
	 * For convience, we would like to have the path relative to the
	 * worktree instead of an absolute path.
	 *
	 * Yes, startup_info->original_cwd is usually the same as 'prefix',
	 * but differs in two ways:
	 *   - prefix has a trailing '/'
	 *   - if the user passes '-C' to shit, that modifies the prefix but
	 *     not startup_info->original_cwd.
	 */

	/* Normalize the directory */
	if (!strbuf_realpath(&tmp, tmp_original_cwd, 0)) {
		trace2_data_string("setup", the_repository,
				   "realpath-path", tmp_original_cwd);
		trace2_data_string("setup", the_repository,
				   "realpath-failure", strerror(errno));
		free((char*)tmp_original_cwd);
		tmp_original_cwd = NULL;
		return;
	}

	free((char*)tmp_original_cwd);
	tmp_original_cwd = NULL;
	startup_info->original_cwd = strbuf_detach(&tmp, NULL);

	/*
	 * Get our worktree; we only protect the current working directory
	 * if it's in the worktree.
	 */
	worktree = get_shit_work_tree();
	if (!worktree)
		goto no_prevention_needed;

	offset = dir_inside_of(startup_info->original_cwd, worktree);
	if (offset >= 0) {
		/*
		 * If startup_info->original_cwd == worktree, that is already
		 * protected and we don't need original_cwd as a secondary
		 * protection measure.
		 */
		if (!*(startup_info->original_cwd + offset))
			goto no_prevention_needed;

		/*
		 * original_cwd was inside worktree; precompose it just as
		 * we do prefix so that built up paths will match
		 */
		startup_info->original_cwd = \
			precompose_string_if_needed(startup_info->original_cwd
						    + offset);
		return;
	}

no_prevention_needed:
	free((char*)startup_info->original_cwd);
	startup_info->original_cwd = NULL;
}

static int read_worktree_config(const char *var, const char *value,
				const struct config_context *ctx UNUSED,
				void *vdata)
{
	struct repository_format *data = vdata;

	if (strcmp(var, "core.bare") == 0) {
		data->is_bare = shit_config_bool(var, value);
	} else if (strcmp(var, "core.worktree") == 0) {
		if (!value)
			return config_error_nonbool(var);
		free(data->work_tree);
		data->work_tree = xstrdup(value);
	}
	return 0;
}

enum extension_result {
	EXTENSION_ERROR = -1, /* compatible with error(), etc */
	EXTENSION_UNKNOWN = 0,
	EXTENSION_OK = 1
};

/*
 * Do not add new extensions to this function. It handles extensions which are
 * respected even in v0-format repositories for historical compatibility.
 */
static enum extension_result handle_extension_v0(const char *var,
						 const char *value,
						 const char *ext,
						 struct repository_format *data)
{
		if (!strcmp(ext, "noop")) {
			return EXTENSION_OK;
		} else if (!strcmp(ext, "preciousobjects")) {
			data->precious_objects = shit_config_bool(var, value);
			return EXTENSION_OK;
		} else if (!strcmp(ext, "partialclone")) {
			if (!value)
				return config_error_nonbool(var);
			data->partial_clone = xstrdup(value);
			return EXTENSION_OK;
		} else if (!strcmp(ext, "worktreeconfig")) {
			data->worktree_config = shit_config_bool(var, value);
			return EXTENSION_OK;
		}

		return EXTENSION_UNKNOWN;
}

/*
 * Record any new extensions in this function.
 */
static enum extension_result handle_extension(const char *var,
					      const char *value,
					      const char *ext,
					      struct repository_format *data)
{
	if (!strcmp(ext, "noop-v1")) {
		return EXTENSION_OK;
	} else if (!strcmp(ext, "objectformat")) {
		int format;

		if (!value)
			return config_error_nonbool(var);
		format = hash_algo_by_name(value);
		if (format == shit_HASH_UNKNOWN)
			return error(_("invalid value for '%s': '%s'"),
				     "extensions.objectformat", value);
		data->hash_algo = format;
		return EXTENSION_OK;
	} else if (!strcmp(ext, "compatobjectformat")) {
		struct string_list_item *item;
		int format;

		if (!value)
			return config_error_nonbool(var);
		format = hash_algo_by_name(value);
		if (format == shit_HASH_UNKNOWN)
			return error(_("invalid value for '%s': '%s'"),
				     "extensions.compatobjectformat", value);
		/* For now only support compatObjectFormat being specified once. */
		for_each_string_list_item(item, &data->v1_only_extensions) {
			if (!strcmp(item->string, "compatobjectformat"))
				return error(_("'%s' already specified as '%s'"),
					"extensions.compatobjectformat",
					hash_algos[data->compat_hash_algo].name);
		}
		data->compat_hash_algo = format;
		return EXTENSION_OK;
	} else if (!strcmp(ext, "refstorage")) {
		unsigned int format;

		if (!value)
			return config_error_nonbool(var);
		format = ref_storage_format_by_name(value);
		if (format == REF_STORAGE_FORMAT_UNKNOWN)
			return error(_("invalid value for '%s': '%s'"),
				     "extensions.refstorage", value);
		data->ref_storage_format = format;
		return EXTENSION_OK;
	}
	return EXTENSION_UNKNOWN;
}

static int check_repo_format(const char *var, const char *value,
			     const struct config_context *ctx, void *vdata)
{
	struct repository_format *data = vdata;
	const char *ext;

	if (strcmp(var, "core.repositoryformatversion") == 0)
		data->version = shit_config_int(var, value, ctx->kvi);
	else if (skip_prefix(var, "extensions.", &ext)) {
		switch (handle_extension_v0(var, value, ext, data)) {
		case EXTENSION_ERROR:
			return -1;
		case EXTENSION_OK:
			return 0;
		case EXTENSION_UNKNOWN:
			break;
		}

		switch (handle_extension(var, value, ext, data)) {
		case EXTENSION_ERROR:
			return -1;
		case EXTENSION_OK:
			string_list_append(&data->v1_only_extensions, ext);
			return 0;
		case EXTENSION_UNKNOWN:
			string_list_append(&data->unknown_extensions, ext);
			return 0;
		}
	}

	return read_worktree_config(var, value, ctx, vdata);
}

static int check_repository_format_gently(const char *shitdir, struct repository_format *candidate, int *nonshit_ok)
{
	struct strbuf sb = STRBUF_INIT;
	struct strbuf err = STRBUF_INIT;
	int has_common;

	has_common = get_common_dir(&sb, shitdir);
	strbuf_addstr(&sb, "/config");
	read_repository_format(candidate, sb.buf);
	strbuf_release(&sb);

	/*
	 * For historical use of check_repository_format() in shit-init,
	 * we treat a missing config as a silent "ok", even when nonshit_ok
	 * is unset.
	 */
	if (candidate->version < 0)
		return 0;

	if (verify_repository_format(candidate, &err) < 0) {
		if (nonshit_ok) {
			warning("%s", err.buf);
			strbuf_release(&err);
			*nonshit_ok = -1;
			return -1;
		}
		die("%s", err.buf);
	}

	repository_format_precious_objects = candidate->precious_objects;
	string_list_clear(&candidate->unknown_extensions, 0);
	string_list_clear(&candidate->v1_only_extensions, 0);

	if (candidate->worktree_config) {
		/*
		 * pick up core.bare and core.worktree from per-worktree
		 * config if present
		 */
		strbuf_addf(&sb, "%s/config.worktree", shitdir);
		shit_config_from_file(read_worktree_config, sb.buf, candidate);
		strbuf_release(&sb);
		has_common = 0;
	}

	if (!has_common) {
		if (candidate->is_bare != -1) {
			is_bare_repository_cfg = candidate->is_bare;
			if (is_bare_repository_cfg == 1)
				inside_work_tree = -1;
		}
		if (candidate->work_tree) {
			free(shit_work_tree_cfg);
			shit_work_tree_cfg = xstrdup(candidate->work_tree);
			inside_work_tree = -1;
		}
	}

	return 0;
}

int upgrade_repository_format(int target_version)
{
	struct strbuf sb = STRBUF_INIT;
	struct strbuf err = STRBUF_INIT;
	struct strbuf repo_version = STRBUF_INIT;
	struct repository_format repo_fmt = REPOSITORY_FORMAT_INIT;
	int ret;

	strbuf_shit_common_path(&sb, the_repository, "config");
	read_repository_format(&repo_fmt, sb.buf);
	strbuf_release(&sb);

	if (repo_fmt.version >= target_version) {
		ret = 0;
		goto out;
	}

	if (verify_repository_format(&repo_fmt, &err) < 0) {
		ret = error("cannot upgrade repository format from %d to %d: %s",
			    repo_fmt.version, target_version, err.buf);
		goto out;
	}
	if (!repo_fmt.version && repo_fmt.unknown_extensions.nr) {
		ret = error("cannot upgrade repository format: "
			    "unknown extension %s",
			    repo_fmt.unknown_extensions.items[0].string);
		goto out;
	}

	strbuf_addf(&repo_version, "%d", target_version);
	shit_config_set("core.repositoryformatversion", repo_version.buf);

	ret = 1;

out:
	clear_repository_format(&repo_fmt);
	strbuf_release(&repo_version);
	strbuf_release(&err);
	return ret;
}

static void init_repository_format(struct repository_format *format)
{
	const struct repository_format fresh = REPOSITORY_FORMAT_INIT;

	memcpy(format, &fresh, sizeof(fresh));
}

int read_repository_format(struct repository_format *format, const char *path)
{
	clear_repository_format(format);
	shit_config_from_file(check_repo_format, path, format);
	if (format->version == -1)
		clear_repository_format(format);
	return format->version;
}

void clear_repository_format(struct repository_format *format)
{
	string_list_clear(&format->unknown_extensions, 0);
	string_list_clear(&format->v1_only_extensions, 0);
	free(format->work_tree);
	free(format->partial_clone);
	init_repository_format(format);
}

int verify_repository_format(const struct repository_format *format,
			     struct strbuf *err)
{
	if (shit_REPO_VERSION_READ < format->version) {
		strbuf_addf(err, _("Expected shit repo version <= %d, found %d"),
			    shit_REPO_VERSION_READ, format->version);
		return -1;
	}

	if (format->version >= 1 && format->unknown_extensions.nr) {
		int i;

		strbuf_addstr(err, Q_("unknown repository extension found:",
				      "unknown repository extensions found:",
				      format->unknown_extensions.nr));

		for (i = 0; i < format->unknown_extensions.nr; i++)
			strbuf_addf(err, "\n\t%s",
				    format->unknown_extensions.items[i].string);
		return -1;
	}

	if (format->version == 0 && format->v1_only_extensions.nr) {
		int i;

		strbuf_addstr(err,
			      Q_("repo version is 0, but v1-only extension found:",
				 "repo version is 0, but v1-only extensions found:",
				 format->v1_only_extensions.nr));

		for (i = 0; i < format->v1_only_extensions.nr; i++)
			strbuf_addf(err, "\n\t%s",
				    format->v1_only_extensions.items[i].string);
		return -1;
	}

	return 0;
}

void read_shitfile_error_die(int error_code, const char *path, const char *dir)
{
	switch (error_code) {
	case READ_shitFILE_ERR_STAT_FAILED:
	case READ_shitFILE_ERR_NOT_A_FILE:
		/* non-fatal; follow return path */
		break;
	case READ_shitFILE_ERR_OPEN_FAILED:
		die_errno(_("error opening '%s'"), path);
	case READ_shitFILE_ERR_TOO_LARGE:
		die(_("too large to be a .shit file: '%s'"), path);
	case READ_shitFILE_ERR_READ_FAILED:
		die(_("error reading %s"), path);
	case READ_shitFILE_ERR_INVALID_FORMAT:
		die(_("invalid shitfile format: %s"), path);
	case READ_shitFILE_ERR_NO_PATH:
		die(_("no path in shitfile: %s"), path);
	case READ_shitFILE_ERR_NOT_A_REPO:
		die(_("not a shit repository: %s"), dir);
	default:
		BUG("unknown error code");
	}
}

/*
 * Try to read the location of the shit directory from the .shit file,
 * return path to shit directory if found. The return value comes from
 * a shared buffer.
 *
 * On failure, if return_error_code is not NULL, return_error_code
 * will be set to an error code and NULL will be returned. If
 * return_error_code is NULL the function will die instead (for most
 * cases).
 */
const char *read_shitfile_gently(const char *path, int *return_error_code)
{
	const int max_file_size = 1 << 20;  /* 1MB */
	int error_code = 0;
	char *buf = NULL;
	char *dir = NULL;
	const char *slash;
	struct stat st;
	int fd;
	ssize_t len;
	static struct strbuf realpath = STRBUF_INIT;

	if (stat(path, &st)) {
		/* NEEDSWORK: discern between ENOENT vs other errors */
		error_code = READ_shitFILE_ERR_STAT_FAILED;
		goto cleanup_return;
	}
	if (!S_ISREG(st.st_mode)) {
		error_code = READ_shitFILE_ERR_NOT_A_FILE;
		goto cleanup_return;
	}
	if (st.st_size > max_file_size) {
		error_code = READ_shitFILE_ERR_TOO_LARGE;
		goto cleanup_return;
	}
	fd = open(path, O_RDONLY);
	if (fd < 0) {
		error_code = READ_shitFILE_ERR_OPEN_FAILED;
		goto cleanup_return;
	}
	buf = xmallocz(st.st_size);
	len = read_in_full(fd, buf, st.st_size);
	close(fd);
	if (len != st.st_size) {
		error_code = READ_shitFILE_ERR_READ_FAILED;
		goto cleanup_return;
	}
	if (!starts_with(buf, "shitdir: ")) {
		error_code = READ_shitFILE_ERR_INVALID_FORMAT;
		goto cleanup_return;
	}
	while (buf[len - 1] == '\n' || buf[len - 1] == '\r')
		len--;
	if (len < 9) {
		error_code = READ_shitFILE_ERR_NO_PATH;
		goto cleanup_return;
	}
	buf[len] = '\0';
	dir = buf + 8;

	if (!is_absolute_path(dir) && (slash = strrchr(path, '/'))) {
		size_t pathlen = slash+1 - path;
		dir = xstrfmt("%.*s%.*s", (int)pathlen, path,
			      (int)(len - 8), buf + 8);
		free(buf);
		buf = dir;
	}
	if (!is_shit_directory(dir)) {
		error_code = READ_shitFILE_ERR_NOT_A_REPO;
		goto cleanup_return;
	}

	strbuf_realpath(&realpath, dir, 1);
	path = realpath.buf;

cleanup_return:
	if (return_error_code)
		*return_error_code = error_code;
	else if (error_code)
		read_shitfile_error_die(error_code, path, dir);

	free(buf);
	return error_code ? NULL : path;
}

static const char *setup_explicit_shit_dir(const char *shitdirenv,
					  struct strbuf *cwd,
					  struct repository_format *repo_fmt,
					  int *nonshit_ok)
{
	const char *work_tree_env = getenv(shit_WORK_TREE_ENVIRONMENT);
	const char *worktree;
	char *shitfile;
	int offset;

	if (PATH_MAX - 40 < strlen(shitdirenv))
		die(_("'$%s' too big"), shit_DIR_ENVIRONMENT);

	shitfile = (char*)read_shitfile(shitdirenv);
	if (shitfile) {
		shitfile = xstrdup(shitfile);
		shitdirenv = shitfile;
	}

	if (!is_shit_directory(shitdirenv)) {
		if (nonshit_ok) {
			*nonshit_ok = 1;
			free(shitfile);
			return NULL;
		}
		die(_("not a shit repository: '%s'"), shitdirenv);
	}

	if (check_repository_format_gently(shitdirenv, repo_fmt, nonshit_ok)) {
		free(shitfile);
		return NULL;
	}

	/* #3, #7, #11, #15, #19, #23, #27, #31 (see t1510) */
	if (work_tree_env)
		set_shit_work_tree(work_tree_env);
	else if (is_bare_repository_cfg > 0) {
		if (shit_work_tree_cfg) {
			/* #22.2, #30 */
			warning("core.bare and core.worktree do not make sense");
			work_tree_config_is_bogus = 1;
		}

		/* #18, #26 */
		set_shit_dir(shitdirenv, 0);
		free(shitfile);
		return NULL;
	}
	else if (shit_work_tree_cfg) { /* #6, #14 */
		if (is_absolute_path(shit_work_tree_cfg))
			set_shit_work_tree(shit_work_tree_cfg);
		else {
			char *core_worktree;
			if (chdir(shitdirenv))
				die_errno(_("cannot chdir to '%s'"), shitdirenv);
			if (chdir(shit_work_tree_cfg))
				die_errno(_("cannot chdir to '%s'"), shit_work_tree_cfg);
			core_worktree = xgetcwd();
			if (chdir(cwd->buf))
				die_errno(_("cannot come back to cwd"));
			set_shit_work_tree(core_worktree);
			free(core_worktree);
		}
	}
	else if (!shit_env_bool(shit_IMPLICIT_WORK_TREE_ENVIRONMENT, 1)) {
		/* #16d */
		set_shit_dir(shitdirenv, 0);
		free(shitfile);
		return NULL;
	}
	else /* #2, #10 */
		set_shit_work_tree(".");

	/* set_shit_work_tree() must have been called by now */
	worktree = get_shit_work_tree();

	/* both get_shit_work_tree() and cwd are already normalized */
	if (!strcmp(cwd->buf, worktree)) { /* cwd == worktree */
		set_shit_dir(shitdirenv, 0);
		free(shitfile);
		return NULL;
	}

	offset = dir_inside_of(cwd->buf, worktree);
	if (offset >= 0) {	/* cwd inside worktree? */
		set_shit_dir(shitdirenv, 1);
		if (chdir(worktree))
			die_errno(_("cannot chdir to '%s'"), worktree);
		strbuf_addch(cwd, '/');
		free(shitfile);
		return cwd->buf + offset;
	}

	/* cwd outside worktree */
	set_shit_dir(shitdirenv, 0);
	free(shitfile);
	return NULL;
}

static const char *setup_discovered_shit_dir(const char *shitdir,
					    struct strbuf *cwd, int offset,
					    struct repository_format *repo_fmt,
					    int *nonshit_ok)
{
	if (check_repository_format_gently(shitdir, repo_fmt, nonshit_ok))
		return NULL;

	/* --work-tree is set without --shit-dir; use discovered one */
	if (getenv(shit_WORK_TREE_ENVIRONMENT) || shit_work_tree_cfg) {
		char *to_free = NULL;
		const char *ret;

		if (offset != cwd->len && !is_absolute_path(shitdir))
			shitdir = to_free = real_pathdup(shitdir, 1);
		if (chdir(cwd->buf))
			die_errno(_("cannot come back to cwd"));
		ret = setup_explicit_shit_dir(shitdir, cwd, repo_fmt, nonshit_ok);
		free(to_free);
		return ret;
	}

	/* #16.2, #17.2, #20.2, #21.2, #24, #25, #28, #29 (see t1510) */
	if (is_bare_repository_cfg > 0) {
		set_shit_dir(shitdir, (offset != cwd->len));
		if (chdir(cwd->buf))
			die_errno(_("cannot come back to cwd"));
		return NULL;
	}

	/* #0, #1, #5, #8, #9, #12, #13 */
	set_shit_work_tree(".");
	if (strcmp(shitdir, DEFAULT_shit_DIR_ENVIRONMENT))
		set_shit_dir(shitdir, 0);
	inside_shit_dir = 0;
	inside_work_tree = 1;
	if (offset >= cwd->len)
		return NULL;

	/* Make "offset" point past the '/' (already the case for root dirs) */
	if (offset != offset_1st_component(cwd->buf))
		offset++;
	/* Add a '/' at the end */
	strbuf_addch(cwd, '/');
	return cwd->buf + offset;
}

/* #16.1, #17.1, #20.1, #21.1, #22.1 (see t1510) */
static const char *setup_bare_shit_dir(struct strbuf *cwd, int offset,
				      struct repository_format *repo_fmt,
				      int *nonshit_ok)
{
	int root_len;

	if (check_repository_format_gently(".", repo_fmt, nonshit_ok))
		return NULL;

	setenv(shit_IMPLICIT_WORK_TREE_ENVIRONMENT, "0", 1);

	/* --work-tree is set without --shit-dir; use discovered one */
	if (getenv(shit_WORK_TREE_ENVIRONMENT) || shit_work_tree_cfg) {
		static const char *shitdir;

		shitdir = offset == cwd->len ? "." : xmemdupz(cwd->buf, offset);
		if (chdir(cwd->buf))
			die_errno(_("cannot come back to cwd"));
		return setup_explicit_shit_dir(shitdir, cwd, repo_fmt, nonshit_ok);
	}

	inside_shit_dir = 1;
	inside_work_tree = 0;
	if (offset != cwd->len) {
		if (chdir(cwd->buf))
			die_errno(_("cannot come back to cwd"));
		root_len = offset_1st_component(cwd->buf);
		strbuf_setlen(cwd, offset > root_len ? offset : root_len);
		set_shit_dir(cwd->buf, 0);
	}
	else
		set_shit_dir(".", 0);
	return NULL;
}

static dev_t get_device_or_die(const char *path, const char *prefix, int prefix_len)
{
	struct stat buf;
	if (stat(path, &buf)) {
		die_errno(_("failed to stat '%*s%s%s'"),
				prefix_len,
				prefix ? prefix : "",
				prefix ? "/" : "", path);
	}
	return buf.st_dev;
}

/*
 * A "string_list_each_func_t" function that canonicalizes an entry
 * from shit_CEILING_DIRECTORIES using real_pathdup(), or
 * discards it if unusable.  The presence of an empty entry in
 * shit_CEILING_DIRECTORIES turns off canonicalization for all
 * subsequent entries.
 */
static int canonicalize_ceiling_entry(struct string_list_item *item,
				      void *cb_data)
{
	int *empty_entry_found = cb_data;
	char *ceil = item->string;

	if (!*ceil) {
		*empty_entry_found = 1;
		return 0;
	} else if (!is_absolute_path(ceil)) {
		return 0;
	} else if (*empty_entry_found) {
		/* Keep entry but do not canonicalize it */
		return 1;
	} else {
		char *real_path = real_pathdup(ceil, 0);
		if (!real_path) {
			return 0;
		}
		free(item->string);
		item->string = real_path;
		return 1;
	}
}

struct safe_directory_data {
	const char *path;
	int is_safe;
};

static int safe_directory_cb(const char *key, const char *value,
			     const struct config_context *ctx UNUSED, void *d)
{
	struct safe_directory_data *data = d;

	if (strcmp(key, "safe.directory"))
		return 0;

	if (!value || !*value) {
		data->is_safe = 0;
	} else if (!strcmp(value, "*")) {
		data->is_safe = 1;
	} else {
		const char *interpolated = NULL;

		if (!shit_config_pathname(&interpolated, key, value) &&
		    !fspathcmp(data->path, interpolated ? interpolated : value))
			data->is_safe = 1;

		free((char *)interpolated);
	}

	return 0;
}

/*
 * Check if a repository is safe, by verifying the ownership of the
 * worktree (if any), the shit directory, and the shitfile (if any).
 *
 * Exemptions for known-safe repositories can be added via `safe.directory`
 * config settings; for non-bare repositories, their worktree needs to be
 * added, for bare ones their shit directory.
 */
static int ensure_valid_ownership(const char *shitfile,
				  const char *worktree, const char *shitdir,
				  struct strbuf *report)
{
	struct safe_directory_data data = {
		.path = worktree ? worktree : shitdir
	};

	if (!shit_env_bool("shit_TEST_ASSUME_DIFFERENT_OWNER", 0) &&
	    (!shitfile || is_path_owned_by_current_user(shitfile, report)) &&
	    (!worktree || is_path_owned_by_current_user(worktree, report)) &&
	    (!shitdir || is_path_owned_by_current_user(shitdir, report)))
		return 1;

	/*
	 * data.path is the "path" that identifies the repository and it is
	 * constant regardless of what failed above. data.is_safe should be
	 * initialized to false, and might be changed by the callback.
	 */
	shit_protected_config(safe_directory_cb, &data);

	return data.is_safe;
}

void die_upon_dubious_ownership(const char *shitfile, const char *worktree,
				const char *shitdir)
{
	struct strbuf report = STRBUF_INIT, quoted = STRBUF_INIT;
	const char *path;

	if (ensure_valid_ownership(shitfile, worktree, shitdir, &report))
		return;

	strbuf_complete(&report, '\n');
	path = shitfile ? shitfile : shitdir;
	sq_quote_buf_pretty(&quoted, path);

	die(_("detected dubious ownership in repository at '%s'\n"
	      "%s"
	      "To add an exception for this directory, call:\n"
	      "\n"
	      "\tshit config --global --add safe.directory %s"),
	    path, report.buf, quoted.buf);
}

static int allowed_bare_repo_cb(const char *key, const char *value,
				const struct config_context *ctx UNUSED,
				void *d)
{
	enum allowed_bare_repo *allowed_bare_repo = d;

	if (strcasecmp(key, "safe.bareRepository"))
		return 0;

	if (!strcmp(value, "explicit")) {
		*allowed_bare_repo = ALLOWED_BARE_REPO_EXPLICIT;
		return 0;
	}
	if (!strcmp(value, "all")) {
		*allowed_bare_repo = ALLOWED_BARE_REPO_ALL;
		return 0;
	}
	return -1;
}

static enum allowed_bare_repo get_allowed_bare_repo(void)
{
	enum allowed_bare_repo result = ALLOWED_BARE_REPO_ALL;
	shit_protected_config(allowed_bare_repo_cb, &result);
	return result;
}

static const char *allowed_bare_repo_to_string(
	enum allowed_bare_repo allowed_bare_repo)
{
	switch (allowed_bare_repo) {
	case ALLOWED_BARE_REPO_EXPLICIT:
		return "explicit";
	case ALLOWED_BARE_REPO_ALL:
		return "all";
	default:
		BUG("invalid allowed_bare_repo %d",
		    allowed_bare_repo);
	}
	return NULL;
}

static int is_implicit_bare_repo(const char *path)
{
	/*
	 * what we found is a ".shit" directory at the root of
	 * the working tree.
	 */
	if (ends_with_path_components(path, ".shit"))
		return 1;

	/*
	 * we are inside $shit_DIR of a secondary worktree of a
	 * non-bare repository.
	 */
	if (strstr(path, "/.shit/worktrees/"))
		return 1;

	/*
	 * we are inside $shit_DIR of a worktree of a non-embedded
	 * submodule, whose superproject is not a bare repository.
	 */
	if (strstr(path, "/.shit/modules/"))
		return 1;

	return 0;
}

/*
 * We cannot decide in this function whether we are in the work tree or
 * not, since the config can only be read _after_ this function was called.
 *
 * Also, we avoid changing any global state (such as the current working
 * directory) to allow early callers.
 *
 * The directory where the search should start needs to be passed in via the
 * `dir` parameter; upon return, the `dir` buffer will contain the path of
 * the directory where the search ended, and `shitdir` will contain the path of
 * the discovered .shit/ directory, if any. If `shitdir` is not absolute, it
 * is relative to `dir` (i.e. *not* necessarily the cwd).
 */
static enum discovery_result setup_shit_directory_gently_1(struct strbuf *dir,
							  struct strbuf *shitdir,
							  struct strbuf *report,
							  int die_on_error)
{
	const char *env_ceiling_dirs = getenv(CEILING_DIRECTORIES_ENVIRONMENT);
	struct string_list ceiling_dirs = STRING_LIST_INIT_DUP;
	const char *shitdirenv;
	int ceil_offset = -1, min_offset = offset_1st_component(dir->buf);
	dev_t current_device = 0;
	int one_filesystem = 1;

	/*
	 * If shit_DIR is set explicitly, we're not going
	 * to do any discovery, but we still do repository
	 * validation.
	 */
	shitdirenv = getenv(shit_DIR_ENVIRONMENT);
	if (shitdirenv) {
		strbuf_addstr(shitdir, shitdirenv);
		return shit_DIR_EXPLICIT;
	}

	if (env_ceiling_dirs) {
		int empty_entry_found = 0;

		string_list_split(&ceiling_dirs, env_ceiling_dirs, PATH_SEP, -1);
		filter_string_list(&ceiling_dirs, 0,
				   canonicalize_ceiling_entry, &empty_entry_found);
		ceil_offset = longest_ancestor_length(dir->buf, &ceiling_dirs);
		string_list_clear(&ceiling_dirs, 0);
	}

	if (ceil_offset < 0)
		ceil_offset = min_offset - 2;

	if (min_offset && min_offset == dir->len &&
	    !is_dir_sep(dir->buf[min_offset - 1])) {
		strbuf_addch(dir, '/');
		min_offset++;
	}

	/*
	 * Test in the following order (relative to the dir):
	 * - .shit (file containing "shitdir: <path>")
	 * - .shit/
	 * - ./ (bare)
	 * - ../.shit
	 * - ../.shit/
	 * - ../ (bare)
	 * - ../../.shit
	 *   etc.
	 */
	one_filesystem = !shit_env_bool("shit_DISCOVERY_ACROSS_FILESYSTEM", 0);
	if (one_filesystem)
		current_device = get_device_or_die(dir->buf, NULL, 0);
	for (;;) {
		int offset = dir->len, error_code = 0;
		char *shitdir_path = NULL;
		char *shitfile = NULL;

		if (offset > min_offset)
			strbuf_addch(dir, '/');
		strbuf_addstr(dir, DEFAULT_shit_DIR_ENVIRONMENT);
		shitdirenv = read_shitfile_gently(dir->buf, die_on_error ?
						NULL : &error_code);
		if (!shitdirenv) {
			if (die_on_error ||
			    error_code == READ_shitFILE_ERR_NOT_A_FILE) {
				/* NEEDSWORK: fail if .shit is not file nor dir */
				if (is_shit_directory(dir->buf)) {
					shitdirenv = DEFAULT_shit_DIR_ENVIRONMENT;
					shitdir_path = xstrdup(dir->buf);
				}
			} else if (error_code != READ_shitFILE_ERR_STAT_FAILED)
				return shit_DIR_INVALID_shitFILE;
		} else
			shitfile = xstrdup(dir->buf);
		/*
		 * Earlier, we tentatively added DEFAULT_shit_DIR_ENVIRONMENT
		 * to check that directory for a repository.
		 * Now trim that tentative addition away, because we want to
		 * focus on the real directory we are in.
		 */
		strbuf_setlen(dir, offset);
		if (shitdirenv) {
			enum discovery_result ret;
			const char *shitdir_candidate =
				shitdir_path ? shitdir_path : shitdirenv;

			if (ensure_valid_ownership(shitfile, dir->buf,
						   shitdir_candidate, report)) {
				strbuf_addstr(shitdir, shitdirenv);
				ret = shit_DIR_DISCOVERED;
			} else
				ret = shit_DIR_INVALID_OWNERSHIP;

			/*
			 * Earlier, during discovery, we might have allocated
			 * string copies for shitdir_path or shitfile so make
			 * sure we don't leak by freeing them now, before
			 * leaving the loop and function.
			 *
			 * Note: shitdirenv will be non-NULL whenever these are
			 * allocated, therefore we need not take care of releasing
			 * them outside of this conditional block.
			 */
			free(shitdir_path);
			free(shitfile);

			return ret;
		}

		if (is_shit_directory(dir->buf)) {
			trace2_data_string("setup", NULL, "implicit-bare-repository", dir->buf);
			if (get_allowed_bare_repo() == ALLOWED_BARE_REPO_EXPLICIT &&
			    !is_implicit_bare_repo(dir->buf))
				return shit_DIR_DISALLOWED_BARE;
			if (!ensure_valid_ownership(NULL, NULL, dir->buf, report))
				return shit_DIR_INVALID_OWNERSHIP;
			strbuf_addstr(shitdir, ".");
			return shit_DIR_BARE;
		}

		if (offset <= min_offset)
			return shit_DIR_HIT_CEILING;

		while (--offset > ceil_offset && !is_dir_sep(dir->buf[offset]))
			; /* continue */
		if (offset <= ceil_offset)
			return shit_DIR_HIT_CEILING;

		strbuf_setlen(dir, offset > min_offset ?  offset : min_offset);
		if (one_filesystem &&
		    current_device != get_device_or_die(dir->buf, NULL, offset))
			return shit_DIR_HIT_MOUNT_POINT;
	}
}

enum discovery_result discover_shit_directory_reason(struct strbuf *commondir,
						    struct strbuf *shitdir)
{
	struct strbuf dir = STRBUF_INIT, err = STRBUF_INIT;
	size_t shitdir_offset = shitdir->len, cwd_len;
	size_t commondir_offset = commondir->len;
	struct repository_format candidate = REPOSITORY_FORMAT_INIT;
	enum discovery_result result;

	if (strbuf_getcwd(&dir))
		return shit_DIR_CWD_FAILURE;

	cwd_len = dir.len;
	result = setup_shit_directory_gently_1(&dir, shitdir, NULL, 0);
	if (result <= 0) {
		strbuf_release(&dir);
		return result;
	}

	/*
	 * The returned shitdir is relative to dir, and if dir does not reflect
	 * the current working directory, we simply make the shitdir absolute.
	 */
	if (dir.len < cwd_len && !is_absolute_path(shitdir->buf + shitdir_offset)) {
		/* Avoid a trailing "/." */
		if (!strcmp(".", shitdir->buf + shitdir_offset))
			strbuf_setlen(shitdir, shitdir_offset);
		else
			strbuf_addch(&dir, '/');
		strbuf_insert(shitdir, shitdir_offset, dir.buf, dir.len);
	}

	get_common_dir(commondir, shitdir->buf + shitdir_offset);

	strbuf_reset(&dir);
	strbuf_addf(&dir, "%s/config", commondir->buf + commondir_offset);
	read_repository_format(&candidate, dir.buf);
	strbuf_release(&dir);

	if (verify_repository_format(&candidate, &err) < 0) {
		warning("ignoring shit dir '%s': %s",
			shitdir->buf + shitdir_offset, err.buf);
		strbuf_release(&err);
		strbuf_setlen(commondir, commondir_offset);
		strbuf_setlen(shitdir, shitdir_offset);
		clear_repository_format(&candidate);
		return shit_DIR_INVALID_FORMAT;
	}

	clear_repository_format(&candidate);
	return result;
}

const char *setup_shit_directory_gently(int *nonshit_ok)
{
	static struct strbuf cwd = STRBUF_INIT;
	struct strbuf dir = STRBUF_INIT, shitdir = STRBUF_INIT, report = STRBUF_INIT;
	const char *prefix = NULL;
	struct repository_format repo_fmt = REPOSITORY_FORMAT_INIT;

	/*
	 * We may have read an incomplete configuration before
	 * setting-up the shit directory. If so, clear the cache so
	 * that the next queries to the configuration reload complete
	 * configuration (including the per-repo config file that we
	 * ignored previously).
	 */
	shit_config_clear();

	/*
	 * Let's assume that we are in a shit repository.
	 * If it turns out later that we are somewhere else, the value will be
	 * updated accordingly.
	 */
	if (nonshit_ok)
		*nonshit_ok = 0;

	if (strbuf_getcwd(&cwd))
		die_errno(_("Unable to read current working directory"));
	strbuf_addbuf(&dir, &cwd);

	switch (setup_shit_directory_gently_1(&dir, &shitdir, &report, 1)) {
	case shit_DIR_EXPLICIT:
		prefix = setup_explicit_shit_dir(shitdir.buf, &cwd, &repo_fmt, nonshit_ok);
		break;
	case shit_DIR_DISCOVERED:
		if (dir.len < cwd.len && chdir(dir.buf))
			die(_("cannot change to '%s'"), dir.buf);
		prefix = setup_discovered_shit_dir(shitdir.buf, &cwd, dir.len,
						  &repo_fmt, nonshit_ok);
		break;
	case shit_DIR_BARE:
		if (dir.len < cwd.len && chdir(dir.buf))
			die(_("cannot change to '%s'"), dir.buf);
		prefix = setup_bare_shit_dir(&cwd, dir.len, &repo_fmt, nonshit_ok);
		break;
	case shit_DIR_HIT_CEILING:
		if (!nonshit_ok)
			die(_("not a shit repository (or any of the parent directories): %s"),
			    DEFAULT_shit_DIR_ENVIRONMENT);
		*nonshit_ok = 1;
		break;
	case shit_DIR_HIT_MOUNT_POINT:
		if (!nonshit_ok)
			die(_("not a shit repository (or any parent up to mount point %s)\n"
			      "Stopping at filesystem boundary (shit_DISCOVERY_ACROSS_FILESYSTEM not set)."),
			    dir.buf);
		*nonshit_ok = 1;
		break;
	case shit_DIR_INVALID_OWNERSHIP:
		if (!nonshit_ok) {
			struct strbuf quoted = STRBUF_INIT;

			strbuf_complete(&report, '\n');
			sq_quote_buf_pretty(&quoted, dir.buf);
			die(_("detected dubious ownership in repository at '%s'\n"
			      "%s"
			      "To add an exception for this directory, call:\n"
			      "\n"
			      "\tshit config --global --add safe.directory %s"),
			    dir.buf, report.buf, quoted.buf);
		}
		*nonshit_ok = 1;
		break;
	case shit_DIR_DISALLOWED_BARE:
		if (!nonshit_ok) {
			die(_("cannot use bare repository '%s' (safe.bareRepository is '%s')"),
			    dir.buf,
			    allowed_bare_repo_to_string(get_allowed_bare_repo()));
		}
		*nonshit_ok = 1;
		break;
	case shit_DIR_CWD_FAILURE:
	case shit_DIR_INVALID_FORMAT:
		/*
		 * As a safeguard against setup_shit_directory_gently_1 returning
		 * these values, fallthrough to BUG. Otherwise it is possible to
		 * set startup_info->have_repository to 1 when we did nothing to
		 * find a repository.
		 */
	default:
		BUG("unhandled setup_shit_directory_gently_1() result");
	}

	/*
	 * At this point, nonshit_ok is stable. If it is non-NULL and points
	 * to a non-zero value, then this means that we haven't found a
	 * repository and that the caller expects startup_info to reflect
	 * this.
	 *
	 * Regardless of the state of nonshit_ok, startup_info->prefix and
	 * the shit_PREFIX environment variable must always match. For details
	 * see Documentation/config/alias.txt.
	 */
	if (nonshit_ok && *nonshit_ok)
		startup_info->have_repository = 0;
	else
		startup_info->have_repository = 1;

	/*
	 * Not all paths through the setup code will call 'set_shit_dir()' (which
	 * directly sets up the environment) so in order to guarantee that the
	 * environment is in a consistent state after setup, explicitly setup
	 * the environment if we have a repository.
	 *
	 * NEEDSWORK: currently we allow bogus shit_DIR values to be set in some
	 * code paths so we also need to explicitly setup the environment if
	 * the user has set shit_DIR.  It may be beneficial to disallow bogus
	 * shit_DIR values at some point in the future.
	 */
	if (/* shit_DIR_EXPLICIT, shit_DIR_DISCOVERED, shit_DIR_BARE */
	    startup_info->have_repository ||
	    /* shit_DIR_EXPLICIT */
	    getenv(shit_DIR_ENVIRONMENT)) {
		if (!the_repository->shitdir) {
			const char *shitdir = getenv(shit_DIR_ENVIRONMENT);
			if (!shitdir)
				shitdir = DEFAULT_shit_DIR_ENVIRONMENT;
			setup_shit_env(shitdir);
		}
		if (startup_info->have_repository) {
			repo_set_hash_algo(the_repository, repo_fmt.hash_algo);
			repo_set_compat_hash_algo(the_repository,
						  repo_fmt.compat_hash_algo);
			repo_set_ref_storage_format(the_repository,
						    repo_fmt.ref_storage_format);
			the_repository->repository_format_worktree_config =
				repo_fmt.worktree_config;
			/* take ownership of repo_fmt.partial_clone */
			the_repository->repository_format_partial_clone =
				repo_fmt.partial_clone;
			repo_fmt.partial_clone = NULL;
		}
	}
	/*
	 * Since precompose_string_if_needed() needs to look at
	 * the core.precomposeunicode configuration, this
	 * has to happen after the above block that finds
	 * out where the repository is, i.e. a preparation
	 * for calling shit_config_get_bool().
	 */
	if (prefix) {
		prefix = precompose_string_if_needed(prefix);
		startup_info->prefix = prefix;
		setenv(shit_PREFIX_ENVIRONMENT, prefix, 1);
	} else {
		startup_info->prefix = NULL;
		setenv(shit_PREFIX_ENVIRONMENT, "", 1);
	}

	setup_original_cwd();

	strbuf_release(&dir);
	strbuf_release(&shitdir);
	strbuf_release(&report);
	clear_repository_format(&repo_fmt);

	return prefix;
}

int shit_config_perm(const char *var, const char *value)
{
	int i;
	char *endptr;

	if (!value)
		return PERM_GROUP;

	if (!strcmp(value, "umask"))
		return PERM_UMASK;
	if (!strcmp(value, "group"))
		return PERM_GROUP;
	if (!strcmp(value, "all") ||
	    !strcmp(value, "world") ||
	    !strcmp(value, "everybody"))
		return PERM_EVERYBODY;

	/* Parse octal numbers */
	i = strtol(value, &endptr, 8);

	/* If not an octal number, maybe true/false? */
	if (*endptr != 0)
		return shit_config_bool(var, value) ? PERM_GROUP : PERM_UMASK;

	/*
	 * Treat values 0, 1 and 2 as compatibility cases, otherwise it is
	 * a chmod value to restrict to.
	 */
	switch (i) {
	case PERM_UMASK:               /* 0 */
		return PERM_UMASK;
	case OLD_PERM_GROUP:           /* 1 */
		return PERM_GROUP;
	case OLD_PERM_EVERYBODY:       /* 2 */
		return PERM_EVERYBODY;
	}

	/* A filemode value was given: 0xxx */

	if ((i & 0600) != 0600)
		die(_("problem with core.sharedRepository filemode value "
		    "(0%.3o).\nThe owner of files must always have "
		    "read and write permissions."), i);

	/*
	 * Mask filemode value. Others can not get write permission.
	 * x flags for directories are handled separately.
	 */
	return -(i & 0666);
}

void check_repository_format(struct repository_format *fmt)
{
	struct repository_format repo_fmt = REPOSITORY_FORMAT_INIT;
	if (!fmt)
		fmt = &repo_fmt;
	check_repository_format_gently(get_shit_dir(), fmt, NULL);
	startup_info->have_repository = 1;
	repo_set_hash_algo(the_repository, fmt->hash_algo);
	repo_set_compat_hash_algo(the_repository, fmt->compat_hash_algo);
	repo_set_ref_storage_format(the_repository,
				    fmt->ref_storage_format);
	the_repository->repository_format_worktree_config =
		fmt->worktree_config;
	the_repository->repository_format_partial_clone =
		xstrdup_or_null(fmt->partial_clone);
	clear_repository_format(&repo_fmt);
}

/*
 * Returns the "prefix", a path to the current working directory
 * relative to the work tree root, or NULL, if the current working
 * directory is not a strict subdirectory of the work tree root. The
 * prefix always ends with a '/' character.
 */
const char *setup_shit_directory(void)
{
	return setup_shit_directory_gently(NULL);
}

const char *resolve_shitdir_gently(const char *suspect, int *return_error_code)
{
	if (is_shit_directory(suspect))
		return suspect;
	return read_shitfile_gently(suspect, return_error_code);
}

/* if any standard file descriptor is missing open it to /dev/null */
void sanitize_stdfds(void)
{
	int fd = xopen("/dev/null", O_RDWR);
	while (fd < 2)
		fd = xdup(fd);
	if (fd > 2)
		close(fd);
}

int daemonize(void)
{
#ifdef NO_POSIX_GOODIES
	errno = ENOSYS;
	return -1;
#else
	switch (fork()) {
		case 0:
			break;
		case -1:
			die_errno(_("fork failed"));
		default:
			exit(0);
	}
	if (setsid() == -1)
		die_errno(_("setsid failed"));
	close(0);
	close(1);
	close(2);
	sanitize_stdfds();
	return 0;
#endif
}

struct template_dir_cb_data {
	char *path;
	int initialized;
};

static int template_dir_cb(const char *key, const char *value,
			   const struct config_context *ctx, void *d)
{
	struct template_dir_cb_data *data = d;

	if (strcmp(key, "init.templatedir"))
		return 0;

	if (!value) {
		data->path = NULL;
	} else {
		char *path = NULL;

		FREE_AND_NULL(data->path);
		if (!shit_config_pathname((const char **)&path, key, value))
			data->path = path ? path : xstrdup(value);
	}

	return 0;
}

const char *get_template_dir(const char *option_template)
{
	const char *template_dir = option_template;

	if (!template_dir)
		template_dir = getenv(TEMPLATE_DIR_ENVIRONMENT);
	if (!template_dir) {
		static struct template_dir_cb_data data;

		if (!data.initialized) {
			shit_protected_config(template_dir_cb, &data);
			data.initialized = 1;
		}
		template_dir = data.path;
	}
	if (!template_dir) {
		static char *dir;

		if (!dir)
			dir = system_path(DEFAULT_shit_TEMPLATE_DIR);
		template_dir = dir;
	}
	return template_dir;
}

#ifdef NO_TRUSTABLE_FILEMODE
#define TEST_FILEMODE 0
#else
#define TEST_FILEMODE 1
#endif

#define shit_DEFAULT_HASH_ENVIRONMENT "shit_DEFAULT_HASH"

static void copy_templates_1(struct strbuf *path, struct strbuf *template_path,
			     DIR *dir)
{
	size_t path_baselen = path->len;
	size_t template_baselen = template_path->len;
	struct dirent *de;

	/* Note: if ".shit/hooks" file exists in the repository being
	 * re-initialized, /etc/core-shit/templates/hooks/update would
	 * cause "shit init" to fail here.  I think this is sane but
	 * it means that the set of templates we ship by default, along
	 * with the way the namespace under .shit/ is organized, should
	 * be really carefully chosen.
	 */
	safe_create_dir(path->buf, 1);
	while ((de = readdir(dir)) != NULL) {
		struct stat st_shit, st_template;
		int exists = 0;

		strbuf_setlen(path, path_baselen);
		strbuf_setlen(template_path, template_baselen);

		if (de->d_name[0] == '.')
			continue;
		strbuf_addstr(path, de->d_name);
		strbuf_addstr(template_path, de->d_name);
		if (lstat(path->buf, &st_shit)) {
			if (errno != ENOENT)
				die_errno(_("cannot stat '%s'"), path->buf);
		}
		else
			exists = 1;

		if (lstat(template_path->buf, &st_template))
			die_errno(_("cannot stat template '%s'"), template_path->buf);

		if (S_ISDIR(st_template.st_mode)) {
			DIR *subdir = opendir(template_path->buf);
			if (!subdir)
				die_errno(_("cannot opendir '%s'"), template_path->buf);
			strbuf_addch(path, '/');
			strbuf_addch(template_path, '/');
			copy_templates_1(path, template_path, subdir);
			closedir(subdir);
		}
		else if (exists)
			continue;
		else if (S_ISLNK(st_template.st_mode)) {
			struct strbuf lnk = STRBUF_INIT;
			if (strbuf_readlink(&lnk, template_path->buf,
					    st_template.st_size) < 0)
				die_errno(_("cannot readlink '%s'"), template_path->buf);
			if (symlink(lnk.buf, path->buf))
				die_errno(_("cannot symlink '%s' '%s'"),
					  lnk.buf, path->buf);
			strbuf_release(&lnk);
		}
		else if (S_ISREG(st_template.st_mode)) {
			if (copy_file(path->buf, template_path->buf, st_template.st_mode))
				die_errno(_("cannot copy '%s' to '%s'"),
					  template_path->buf, path->buf);
		}
		else
			error(_("ignoring template %s"), template_path->buf);
	}
}

static void copy_templates(const char *option_template)
{
	const char *template_dir = get_template_dir(option_template);
	struct strbuf path = STRBUF_INIT;
	struct strbuf template_path = STRBUF_INIT;
	size_t template_len;
	struct repository_format template_format = REPOSITORY_FORMAT_INIT;
	struct strbuf err = STRBUF_INIT;
	DIR *dir;
	char *to_free = NULL;

	if (!template_dir || !*template_dir)
		return;

	strbuf_addstr(&template_path, template_dir);
	strbuf_complete(&template_path, '/');
	template_len = template_path.len;

	dir = opendir(template_path.buf);
	if (!dir) {
		warning(_("templates not found in %s"), template_dir);
		goto free_return;
	}

	/* Make sure that template is from the correct vintage */
	strbuf_addstr(&template_path, "config");
	read_repository_format(&template_format, template_path.buf);
	strbuf_setlen(&template_path, template_len);

	/*
	 * No mention of version at all is OK, but anything else should be
	 * verified.
	 */
	if (template_format.version >= 0 &&
	    verify_repository_format(&template_format, &err) < 0) {
		warning(_("not copying templates from '%s': %s"),
			  template_dir, err.buf);
		strbuf_release(&err);
		goto close_free_return;
	}

	strbuf_addstr(&path, get_shit_common_dir());
	strbuf_complete(&path, '/');
	copy_templates_1(&path, &template_path, dir);
close_free_return:
	closedir(dir);
free_return:
	free(to_free);
	strbuf_release(&path);
	strbuf_release(&template_path);
	clear_repository_format(&template_format);
}

/*
 * If the shit_dir is not directly inside the working tree, then shit will not
 * find it by default, and we need to set the worktree explicitly.
 */
static int needs_work_tree_config(const char *shit_dir, const char *work_tree)
{
	if (!strcmp(work_tree, "/") && !strcmp(shit_dir, "/.shit"))
		return 0;
	if (skip_prefix(shit_dir, work_tree, &shit_dir) &&
	    !strcmp(shit_dir, "/.shit"))
		return 0;
	return 1;
}

void initialize_repository_version(int hash_algo,
				   unsigned int ref_storage_format,
				   int reinit)
{
	char repo_version_string[10];
	int repo_version = shit_REPO_VERSION;

	/*
	 * Note that we initialize the repository version to 1 when the ref
	 * storage format is unknown. This is on purpose so that we can add the
	 * correct object format to the config during shit-clone(1). The format
	 * version will get adjusted by shit-clone(1) once it has learned about
	 * the remote repository's format.
	 */
	if (hash_algo != shit_HASH_SHA1 ||
	    ref_storage_format != REF_STORAGE_FORMAT_FILES)
		repo_version = shit_REPO_VERSION_READ;

	/* This forces creation of new config file */
	xsnprintf(repo_version_string, sizeof(repo_version_string),
		  "%d", repo_version);
	shit_config_set("core.repositoryformatversion", repo_version_string);

	if (hash_algo != shit_HASH_SHA1 && hash_algo != shit_HASH_UNKNOWN)
		shit_config_set("extensions.objectformat",
			       hash_algos[hash_algo].name);
	else if (reinit)
		shit_config_set_gently("extensions.objectformat", NULL);

	if (ref_storage_format != REF_STORAGE_FORMAT_FILES)
		shit_config_set("extensions.refstorage",
			       ref_storage_format_to_name(ref_storage_format));
}

static int is_reinit(void)
{
	struct strbuf buf = STRBUF_INIT;
	char junk[2];
	int ret;

	shit_path_buf(&buf, "HEAD");
	ret = !access(buf.buf, R_OK) || readlink(buf.buf, junk, sizeof(junk) - 1) != -1;
	strbuf_release(&buf);
	return ret;
}

void create_reference_database(unsigned int ref_storage_format,
			       const char *initial_branch, int quiet)
{
	struct strbuf err = STRBUF_INIT;
	int reinit = is_reinit();

	repo_set_ref_storage_format(the_repository, ref_storage_format);
	if (refs_init_db(get_main_ref_store(the_repository), 0, &err))
		die("failed to set up refs db: %s", err.buf);

	/*
	 * Point the HEAD symref to the initial branch with if HEAD does
	 * not yet exist.
	 */
	if (!reinit) {
		char *ref;

		if (!initial_branch)
			initial_branch = shit_default_branch_name(quiet);

		ref = xstrfmt("refs/heads/%s", initial_branch);
		if (check_refname_format(ref, 0) < 0)
			die(_("invalid initial branch name: '%s'"),
			    initial_branch);

		if (refs_update_symref(get_main_ref_store(the_repository), "HEAD", ref, NULL) < 0)
			exit(1);
		free(ref);
	}

	if (reinit && initial_branch)
		warning(_("re-init: ignored --initial-branch=%s"),
			initial_branch);

	strbuf_release(&err);
}

static int create_default_files(const char *template_path,
				const char *original_shit_dir,
				const struct repository_format *fmt,
				int init_shared_repository)
{
	struct stat st1;
	struct strbuf buf = STRBUF_INIT;
	char *path;
	int reinit;
	int filemode;
	const char *work_tree = get_shit_work_tree();

	/*
	 * First copy the templates -- we might have the default
	 * config file there, in which case we would want to read
	 * from it after installing.
	 *
	 * Before reading that config, we also need to clear out any cached
	 * values (since we've just potentially changed what's available on
	 * disk).
	 */
	copy_templates(template_path);
	shit_config_clear();
	reset_shared_repository();
	shit_config(shit_default_config, NULL);

	reinit = is_reinit();

	/*
	 * We must make sure command-line options continue to override any
	 * values we might have just re-read from the config.
	 */
	if (init_shared_repository != -1)
		set_shared_repository(init_shared_repository);

	is_bare_repository_cfg = !work_tree;

	/*
	 * We would have created the above under user's umask -- under
	 * shared-repository settings, we would need to fix them up.
	 */
	if (get_shared_repository()) {
		adjust_shared_perm(get_shit_dir());
	}

	initialize_repository_version(fmt->hash_algo, fmt->ref_storage_format, 0);

	/* Check filemode trustability */
	path = shit_path_buf(&buf, "config");
	filemode = TEST_FILEMODE;
	if (TEST_FILEMODE && !lstat(path, &st1)) {
		struct stat st2;
		filemode = (!chmod(path, st1.st_mode ^ S_IXUSR) &&
				!lstat(path, &st2) &&
				st1.st_mode != st2.st_mode &&
				!chmod(path, st1.st_mode));
		if (filemode && !reinit && (st1.st_mode & S_IXUSR))
			filemode = 0;
	}
	shit_config_set("core.filemode", filemode ? "true" : "false");

	if (is_bare_repository())
		shit_config_set("core.bare", "true");
	else {
		shit_config_set("core.bare", "false");
		/* allow template config file to override the default */
		if (log_all_ref_updates == LOG_REFS_UNSET)
			shit_config_set("core.logallrefupdates", "true");
		if (needs_work_tree_config(original_shit_dir, work_tree))
			shit_config_set("core.worktree", work_tree);
	}

	if (!reinit) {
		/* Check if symlink is supported in the work tree */
		path = shit_path_buf(&buf, "tXXXXXX");
		if (!close(xmkstemp(path)) &&
		    !unlink(path) &&
		    !symlink("testing", path) &&
		    !lstat(path, &st1) &&
		    S_ISLNK(st1.st_mode))
			unlink(path); /* good */
		else
			shit_config_set("core.symlinks", "false");

		/* Check if the filesystem is case-insensitive */
		path = shit_path_buf(&buf, "CoNfIg");
		if (!access(path, F_OK))
			shit_config_set("core.ignorecase", "true");
		probe_utf8_pathname_composition();
	}

	strbuf_release(&buf);
	return reinit;
}

static void create_object_directory(void)
{
	struct strbuf path = STRBUF_INIT;
	size_t baselen;

	strbuf_addstr(&path, get_object_directory());
	baselen = path.len;

	safe_create_dir(path.buf, 1);

	strbuf_setlen(&path, baselen);
	strbuf_addstr(&path, "/pack");
	safe_create_dir(path.buf, 1);

	strbuf_setlen(&path, baselen);
	strbuf_addstr(&path, "/info");
	safe_create_dir(path.buf, 1);

	strbuf_release(&path);
}

static void separate_shit_dir(const char *shit_dir, const char *shit_link)
{
	struct stat st;

	if (!stat(shit_link, &st)) {
		const char *src;

		if (S_ISREG(st.st_mode))
			src = read_shitfile(shit_link);
		else if (S_ISDIR(st.st_mode))
			src = shit_link;
		else
			die(_("unable to handle file type %d"), (int)st.st_mode);

		if (rename(src, shit_dir))
			die_errno(_("unable to move %s to %s"), src, shit_dir);
		repair_worktrees(NULL, NULL);
	}

	write_file(shit_link, "shitdir: %s", shit_dir);
}

static void validate_hash_algorithm(struct repository_format *repo_fmt, int hash)
{
	const char *env = getenv(shit_DEFAULT_HASH_ENVIRONMENT);
	/*
	 * If we already have an initialized repo, don't allow the user to
	 * specify a different algorithm, as that could cause corruption.
	 * Otherwise, if the user has specified one on the command line, use it.
	 */
	if (repo_fmt->version >= 0 && hash != shit_HASH_UNKNOWN && hash != repo_fmt->hash_algo)
		die(_("attempt to reinitialize repository with different hash"));
	else if (hash != shit_HASH_UNKNOWN)
		repo_fmt->hash_algo = hash;
	else if (env) {
		int env_algo = hash_algo_by_name(env);
		if (env_algo == shit_HASH_UNKNOWN)
			die(_("unknown hash algorithm '%s'"), env);
		repo_fmt->hash_algo = env_algo;
	}
}

static void validate_ref_storage_format(struct repository_format *repo_fmt,
					unsigned int format)
{
	const char *name = getenv("shit_DEFAULT_REF_FORMAT");

	if (repo_fmt->version >= 0 &&
	    format != REF_STORAGE_FORMAT_UNKNOWN &&
	    format != repo_fmt->ref_storage_format) {
		die(_("attempt to reinitialize repository with different reference storage format"));
	} else if (format != REF_STORAGE_FORMAT_UNKNOWN) {
		repo_fmt->ref_storage_format = format;
	} else if (name) {
		format = ref_storage_format_by_name(name);
		if (format == REF_STORAGE_FORMAT_UNKNOWN)
			die(_("unknown ref storage format '%s'"), name);
		repo_fmt->ref_storage_format = format;
	}
}

int init_db(const char *shit_dir, const char *real_shit_dir,
	    const char *template_dir, int hash,
	    unsigned int ref_storage_format,
	    const char *initial_branch,
	    int init_shared_repository, unsigned int flags)
{
	int reinit;
	int exist_ok = flags & INIT_DB_EXIST_OK;
	char *original_shit_dir = real_pathdup(shit_dir, 1);
	struct repository_format repo_fmt = REPOSITORY_FORMAT_INIT;

	if (real_shit_dir) {
		struct stat st;

		if (!exist_ok && !stat(shit_dir, &st))
			die(_("%s already exists"), shit_dir);

		if (!exist_ok && !stat(real_shit_dir, &st))
			die(_("%s already exists"), real_shit_dir);

		set_shit_dir(real_shit_dir, 1);
		shit_dir = get_shit_dir();
		separate_shit_dir(shit_dir, original_shit_dir);
	}
	else {
		set_shit_dir(shit_dir, 1);
		shit_dir = get_shit_dir();
	}
	startup_info->have_repository = 1;

	/* Ensure `core.hidedotfiles` is processed */
	shit_config(platform_core_config, NULL);

	safe_create_dir(shit_dir, 0);


	/* Check to see if the repository version is right.
	 * Note that a newly created repository does not have
	 * config file, so this will not fail.  What we are catching
	 * is an attempt to reinitialize new repository with an old tool.
	 */
	check_repository_format(&repo_fmt);

	validate_hash_algorithm(&repo_fmt, hash);
	validate_ref_storage_format(&repo_fmt, ref_storage_format);

	reinit = create_default_files(template_dir, original_shit_dir,
				      &repo_fmt, init_shared_repository);

	/*
	 * Now that we have set up both the hash algorithm and the ref storage
	 * format we can update the repository's settings accordingly.
	 */
	repo_set_hash_algo(the_repository, repo_fmt.hash_algo);
	repo_set_ref_storage_format(the_repository, repo_fmt.ref_storage_format);

	if (!(flags & INIT_DB_SKIP_REFDB))
		create_reference_database(repo_fmt.ref_storage_format,
					  initial_branch, flags & INIT_DB_QUIET);
	create_object_directory();

	if (get_shared_repository()) {
		char buf[10];
		/* We do not spell "group" and such, so that
		 * the configuration can be read by older version
		 * of shit. Note, we use octal numbers for new share modes,
		 * and compatibility values for PERM_GROUP and
		 * PERM_EVERYBODY.
		 */
		if (get_shared_repository() < 0)
			/* force to the mode value */
			xsnprintf(buf, sizeof(buf), "0%o", -get_shared_repository());
		else if (get_shared_repository() == PERM_GROUP)
			xsnprintf(buf, sizeof(buf), "%d", OLD_PERM_GROUP);
		else if (get_shared_repository() == PERM_EVERYBODY)
			xsnprintf(buf, sizeof(buf), "%d", OLD_PERM_EVERYBODY);
		else
			BUG("invalid value for shared_repository");
		shit_config_set("core.sharedrepository", buf);
		shit_config_set("receive.denyNonFastforwards", "true");
	}

	if (!(flags & INIT_DB_QUIET)) {
		int len = strlen(shit_dir);

		if (reinit)
			printf(get_shared_repository()
			       ? _("Reinitialized existing shared shit repository in %s%s\n")
			       : _("Reinitialized existing shit repository in %s%s\n"),
			       shit_dir, len && shit_dir[len-1] != '/' ? "/" : "");
		else
			printf(get_shared_repository()
			       ? _("Initialized empty shared shit repository in %s%s\n")
			       : _("Initialized empty shit repository in %s%s\n"),
			       shit_dir, len && shit_dir[len-1] != '/' ? "/" : "");
	}

	clear_repository_format(&repo_fmt);
	free(original_shit_dir);
	return 0;
}
