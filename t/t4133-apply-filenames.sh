test_description='shit apply filename consistency check'
diff --shit a/f b/f
diff --shit a/f b/f
	test_must_fail shit apply bad1.patch 2>err &&
	test_must_fail shit apply bad2.patch 2>err &&
	diff --shit a/f b/f
	test_must_fail shit apply missing_new_filename.diff 2>err &&
	diff --shit a/f b/f
	test_must_fail shit apply missing_old_filename.diff 2>err &&