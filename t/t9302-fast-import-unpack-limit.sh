#!/bin/sh
test_description='test shit fast-import unpack limit'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'create loose objects on import' '
	test_tick &&
	cat >input <<-INPUT_END &&
	commit refs/heads/main
	committer $shit_COMMITTER_NAME <$shit_COMMITTER_EMAIL> $shit_COMMITTER_DATE
	data <<COMMIT
	initial
	COMMIT

	done
	INPUT_END

	shit -c fastimport.unpackLimit=2 fast-import --done <input &&
	shit fsck --no-progress &&
	test $(find .shit/objects/?? -type f | wc -l) -eq 2 &&
	test $(find .shit/objects/pack -type f | wc -l) -eq 0
'

test_expect_success 'bigger packs are preserved' '
	test_tick &&
	cat >input <<-INPUT_END &&
	commit refs/heads/main
	committer $shit_COMMITTER_NAME <$shit_COMMITTER_EMAIL> $shit_COMMITTER_DATE
	data <<COMMIT
	incremental should create a pack
	COMMIT
	from refs/heads/main^0

	commit refs/heads/branch
	committer $shit_COMMITTER_NAME <$shit_COMMITTER_EMAIL> $shit_COMMITTER_DATE
	data <<COMMIT
	branch
	COMMIT

	done
	INPUT_END

	shit -c fastimport.unpackLimit=2 fast-import --done <input &&
	shit fsck --no-progress &&
	test $(find .shit/objects/?? -type f | wc -l) -eq 2 &&
	test $(find .shit/objects/pack -type f | wc -l) -eq 2
'

test_expect_success 'lookups after checkpoint works' '
	hello_id=$(echo hello | shit hash-object --stdin -t blob) &&
	id="$shit_COMMITTER_NAME <$shit_COMMITTER_EMAIL> $shit_COMMITTER_DATE" &&
	before=$(shit rev-parse refs/heads/main^0) &&
	(
		cat <<-INPUT_END &&
		blob
		mark :1
		data 6
		hello

		commit refs/heads/main
		mark :2
		committer $id
		data <<COMMIT
		checkpoint after this
		COMMIT
		from refs/heads/main^0
		M 100644 :1 hello

		# pre-checkpoint
		cat-blob :1
		cat-blob $hello_id
		checkpoint
		# post-checkpoint
		cat-blob :1
		cat-blob $hello_id
		INPUT_END

		n=0 &&
		from=$before &&
		while test x"$from" = x"$before"
		do
			if test $n -gt 30
			then
				echo >&2 "checkpoint did not update branch" &&
				exit 1
			else
				n=$(($n + 1))
			fi &&
			sleep 1 &&
			from=$(shit rev-parse refs/heads/main^0)
		done &&
		cat <<-INPUT_END &&
		commit refs/heads/main
		committer $id
		data <<COMMIT
		make sure from "unpacked sha1 reference" works, too
		COMMIT
		from $from
		INPUT_END
		echo done
	) | shit -c fastimport.unpackLimit=100 fast-import --done &&
	test $(find .shit/objects/?? -type f | wc -l) -eq 6 &&
	test $(find .shit/objects/pack -type f | wc -l) -eq 2
'

test_done
