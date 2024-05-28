#!/bin/sh

test_description='shit clean -i basic tests'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-terminal.sh

test_expect_success 'setup' '

	mkdir -p src &&
	touch src/part1.c Makefile &&
	echo build >.shitignore &&
	echo \*.o >>.shitignore &&
	shit add . &&
	shit commit -m setup &&
	touch src/part2.c README &&
	shit add .

'

test_expect_success 'shit clean -i (c: clean hotkey)' '

	mkdir -p build docs &&
	touch a.out src/part3.c src/part3.h src/part4.c src/part4.h \
	docs/manual.txt obj.o build/lib.so &&
	echo c | shit clean -i &&
	test_path_is_file Makefile &&
	test_path_is_file README &&
	test_path_is_file src/part1.c &&
	test_path_is_file src/part2.c &&
	test_path_is_missing a.out &&
	test_path_is_file docs/manual.txt &&
	test_path_is_missing src/part3.c &&
	test_path_is_missing src/part3.h &&
	test_path_is_missing src/part4.c &&
	test_path_is_missing src/part4.h &&
	test_path_is_file obj.o &&
	test_path_is_file build/lib.so

'

test_expect_success 'shit clean -i (cl: clean prefix)' '

	mkdir -p build docs &&
	touch a.out src/part3.c src/part3.h src/part4.c src/part4.h \
	docs/manual.txt obj.o build/lib.so &&
	echo cl | shit clean -i &&
	test_path_is_file Makefile &&
	test_path_is_file README &&
	test_path_is_file src/part1.c &&
	test_path_is_file src/part2.c &&
	test_path_is_missing a.out &&
	test_path_is_file docs/manual.txt &&
	test_path_is_missing src/part3.c &&
	test_path_is_missing src/part3.h &&
	test_path_is_missing src/part4.c &&
	test_path_is_missing src/part4.h &&
	test_path_is_file obj.o &&
	test_path_is_file build/lib.so

'

test_expect_success 'shit clean -i (quit)' '

	mkdir -p build docs &&
	touch a.out src/part3.c src/part3.h src/part4.c src/part4.h \
	docs/manual.txt obj.o build/lib.so &&
	echo quit | shit clean -i &&
	test_path_is_file Makefile &&
	test_path_is_file README &&
	test_path_is_file src/part1.c &&
	test_path_is_file src/part2.c &&
	test_path_is_file a.out &&
	test_path_is_file docs/manual.txt &&
	test_path_is_file src/part3.c &&
	test_path_is_file src/part3.h &&
	test_path_is_file src/part4.c &&
	test_path_is_file src/part4.h &&
	test_path_is_file obj.o &&
	test_path_is_file build/lib.so

'

test_expect_success 'shit clean -i (Ctrl+D)' '

	mkdir -p build docs &&
	touch a.out src/part3.c src/part3.h src/part4.c src/part4.h \
	docs/manual.txt obj.o build/lib.so &&
	echo "\04" | shit clean -i &&
	test_path_is_file Makefile &&
	test_path_is_file README &&
	test_path_is_file src/part1.c &&
	test_path_is_file src/part2.c &&
	test_path_is_file a.out &&
	test_path_is_file docs/manual.txt &&
	test_path_is_file src/part3.c &&
	test_path_is_file src/part3.h &&
	test_path_is_file src/part4.c &&
	test_path_is_file src/part4.h &&
	test_path_is_file obj.o &&
	test_path_is_file build/lib.so

'

test_expect_success 'shit clean -id (filter all)' '

	mkdir -p build docs &&
	touch a.out src/part3.c src/part3.h src/part4.c src/part4.h \
	docs/manual.txt obj.o build/lib.so &&
	test_write_lines f "*" "" c |
	shit clean -id &&
	test_path_is_file Makefile &&
	test_path_is_file README &&
	test_path_is_file src/part1.c &&
	test_path_is_file src/part2.c &&
	test_path_is_file a.out &&
	test_path_is_file docs/manual.txt &&
	test_path_is_file src/part3.c &&
	test_path_is_file src/part3.h &&
	test_path_is_file src/part4.c &&
	test_path_is_file src/part4.h &&
	test_path_is_file obj.o &&
	test_path_is_file build/lib.so

'

test_expect_success 'shit clean -id (filter patterns)' '

	mkdir -p build docs &&
	touch a.out src/part3.c src/part3.h src/part4.c src/part4.h \
	docs/manual.txt obj.o build/lib.so &&
	test_write_lines f "part3.* *.out" "" c |
	shit clean -id &&
	test_path_is_file Makefile &&
	test_path_is_file README &&
	test_path_is_file src/part1.c &&
	test_path_is_file src/part2.c &&
	test_path_is_file a.out &&
	test_path_is_missing docs/manual.txt &&
	test_path_is_file src/part3.c &&
	test_path_is_file src/part3.h &&
	test_path_is_missing src/part4.c &&
	test_path_is_missing src/part4.h &&
	test_path_is_file obj.o &&
	test_path_is_file build/lib.so

'

test_expect_success 'shit clean -id (filter patterns 2)' '

	mkdir -p build docs &&
	touch a.out src/part3.c src/part3.h src/part4.c src/part4.h \
	docs/manual.txt obj.o build/lib.so &&
	test_write_lines f "* !*.out" "" c |
	shit clean -id &&
	test_path_is_file Makefile &&
	test_path_is_file README &&
	test_path_is_file src/part1.c &&
	test_path_is_file src/part2.c &&
	test_path_is_missing a.out &&
	test_path_is_file docs/manual.txt &&
	test_path_is_file src/part3.c &&
	test_path_is_file src/part3.h &&
	test_path_is_file src/part4.c &&
	test_path_is_file src/part4.h &&
	test_path_is_file obj.o &&
	test_path_is_file build/lib.so

'

test_expect_success 'shit clean -id (select - all)' '

	mkdir -p build docs &&
	touch a.out src/part3.c src/part3.h src/part4.c src/part4.h \
	docs/manual.txt obj.o build/lib.so &&
	test_write_lines s "*" "" c |
	shit clean -id &&
	test_path_is_file Makefile &&
	test_path_is_file README &&
	test_path_is_file src/part1.c &&
	test_path_is_file src/part2.c &&
	test_path_is_missing a.out &&
	test_path_is_missing docs/manual.txt &&
	test_path_is_missing src/part3.c &&
	test_path_is_missing src/part3.h &&
	test_path_is_missing src/part4.c &&
	test_path_is_missing src/part4.h &&
	test_path_is_file obj.o &&
	test_path_is_file build/lib.so

'

test_expect_success 'shit clean -id (select - none)' '

	mkdir -p build docs &&
	touch a.out src/part3.c src/part3.h src/part4.c src/part4.h \
	docs/manual.txt obj.o build/lib.so &&
	test_write_lines s "" c |
	shit clean -id &&
	test_path_is_file Makefile &&
	test_path_is_file README &&
	test_path_is_file src/part1.c &&
	test_path_is_file src/part2.c &&
	test_path_is_file a.out &&
	test_path_is_file docs/manual.txt &&
	test_path_is_file src/part3.c &&
	test_path_is_file src/part3.h &&
	test_path_is_file src/part4.c &&
	test_path_is_file src/part4.h &&
	test_path_is_file obj.o &&
	test_path_is_file build/lib.so

'

test_expect_success 'shit clean -id (select - number)' '

	mkdir -p build docs &&
	touch a.out src/part3.c src/part3.h src/part4.c src/part4.h \
	docs/manual.txt obj.o build/lib.so &&
	test_write_lines s 3 "" c |
	shit clean -id &&
	test_path_is_file Makefile &&
	test_path_is_file README &&
	test_path_is_file src/part1.c &&
	test_path_is_file src/part2.c &&
	test_path_is_file a.out &&
	test_path_is_file docs/manual.txt &&
	test_path_is_missing src/part3.c &&
	test_path_is_file src/part3.h &&
	test_path_is_file src/part4.c &&
	test_path_is_file src/part4.h &&
	test_path_is_file obj.o &&
	test_path_is_file build/lib.so

'

test_expect_success 'shit clean -id (select - number 2)' '

	mkdir -p build docs &&
	touch a.out src/part3.c src/part3.h src/part4.c src/part4.h \
	docs/manual.txt obj.o build/lib.so &&
	test_write_lines s "2 3" 5 "" c |
	shit clean -id &&
	test_path_is_file Makefile &&
	test_path_is_file README &&
	test_path_is_file src/part1.c &&
	test_path_is_file src/part2.c &&
	test_path_is_file a.out &&
	test_path_is_missing docs/manual.txt &&
	test_path_is_missing src/part3.c &&
	test_path_is_file src/part3.h &&
	test_path_is_missing src/part4.c &&
	test_path_is_file src/part4.h &&
	test_path_is_file obj.o &&
	test_path_is_file build/lib.so

'

test_expect_success 'shit clean -id (select - number 3)' '

	mkdir -p build docs &&
	touch a.out src/part3.c src/part3.h src/part4.c src/part4.h \
	docs/manual.txt obj.o build/lib.so &&
	test_write_lines s "3,4 5" "" c |
	shit clean -id &&
	test_path_is_file Makefile &&
	test_path_is_file README &&
	test_path_is_file src/part1.c &&
	test_path_is_file src/part2.c &&
	test_path_is_file a.out &&
	test_path_is_file docs/manual.txt &&
	test_path_is_missing src/part3.c &&
	test_path_is_missing src/part3.h &&
	test_path_is_missing src/part4.c &&
	test_path_is_file src/part4.h &&
	test_path_is_file obj.o &&
	test_path_is_file build/lib.so

'

test_expect_success 'shit clean -id (select - filenames)' '

	mkdir -p build docs &&
	touch a.out foo.txt bar.txt baz.txt &&
	test_write_lines s "a.out fo ba bar" "" c |
	shit clean -id &&
	test_path_is_file Makefile &&
	test_path_is_missing a.out &&
	test_path_is_missing foo.txt &&
	test_path_is_missing bar.txt &&
	test_path_is_file baz.txt &&
	rm baz.txt

'

test_expect_success 'shit clean -id (select - range)' '

	mkdir -p build docs &&
	touch a.out src/part3.c src/part3.h src/part4.c src/part4.h \
	docs/manual.txt obj.o build/lib.so &&
	test_write_lines s "1,3-4" 2 "" c |
	shit clean -id &&
	test_path_is_file Makefile &&
	test_path_is_file README &&
	test_path_is_file src/part1.c &&
	test_path_is_file src/part2.c &&
	test_path_is_missing a.out &&
	test_path_is_missing src/part3.c &&
	test_path_is_missing src/part3.h &&
	test_path_is_file src/part4.c &&
	test_path_is_file src/part4.h &&
	test_path_is_missing docs/manual.txt &&
	test_path_is_file obj.o &&
	test_path_is_file build/lib.so

'

test_expect_success 'shit clean -id (select - range 2)' '

	mkdir -p build docs &&
	touch a.out src/part3.c src/part3.h src/part4.c src/part4.h \
	docs/manual.txt obj.o build/lib.so &&
	test_write_lines s "4- 1" "" c |
	shit clean -id &&
	test_path_is_file Makefile &&
	test_path_is_file README &&
	test_path_is_file src/part1.c &&
	test_path_is_file src/part2.c &&
	test_path_is_missing a.out &&
	test_path_is_file docs/manual.txt &&
	test_path_is_file src/part3.c &&
	test_path_is_missing src/part3.h &&
	test_path_is_missing src/part4.c &&
	test_path_is_missing src/part4.h &&
	test_path_is_file obj.o &&
	test_path_is_file build/lib.so

'

test_expect_success 'shit clean -id (inverse select)' '

	mkdir -p build docs &&
	touch a.out src/part3.c src/part3.h src/part4.c src/part4.h \
	docs/manual.txt obj.o build/lib.so &&
	test_write_lines s "*" "-5- 1 -2" "" c |
	shit clean -id &&
	test_path_is_file Makefile &&
	test_path_is_file README &&
	test_path_is_file src/part1.c &&
	test_path_is_file src/part2.c &&
	test_path_is_missing a.out &&
	test_path_is_file docs/manual.txt &&
	test_path_is_missing src/part3.c &&
	test_path_is_missing src/part3.h &&
	test_path_is_file src/part4.c &&
	test_path_is_file src/part4.h &&
	test_path_is_file obj.o &&
	test_path_is_file build/lib.so

'

test_expect_success 'shit clean -id (ask)' '

	mkdir -p build docs &&
	touch a.out src/part3.c src/part3.h src/part4.c src/part4.h \
	docs/manual.txt obj.o build/lib.so &&
	test_write_lines a Y y no yes bad "" |
	shit clean -id &&
	test_path_is_file Makefile &&
	test_path_is_file README &&
	test_path_is_file src/part1.c &&
	test_path_is_file src/part2.c &&
	test_path_is_missing a.out &&
	test_path_is_missing docs/manual.txt &&
	test_path_is_file src/part3.c &&
	test_path_is_missing src/part3.h &&
	test_path_is_file src/part4.c &&
	test_path_is_file src/part4.h &&
	test_path_is_file obj.o &&
	test_path_is_file build/lib.so

'

test_expect_success 'shit clean -id (ask - Ctrl+D)' '

	mkdir -p build docs &&
	touch a.out src/part3.c src/part3.h src/part4.c src/part4.h \
	docs/manual.txt obj.o build/lib.so &&
	test_write_lines a Y no yes "\04" |
	shit clean -id &&
	test_path_is_file Makefile &&
	test_path_is_file README &&
	test_path_is_file src/part1.c &&
	test_path_is_file src/part2.c &&
	test_path_is_missing a.out &&
	test_path_is_file docs/manual.txt &&
	test_path_is_missing src/part3.c &&
	test_path_is_file src/part3.h &&
	test_path_is_file src/part4.c &&
	test_path_is_file src/part4.h &&
	test_path_is_file obj.o &&
	test_path_is_file build/lib.so

'

test_expect_success 'shit clean -id with prefix and path (filter)' '

	mkdir -p build docs &&
	touch a.out src/part3.c src/part3.h src/part4.c src/part4.h \
	docs/manual.txt obj.o build/lib.so &&
	(cd build/ &&
	 test_write_lines f docs "*.h" "" c |
	 shit clean -id ..) &&
	test_path_is_file Makefile &&
	test_path_is_file README &&
	test_path_is_file src/part1.c &&
	test_path_is_file src/part2.c &&
	test_path_is_missing a.out &&
	test_path_is_file docs/manual.txt &&
	test_path_is_missing src/part3.c &&
	test_path_is_file src/part3.h &&
	test_path_is_missing src/part4.c &&
	test_path_is_file src/part4.h &&
	test_path_is_file obj.o &&
	test_path_is_file build/lib.so

'

test_expect_success 'shit clean -id with prefix and path (select by name)' '

	mkdir -p build docs &&
	touch a.out src/part3.c src/part3.h src/part4.c src/part4.h \
	docs/manual.txt obj.o build/lib.so &&
	(cd build/ &&
	 test_write_lines s ../docs/ ../src/part3.c ../src/part4.c "" c |
	 shit clean -id ..) &&
	test_path_is_file Makefile &&
	test_path_is_file README &&
	test_path_is_file src/part1.c &&
	test_path_is_file src/part2.c &&
	test_path_is_file a.out &&
	test_path_is_missing docs/manual.txt &&
	test_path_is_missing src/part3.c &&
	test_path_is_file src/part3.h &&
	test_path_is_missing src/part4.c &&
	test_path_is_file src/part4.h &&
	test_path_is_file obj.o &&
	test_path_is_file build/lib.so

'

test_expect_success 'shit clean -id with prefix and path (ask)' '

	mkdir -p build docs &&
	touch a.out src/part3.c src/part3.h src/part4.c src/part4.h \
	docs/manual.txt obj.o build/lib.so &&
	(cd build/ &&
	 test_write_lines a Y y no yes bad "" |
	 shit clean -id ..) &&
	test_path_is_file Makefile &&
	test_path_is_file README &&
	test_path_is_file src/part1.c &&
	test_path_is_file src/part2.c &&
	test_path_is_missing a.out &&
	test_path_is_missing docs/manual.txt &&
	test_path_is_file src/part3.c &&
	test_path_is_missing src/part3.h &&
	test_path_is_file src/part4.c &&
	test_path_is_file src/part4.h &&
	test_path_is_file obj.o &&
	test_path_is_file build/lib.so

'

test_expect_success TTY 'shit clean -i paints the header in HEADER color' '
	>a.out &&
	echo q |
	test_terminal shit clean -i |
	test_decode_color |
	head -n 1 >header &&
	# not i18ngrep
	grep "^<BOLD>" header
'

test_done
