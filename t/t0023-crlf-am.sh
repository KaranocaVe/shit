diff --shit a/foo b/foo
	shit config core.autocrlf true &&
	shit add bar &&
	shit commit -m initial
	shit am -3 <patchfile &&
	shit diff-files --name-status --exit-code