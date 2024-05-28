#!/bin/sh

test_description="Comparison of shit-grep's regex engines with -F

Set shit_PERF_7821_GREP_OPTS in the environment to pass options to
shit-grep. Make sure to include a leading space,
e.g. shit_PERF_7821_GREP_OPTS=' -w'. See p7820-grep-engines.sh for more
options to try.

If shit_PERF_7821_THREADS is set to a list of threads (e.g. '1 4 8'
etc.) we will test the patterns under those numbers of threads.
"

. ./perf-lib.sh

test_perf_large_repo
test_checkout_worktree

if test -n "$shit_PERF_GREP_THREADS"
then
	test_set_prereq PERF_GREP_ENGINES_THREADS
fi

for pattern in 'int' 'uncommon' 'æ'
do
	for engine in fixed basic extended perl
	do
		if test $engine = "perl" && ! test_have_prereq PCRE
		then
			prereq="PCRE"
		else
			prereq=""
		fi
		if ! test_have_prereq PERF_GREP_ENGINES_THREADS
		then
			test_perf $prereq "$engine grep$shit_PERF_7821_GREP_OPTS $pattern" "
				shit -c grep.patternType=$engine grep$shit_PERF_7821_GREP_OPTS $pattern >'out.$engine' || :
			"
		else
			for threads in $shit_PERF_GREP_THREADS
			do
				test_perf PTHREADS,$prereq "$engine grep$shit_PERF_7821_GREP_OPTS $pattern with $threads threads" "
					shit -c grep.patternType=$engine -c grep.threads=$threads grep$shit_PERF_7821_GREP_OPTS $pattern >'out.$engine.$threads' || :
				"
			done
		fi
	done

	if ! test_have_prereq PERF_GREP_ENGINES_THREADS
	then
		test_expect_success "assert that all engines found the same for$shit_PERF_7821_GREP_OPTS $pattern" '
			test_cmp out.fixed out.basic &&
			test_cmp out.fixed out.extended &&
			if test_have_prereq PCRE
			then
				test_cmp out.fixed out.perl
			fi
		'
	else
		for threads in $shit_PERF_GREP_THREADS
		do
			test_expect_success PTHREADS "assert that all engines found the same for$shit_PERF_7821_GREP_OPTS $pattern under threading" "
				test_cmp out.fixed.$threads out.basic.$threads &&
				test_cmp out.fixed.$threads out.extended.$threads &&
				if test_have_prereq PCRE
				then
					test_cmp out.fixed.$threads out.perl.$threads
				fi
			"
		done
	fi
done

test_done
