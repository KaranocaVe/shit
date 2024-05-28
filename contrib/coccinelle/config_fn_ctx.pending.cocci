@ get_fn @
identifier fn, R;
@@
(
(
shit_config_from_file
|
shit_config_from_file_with_options
|
shit_config_from_mem
|
shit_config_from_blob_oid
|
read_early_config
|
read_very_early_config
|
config_with_options
|
shit_config
|
shit_protected_config
|
config_from_shitmodules
)
  (fn, ...)
|
repo_config(R, fn, ...)
)

@ extends get_fn @
identifier C1, C2, D;
@@
int fn(const char *C1, const char *C2,
+ const struct config_context *ctx,
  void *D);

@ extends get_fn @
@@
int fn(const char *, const char *,
+ const struct config_context *,
  void *);

@ extends get_fn @
// Don't change fns that look like callback fns but aren't
identifier fn2 != tar_filter_config && != shit_diff_heuristic_config &&
  != shit_default_submodule_config && != shit_color_config &&
  != bundle_list_update && != parse_object_filter_config;
identifier C1, C2, D1, D2, S;
attribute name UNUSED;
@@
int fn(const char *C1, const char *C2,
+ const struct config_context *ctx,
  void *D1) {
<+...
(
fn2(C1, C2
+ , ctx
, D2);
|
if(fn2(C1, C2
+ , ctx
, D2) < 0) { ... }
|
return fn2(C1, C2
+ , ctx
, D2);
|
S = fn2(C1, C2
+ , ctx
, D2);
)
...+>
  }

@ extends get_fn@
identifier C1, C2, D;
attribute name UNUSED;
@@
int fn(const char *C1, const char *C2,
+ const struct config_context *ctx UNUSED,
  void *D) {...}


// The previous rules don't catch all callbacks, especially if they're defined
// in a separate file from the shit_config() call. Fix these manually.
@@
identifier C1, C2, D;
attribute name UNUSED;
@@
int
(
shit_ident_config
|
urlmatch_collect_fn
|
write_one_config
|
forbid_remote_url
|
credential_config_callback
)
  (const char *C1, const char *C2,
+ const struct config_context *ctx UNUSED,
  void *D) {...}

@@
identifier C1, C2, D, D2, S, fn2;
@@
int
(
http_options
|
shit_status_config
|
shit_commit_config
|
shit_default_core_config
|
grep_config
)
  (const char *C1, const char *C2,
+ const struct config_context *ctx,
  void *D) {
<+...
(
fn2(C1, C2
+ , ctx
, D2);
|
if(fn2(C1, C2
+ , ctx
, D2) < 0) { ... }
|
return fn2(C1, C2
+ , ctx
, D2);
|
S = fn2(C1, C2
+ , ctx
, D2);
)
...+>
  }
