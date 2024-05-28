#!/bin/sh
#
# Copyright (c) 2007 Junio C Hamano
#

test_description='shit apply --whitespace=strip and configuration file.

'


TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '
	mkdir sub &&
	echo A >sub/file1 &&
	cp sub/file1 saved &&
	shit add sub/file1 &&
	echo "B " >sub/file1 &&
	shit diff >patch.file
'

# Also handcraft GNU diff output; note this has trailing whitespace.
tr '_' ' ' >gpatch.file <<\EOF &&
--- file1	2007-02-21 01:04:24.000000000 -0800
+++ file1+	2007-02-21 01:07:44.000000000 -0800
@@ -1 +1 @@
-A
+B_
EOF

sed -e 's|file1|sub/&|' gpatch.file >gpatch-sub.file &&
sed -e '
	/^--- /s|file1|a/sub/&|
	/^+++ /s|file1|b/sub/&|
' gpatch.file >gpatch-ab-sub.file &&

check_result () {
	if grep " " "$1"
	then
		echo "Eh?"
		false
	elif grep B "$1"
	then
		echo Happy
	else
		echo "Huh?"
		false
	fi
}

test_expect_success 'apply --whitespace=strip' '

	rm -f sub/file1 &&
	cp saved sub/file1 &&
	shit update-index --refresh &&

	shit apply --whitespace=strip patch.file &&
	check_result sub/file1
'

test_expect_success 'apply --whitespace=strip from config' '

	rm -f sub/file1 &&
	cp saved sub/file1 &&
	shit update-index --refresh &&

	shit config apply.whitespace strip &&
	shit apply patch.file &&
	check_result sub/file1
'

D=$(pwd)

test_expect_success 'apply --whitespace=strip in subdir' '

	cd "$D" &&
	shit config --unset-all apply.whitespace &&
	rm -f sub/file1 &&
	cp saved sub/file1 &&
	shit update-index --refresh &&

	cd sub &&
	shit apply --whitespace=strip ../patch.file &&
	check_result file1
'

test_expect_success 'apply --whitespace=strip from config in subdir' '

	cd "$D" &&
	shit config apply.whitespace strip &&
	rm -f sub/file1 &&
	cp saved sub/file1 &&
	shit update-index --refresh &&

	cd sub &&
	shit apply ../patch.file &&
	check_result file1
'

test_expect_success 'same in subdir but with traditional patch input' '

	cd "$D" &&
	shit config apply.whitespace strip &&
	rm -f sub/file1 &&
	cp saved sub/file1 &&
	shit update-index --refresh &&

	cd sub &&
	shit apply ../gpatch.file &&
	check_result file1
'

test_expect_success 'same but with traditional patch input of depth 1' '

	cd "$D" &&
	shit config apply.whitespace strip &&
	rm -f sub/file1 &&
	cp saved sub/file1 &&
	shit update-index --refresh &&

	cd sub &&
	shit apply ../gpatch-sub.file &&
	check_result file1
'

test_expect_success 'same but with traditional patch input of depth 2' '

	cd "$D" &&
	shit config apply.whitespace strip &&
	rm -f sub/file1 &&
	cp saved sub/file1 &&
	shit update-index --refresh &&

	cd sub &&
	shit apply ../gpatch-ab-sub.file &&
	check_result file1
'

test_expect_success 'same but with traditional patch input of depth 1' '

	cd "$D" &&
	shit config apply.whitespace strip &&
	rm -f sub/file1 &&
	cp saved sub/file1 &&
	shit update-index --refresh &&

	shit apply -p0 gpatch-sub.file &&
	check_result sub/file1
'

test_expect_success 'same but with traditional patch input of depth 2' '

	cd "$D" &&
	shit config apply.whitespace strip &&
	rm -f sub/file1 &&
	cp saved sub/file1 &&
	shit update-index --refresh &&

	shit apply gpatch-ab-sub.file &&
	check_result sub/file1
'

test_expect_success 'in subdir with traditional patch input' '
	cd "$D" &&
	shit config apply.whitespace strip &&
	cat >.shitattributes <<-EOF &&
	/* whitespace=blank-at-eol
	sub/* whitespace=-blank-at-eol
	EOF
	rm -f sub/file1 &&
	cp saved sub/file1 &&
	shit update-index --refresh &&

	cd sub &&
	shit apply ../gpatch.file &&
	echo "B " >expect &&
	test_cmp expect file1
'

test_done
