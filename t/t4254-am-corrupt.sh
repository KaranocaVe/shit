test_description='shit am with corrupt input'
	diff --shit a/afile b/afile
	diff --shit a/f b/f
	shit add f &&
	shit commit -m initial
	test_when_finished "shit am --abort" &&
	test_must_fail shit -c advice.amWorkDir=false -c advice.mergeConflict=false am bad-patch.diff 2>actual &&
	echo "error: shit diff header lacks filename information (line 4)" >expected &&
	test_when_finished "shit am --abort" &&
	test_must_fail shit am body.patch 2>err &&
	test_when_finished 'shit am --abort' &&
	test_must_fail shit mailinfo msg patch <subject.patch 2>err &&
	test_must_fail shit am subject.patch 2>err &&