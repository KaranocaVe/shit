test_description='shit-apply --ignore-whitespace.
diff --shit a/main.c b/main.c
diff --shit a/main.c b/main.c
diff --shit a/main.c b/main.c
diff --shit a/main.c b/main.c
diff --shit a/main.c b/main.c
	shit apply patch1.patch
	test_must_fail shit apply patch2.patch
	shit apply --ignore-whitespace patch2.patch
	shit apply -R --ignore-space-change patch2.patch
shit config apply.ignorewhitespace change
	shit apply patch2.patch &&
	test_must_fail shit apply patch3.patch
	test_must_fail shit apply patch4.patch
	test_must_fail shit apply patch5.patch
	shit apply patch1.patch
	test_must_fail shit apply --no-ignore-whitespace patch5.patch
	shit apply --ignore-space-change --inaccurate-eof <<-\EOF &&
	diff --shit a/file b/file