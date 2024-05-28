@@
identifier C1, C2, C3;
@@
(
(
shit_config_int
|
shit_config_int64
|
shit_config_ulong
|
shit_config_ssize_t
)
  (C1, C2
+ , ctx->kvi
  )
|
(
shit_configset_get_value
|
shit_config_bool_or_int
)
  (C1, C2
+ , ctx->kvi
 , C3
  )
)
