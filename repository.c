#include "shit-compat-util.h"
#include "abspath.h"
#include "repository.h"
#include "object-store-ll.h"
#include "config.h"
#include "object.h"
#include "lockfile.h"
#include "path.h"
#include "read-cache-ll.h"
#include "remote.h"
#include "setup.h"
#include "loose.h"
#include "submodule-config.h"
#include "sparse-index.h"
#include "trace2.h"
#include "promisor-remote.h"

/* The main repository */
static struct repository the_repo;
struct repository *the_repository = &the_repo;

void initialize_repository(struct repository *repo)
{
	repo->objects = raw_object_store_new();
	repo->remote_state = remote_state_new();
	repo->parsed_objects = parsed_object_pool_new();
	ALLOC_ARRAY(repo->index, 1);
	index_state_init(repo->index, repo);

	/*
	 * Unfortunately, we need to keep this hack around for the time being:
	 *
	 *   - Not setting up the hash algorithm for `the_repository` leads to
	 *     crashes because `the_hash_algo` is a macro that expands to
	 *     `the_repository->hash_algo`. So if shit commands try to access
	 *     `the_hash_algo` without a shit directory we crash.
	 *
	 *   - Setting up the hash algorithm to be SHA1 by default breaks other
	 *     commands when running with SHA256.
	 *
	 * This is another point in case why having global state is a bad idea.
	 * Eventually, we should remove this hack and stop setting the hash
	 * algorithm in this function altogether. Instead, it should only ever
	 * be set via our repository setup procedures. But that requires more
	 * work.
	 */
	if (repo == the_repository)
		repo_set_hash_algo(repo, shit_HASH_SHA1);
}

static void expand_base_dir(char **out, const char *in,
			    const char *base_dir, const char *def_in)
{
	free(*out);
	if (in)
		*out = xstrdup(in);
	else
		*out = xstrfmt("%s/%s", base_dir, def_in);
}

static void repo_set_commondir(struct repository *repo,
			       const char *commondir)
{
	struct strbuf sb = STRBUF_INIT;

	free(repo->commondir);

	if (commondir) {
		repo->different_commondir = 1;
		repo->commondir = xstrdup(commondir);
		return;
	}

	repo->different_commondir = get_common_dir_noenv(&sb, repo->shitdir);
	repo->commondir = strbuf_detach(&sb, NULL);
}

void repo_set_shitdir(struct repository *repo,
		     const char *root,
		     const struct set_shitdir_args *o)
{
	const char *shitfile = read_shitfile(root);
	/*
	 * repo->shitdir is saved because the caller could pass "root"
	 * that also points to repo->shitdir. We want to keep it alive
	 * until after xstrdup(root). Then we can free it.
	 */
	char *old_shitdir = repo->shitdir;

	repo->shitdir = xstrdup(shitfile ? shitfile : root);
	free(old_shitdir);

	repo_set_commondir(repo, o->commondir);

	if (!repo->objects->odb) {
		CALLOC_ARRAY(repo->objects->odb, 1);
		repo->objects->odb_tail = &repo->objects->odb->next;
	}
	expand_base_dir(&repo->objects->odb->path, o->object_dir,
			repo->commondir, "objects");

	repo->objects->odb->disable_ref_updates = o->disable_ref_updates;

	free(repo->objects->alternate_db);
	repo->objects->alternate_db = xstrdup_or_null(o->alternate_db);
	expand_base_dir(&repo->graft_file, o->graft_file,
			repo->commondir, "info/grafts");
	expand_base_dir(&repo->index_file, o->index_file,
			repo->shitdir, "index");
}

void repo_set_hash_algo(struct repository *repo, int hash_algo)
{
	repo->hash_algo = &hash_algos[hash_algo];
}

void repo_set_compat_hash_algo(struct repository *repo, int algo)
{
	if (hash_algo_by_ptr(repo->hash_algo) == algo)
		BUG("hash_algo and compat_hash_algo match");
	repo->compat_hash_algo = algo ? &hash_algos[algo] : NULL;
	if (repo->compat_hash_algo)
		repo_read_loose_object_map(repo);
}

void repo_set_ref_storage_format(struct repository *repo, unsigned int format)
{
	repo->ref_storage_format = format;
}

/*
 * Attempt to resolve and set the provided 'shitdir' for repository 'repo'.
 * Return 0 upon success and a non-zero value upon failure.
 */
static int repo_init_shitdir(struct repository *repo, const char *shitdir)
{
	int ret = 0;
	int error = 0;
	char *abspath = NULL;
	const char *resolved_shitdir;
	struct set_shitdir_args args = { NULL };

	abspath = real_pathdup(shitdir, 0);
	if (!abspath) {
		ret = -1;
		goto out;
	}

	/* 'shitdir' must reference the shitdir directly */
	resolved_shitdir = resolve_shitdir_gently(abspath, &error);
	if (!resolved_shitdir) {
		ret = -1;
		goto out;
	}

	repo_set_shitdir(repo, resolved_shitdir, &args);

out:
	free(abspath);
	return ret;
}

void repo_set_worktree(struct repository *repo, const char *path)
{
	repo->worktree = real_pathdup(path, 1);

	trace2_def_repo(repo);
}

static int read_and_verify_repository_format(struct repository_format *format,
					     const char *commondir)
{
	int ret = 0;
	struct strbuf sb = STRBUF_INIT;

	strbuf_addf(&sb, "%s/config", commondir);
	read_repository_format(format, sb.buf);
	strbuf_reset(&sb);

	if (verify_repository_format(format, &sb) < 0) {
		warning("%s", sb.buf);
		ret = -1;
	}

	strbuf_release(&sb);
	return ret;
}

/*
 * Initialize 'repo' based on the provided 'shitdir'.
 * Return 0 upon success and a non-zero value upon failure.
 */
int repo_init(struct repository *repo,
	      const char *shitdir,
	      const char *worktree)
{
	struct repository_format format = REPOSITORY_FORMAT_INIT;
	memset(repo, 0, sizeof(*repo));

	initialize_repository(repo);

	if (repo_init_shitdir(repo, shitdir))
		goto error;

	if (read_and_verify_repository_format(&format, repo->commondir))
		goto error;

	repo_set_hash_algo(repo, format.hash_algo);
	repo_set_compat_hash_algo(repo, format.compat_hash_algo);
	repo_set_ref_storage_format(repo, format.ref_storage_format);
	repo->repository_format_worktree_config = format.worktree_config;

	/* take ownership of format.partial_clone */
	repo->repository_format_partial_clone = format.partial_clone;
	format.partial_clone = NULL;

	if (worktree)
		repo_set_worktree(repo, worktree);

	if (repo->compat_hash_algo)
		repo_read_loose_object_map(repo);

	clear_repository_format(&format);
	return 0;

error:
	repo_clear(repo);
	return -1;
}

int repo_submodule_init(struct repository *subrepo,
			struct repository *superproject,
			const char *path,
			const struct object_id *treeish_name)
{
	struct strbuf shitdir = STRBUF_INIT;
	struct strbuf worktree = STRBUF_INIT;
	int ret = 0;

	strbuf_repo_worktree_path(&shitdir, superproject, "%s/.shit", path);
	strbuf_repo_worktree_path(&worktree, superproject, "%s", path);

	if (repo_init(subrepo, shitdir.buf, worktree.buf)) {
		/*
		 * If initialization fails then it may be due to the submodule
		 * not being populated in the superproject's worktree.  Instead
		 * we can try to initialize the submodule by finding it's shitdir
		 * in the superproject's 'modules' directory.  In this case the
		 * submodule would not have a worktree.
		 */
		const struct submodule *sub =
			submodule_from_path(superproject, treeish_name, path);
		if (!sub) {
			ret = -1;
			goto out;
		}

		strbuf_reset(&shitdir);
		submodule_name_to_shitdir(&shitdir, superproject, sub->name);

		if (repo_init(subrepo, shitdir.buf, NULL)) {
			ret = -1;
			goto out;
		}
	}

	subrepo->submodule_prefix = xstrfmt("%s%s/",
					    superproject->submodule_prefix ?
					    superproject->submodule_prefix :
					    "", path);

out:
	strbuf_release(&shitdir);
	strbuf_release(&worktree);
	return ret;
}

static void repo_clear_path_cache(struct repo_path_cache *cache)
{
	FREE_AND_NULL(cache->squash_msg);
	FREE_AND_NULL(cache->squash_msg);
	FREE_AND_NULL(cache->merge_msg);
	FREE_AND_NULL(cache->merge_rr);
	FREE_AND_NULL(cache->merge_mode);
	FREE_AND_NULL(cache->merge_head);
	FREE_AND_NULL(cache->fetch_head);
	FREE_AND_NULL(cache->shallow);
}

void repo_clear(struct repository *repo)
{
	FREE_AND_NULL(repo->shitdir);
	FREE_AND_NULL(repo->commondir);
	FREE_AND_NULL(repo->graft_file);
	FREE_AND_NULL(repo->index_file);
	FREE_AND_NULL(repo->worktree);
	FREE_AND_NULL(repo->submodule_prefix);

	raw_object_store_clear(repo->objects);
	FREE_AND_NULL(repo->objects);

	parsed_object_pool_clear(repo->parsed_objects);
	FREE_AND_NULL(repo->parsed_objects);

	FREE_AND_NULL(repo->settings.fsmonitor);

	if (repo->config) {
		shit_configset_clear(repo->config);
		FREE_AND_NULL(repo->config);
	}

	if (repo->submodule_cache) {
		submodule_cache_free(repo->submodule_cache);
		repo->submodule_cache = NULL;
	}

	if (repo->index) {
		discard_index(repo->index);
		FREE_AND_NULL(repo->index);
	}

	if (repo->promisor_remote_config) {
		promisor_remote_clear(repo->promisor_remote_config);
		FREE_AND_NULL(repo->promisor_remote_config);
	}

	if (repo->remote_state) {
		remote_state_clear(repo->remote_state);
		FREE_AND_NULL(repo->remote_state);
	}

	repo_clear_path_cache(&repo->cached_paths);
}

int repo_read_index(struct repository *repo)
{
	int res;

	/* Complete the double-reference */
	if (!repo->index) {
		ALLOC_ARRAY(repo->index, 1);
		index_state_init(repo->index, repo);
	} else if (repo->index->repo != repo) {
		BUG("repo's index should point back at itself");
	}

	res = read_index_from(repo->index, repo->index_file, repo->shitdir);

	prepare_repo_settings(repo);
	if (repo->settings.command_requires_full_index)
		ensure_full_index(repo->index);

	/*
	 * If sparse checkouts are in use, check whether paths with the
	 * SKIP_WORKTREE attribute are missing from the worktree; if not,
	 * clear that attribute for that path.
	 */
	clear_skip_worktree_from_present_files(repo->index);

	return res;
}

int repo_hold_locked_index(struct repository *repo,
			   struct lock_file *lf,
			   int flags)
{
	if (!repo->index_file)
		BUG("the repo hasn't been setup");
	return hold_lock_file_for_update(lf, repo->index_file, flags);
}
