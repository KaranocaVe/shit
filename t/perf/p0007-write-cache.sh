#!/bin/sh

test_description="Tests performance of writing the index"

. ./perf-lib.sh

test_perf_default_repo

test_expect_success "setup repo" '
	if shit rev-parse --verify refs/heads/p0006-ballast^{commit}
	then
		echo Assuming synthetic repo from many-files.sh &&
		shit config --local core.sparsecheckout 1 &&
		cat >.shit/info/sparse-checkout <<-EOF
		/*
		!ballast/*
		EOF
	else
		echo Assuming non-synthetic repo...
	fi &&
	nr_files=$(shit ls-files | wc -l)
'

count=3
test_perf "write_locked_index $count times ($nr_files files)" "
	test-tool write-cache $count
"

test_done
