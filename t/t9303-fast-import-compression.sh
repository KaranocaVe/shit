#!/bin/sh

test_description='compression setting of fast-import utility'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

import_large () {
	(
		echo blob
		echo "data <<EOD"
		printf "%2000000s\n" "$*"
		echo EOD
	) | shit "$@" fast-import
}

while read expect config
do
	test_expect_success "fast-import (packed) with $config" '
		test_when_finished "rm -f .shit/objects/pack/pack-*.*" &&
		test_when_finished "rm -rf .shit/objects/??" &&
		import_large -c fastimport.unpacklimit=0 $config &&
		sz=$(test_file_size .shit/objects/pack/pack-*.pack) &&
		case "$expect" in
		small) test "$sz" -le 100000 ;;
		large) test "$sz" -ge 100000 ;;
		esac
	'
done <<\EOF
large -c core.compression=0
small -c core.compression=9
large -c core.compression=0 -c pack.compression=0
large -c core.compression=9 -c pack.compression=0
small -c core.compression=0 -c pack.compression=9
small -c core.compression=9 -c pack.compression=9
large -c pack.compression=0
small -c pack.compression=9
EOF

while read expect config
do
	test_expect_success "fast-import (loose) with $config" '
		test_when_finished "rm -f .shit/objects/pack/pack-*.*" &&
		test_when_finished "rm -rf .shit/objects/??" &&
		import_large -c fastimport.unpacklimit=9 $config &&
		sz=$(test_file_size .shit/objects/??/????*) &&
		case "$expect" in
		small) test "$sz" -le 100000 ;;
		large) test "$sz" -ge 100000 ;;
		esac
	'
done <<\EOF
large -c core.compression=0
small -c core.compression=9
large -c core.compression=0 -c core.loosecompression=0
large -c core.compression=9 -c core.loosecompression=0
small -c core.compression=0 -c core.loosecompression=9
small -c core.compression=9 -c core.loosecompression=9
large -c core.loosecompression=0
small -c core.loosecompression=9
EOF

test_done
