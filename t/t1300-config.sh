#!/bin/sh
#
# Copyright (c) 2005 Johannes Schindelin
#

test_description='Test shit config in different settings'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

for mode in legacy subcommands
do

case "$mode" in
legacy)
	mode_prefix="--"
	mode_get=""
	mode_get_all="--get-all"
	mode_get_regexp="--get-regexp"
	mode_set=""
	mode_replace_all="--replace-all"
	mode_unset="--unset"
	mode_unset_all="--unset-all"
	;;
subcommands)
	mode_prefix=""
	mode_get="get"
	mode_get_all="get --all"
	mode_get_regexp="get --regexp --all --show-names"
	mode_set="set"
	mode_replace_all="set --all"
	mode_unset="unset"
	mode_unset_all="unset --all"
	;;
*)
	BUG "unknown mode $mode";;
esac

test_expect_success 'setup whitespace config' '
	sed -e "s/^|//" \
	    -e "s/[$]$//" \
	    -e "s/X/	/g" >.shit/config <<-\EOF
	[section]
	|	solid = rock
	|	sparse = big XX blue
	|	sparseAndTail = big XX blue $
	|	sparseAndTailQuoted = "big XX blue "
	|	sparseAndBiggerTail = big XX blue X X
	|	sparseAndBiggerTailQuoted = "big XX blue X X"
	|	sparseAndBiggerTailQuotedPlus = "big XX blue X X"X $
	|	headAndTail = Xbig blue $
	|	headAndTailQuoted = "Xbig blue "
	|	headAndTailQuotedPlus = "Xbig blue " $
	|	annotated = big blueX# to be discarded
	|	annotatedQuoted = "big blue"X# to be discarded
	EOF
'

test_expect_success 'no internal whitespace' '
	echo "rock" >expect &&
	shit config --get section.solid >actual &&
	test_cmp expect actual
'

test_expect_success 'internal whitespace' '
	echo "big QQ blue" | q_to_tab >expect &&
	shit config --get section.sparse >actual &&
	test_cmp expect actual
'

test_expect_success 'internal and trailing whitespace' '
	echo "big QQ blue" | q_to_tab >expect &&
	shit config --get section.sparseAndTail >actual &&
	test_cmp expect actual
'

test_expect_success 'internal and trailing whitespace, all quoted' '
	echo "big QQ blue " | q_to_tab >expect &&
	shit config --get section.sparseAndTailQuoted >actual &&
	test_cmp expect actual
'

test_expect_success 'internal and more trailing whitespace' '
	echo "big QQ blue" | q_to_tab >expect &&
	shit config --get section.sparseAndBiggerTail >actual &&
	test_cmp expect actual
'

test_expect_success 'internal and more trailing whitespace, all quoted' '
	echo "big QQ blue Q Q" | q_to_tab >expect &&
	shit config --get section.sparseAndBiggerTailQuoted >actual &&
	test_cmp expect actual
'

test_expect_success 'internal and more trailing whitespace, not all quoted' '
	echo "big QQ blue Q Q" | q_to_tab >expect &&
	shit config --get section.sparseAndBiggerTailQuotedPlus >actual &&
	test_cmp expect actual
'

test_expect_success 'leading and trailing whitespace' '
	echo "big blue" >expect &&
	shit config --get section.headAndTail >actual &&
	test_cmp expect actual
'

test_expect_success 'leading and trailing whitespace, all quoted' '
	echo "Qbig blue " | q_to_tab >expect &&
	shit config --get section.headAndTailQuoted >actual &&
	test_cmp expect actual
'

test_expect_success 'leading and trailing whitespace, not all quoted' '
	echo "Qbig blue " | q_to_tab >expect &&
	shit config --get section.headAndTailQuotedPlus >actual &&
	test_cmp expect actual
'

test_expect_success 'inline comment' '
	echo "big blue" >expect &&
	shit config --get section.annotated >actual &&
	test_cmp expect actual
'

test_expect_success 'inline comment, quoted' '
	echo "big blue" >expect &&
	shit config --get section.annotatedQuoted >actual &&
	test_cmp expect actual
'

test_expect_success 'clear default config' '
	rm -f .shit/config
'

cat > expect << EOF
[section]
	penguin = little blue
EOF
test_expect_success 'initial' '
	shit config ${mode_set} section.penguin "little blue" &&
	test_cmp expect .shit/config
'

cat > expect << EOF
[section]
	penguin = little blue
	Movie = BadPhysics
EOF
test_expect_success 'mixed case' '
	shit config ${mode_set} Section.Movie BadPhysics &&
	test_cmp expect .shit/config
'

cat > expect << EOF
[section]
	penguin = little blue
	Movie = BadPhysics
[Sections]
	WhatEver = Second
EOF
test_expect_success 'similar section' '
	shit config ${mode_set} Sections.WhatEver Second &&
	test_cmp expect .shit/config
'

cat > expect << EOF
[section]
	penguin = little blue
	Movie = BadPhysics
	UPPERCASE = true
[Sections]
	WhatEver = Second
EOF
test_expect_success 'uppercase section' '
	shit config ${mode_set} SECTION.UPPERCASE true &&
	test_cmp expect .shit/config
'

test_expect_success 'replace with non-match' '
	shit config section.penguin kingpin !blue
'

test_expect_success 'replace with non-match (actually matching)' '
	shit config section.penguin "very blue" !kingpin
'

cat > expect << EOF
[section]
	Movie = BadPhysics
	UPPERCASE = true
	penguin = gentoo # Pygoscelis papua
	disposition = peckish # find fish
	foo = bar #abc
	spsp = value # and comment
	htsp = value	# and comment
[Sections]
	WhatEver = Second
EOF

test_expect_success 'append comments' '
	shit config --replace-all --comment="Pygoscelis papua" section.penguin gentoo &&
	shit config ${mode_set} --comment="find fish" section.disposition peckish &&
	shit config ${mode_set} --comment="#abc" section.foo bar &&

	shit config --comment="and comment" section.spsp value &&
	shit config --comment="	# and comment" section.htsp value &&

	test_cmp expect .shit/config
'

test_expect_success 'Prohibited LF in comment' '
	test_must_fail shit config ${mode_set} --comment="a${LF}b" section.k v
'

test_expect_success 'non-match result' 'test_cmp expect .shit/config'

test_expect_success 'find mixed-case key by canonical name' '
	test_cmp_config Second sections.whatever
'

test_expect_success 'find mixed-case key by non-canonical name' '
	test_cmp_config Second SeCtIoNs.WhAtEvEr
'

test_expect_success 'subsections are not canonicalized by shit-config' '
	cat >>.shit/config <<-\EOF &&
	[section.SubSection]
	key = one
	[section "SubSection"]
	key = two
	EOF
	test_cmp_config one section.subsection.key &&
	test_cmp_config two section.SubSection.key
'

test_missing_key () {
	local key="$1" &&
	local title="$2" &&
	test_expect_success "value for $title is not printed" '
		test_must_fail shit config "$key" >out 2>err &&
		test_must_be_empty out &&
		test_must_be_empty err
	'
}

test_missing_key 'missingsection.missingkey' 'missing section and missing key'
test_missing_key 'missingsection.penguin' 'missing section and existing key'
test_missing_key 'section.missingkey' 'existing section and missing key'
test_missing_key 'section.MissingSubSection.missingkey' 'missing subsection and missing key'
test_missing_key 'section.SubSection.missingkey' 'existing subsection and missing key'
test_missing_key 'section.MissingSubSection.key' 'missing subsection and existing key'

cat > .shit/config <<\EOF
[alpha]
bar = foo
[beta]
baz = multiple \
lines
foo = bar
EOF

test_expect_success 'unset with cont. lines' '
	shit config ${mode_unset} beta.baz
'

cat > expect <<\EOF
[alpha]
bar = foo
[beta]
foo = bar
EOF

test_expect_success 'unset with cont. lines is correct' 'test_cmp expect .shit/config'

cat > .shit/config << EOF
[beta] ; silly comment # another comment
noIndent= sillyValue ; 'nother silly comment

# empty line
		; comment
		haha   ="beta" # last silly comment
haha = hello
	haha = bello
[nextSection] noNewline = ouch
EOF

cp .shit/config .shit/config2

test_expect_success 'multiple unset' '
	shit config ${mode_unset_all} beta.haha
'

cat > expect << EOF
[beta] ; silly comment # another comment
noIndent= sillyValue ; 'nother silly comment

# empty line
		; comment
[nextSection] noNewline = ouch
EOF

test_expect_success 'multiple unset is correct' '
	test_cmp expect .shit/config
'

cp .shit/config2 .shit/config

test_expect_success '--replace-all missing value' '
	test_must_fail shit config ${mode_replace_all} beta.haha &&
	test_cmp .shit/config2 .shit/config
'

rm .shit/config2

test_expect_success '--replace-all' '
	shit config ${mode_replace_all} beta.haha gamma
'

cat > expect << EOF
[beta] ; silly comment # another comment
noIndent= sillyValue ; 'nother silly comment

# empty line
		; comment
	haha = gamma
[nextSection] noNewline = ouch
EOF

test_expect_success 'all replaced' '
	test_cmp expect .shit/config
'

cat > expect << EOF
[beta] ; silly comment # another comment
noIndent= sillyValue ; 'nother silly comment

# empty line
		; comment
	haha = alpha
[nextSection] noNewline = ouch
EOF
test_expect_success 'really mean test' '
	shit config ${mode_set} beta.haha alpha &&
	test_cmp expect .shit/config
'

cat > expect << EOF
[beta] ; silly comment # another comment
noIndent= sillyValue ; 'nother silly comment

# empty line
		; comment
	haha = alpha
[nextSection]
	nonewline = wow
EOF
test_expect_success 'really really mean test' '
	shit config ${mode_set} nextsection.nonewline wow &&
	test_cmp expect .shit/config
'

test_expect_success 'get value' '
	test_cmp_config alpha beta.haha
'

cat > expect << EOF
[beta] ; silly comment # another comment
noIndent= sillyValue ; 'nother silly comment

# empty line
		; comment
[nextSection]
	nonewline = wow
EOF
test_expect_success 'unset' '
	shit config ${mode_unset} beta.haha &&
	test_cmp expect .shit/config
'

cat > expect << EOF
[beta] ; silly comment # another comment
noIndent= sillyValue ; 'nother silly comment

# empty line
		; comment
[nextSection]
	nonewline = wow
	NoNewLine = wow2 for me
EOF
test_expect_success 'multivar' '
	shit config nextsection.NoNewLine "wow2 for me" "for me$" &&
	test_cmp expect .shit/config
'

test_expect_success 'non-match' '
	shit config --get nextsection.nonewline !for
'

test_expect_success 'non-match value' '
	test_cmp_config wow --get nextsection.nonewline !for
'

test_expect_success 'multi-valued get returns final one' '
	test_cmp_config "wow2 for me" --get nextsection.nonewline
'

test_expect_success 'multi-valued get-all returns all' '
	cat >expect <<-\EOF &&
	wow
	wow2 for me
	EOF
	shit config ${mode_get_all} nextsection.nonewline >actual &&
	test_cmp expect actual
'

cat > expect << EOF
[beta] ; silly comment # another comment
noIndent= sillyValue ; 'nother silly comment

# empty line
		; comment
[nextSection]
	nonewline = wow3
	NoNewLine = wow2 for me
EOF
test_expect_success 'multivar replace' '
	shit config nextsection.nonewline "wow3" "wow$" &&
	test_cmp expect .shit/config
'

test_expect_success 'ambiguous unset' '
	test_must_fail shit config ${mode_unset} nextsection.nonewline
'

test_expect_success 'invalid unset' '
	test_must_fail shit config ${mode_unset} somesection.nonewline
'

cat > expect << EOF
[beta] ; silly comment # another comment
noIndent= sillyValue ; 'nother silly comment

# empty line
		; comment
[nextSection]
	NoNewLine = wow2 for me
EOF

test_expect_success 'multivar unset' '
	case "$mode" in
	legacy)
		shit config --unset nextsection.nonewline "wow3$";;
	subcommands)
		shit config unset --value="wow3$" nextsection.nonewline;;
	esac &&
	test_cmp expect .shit/config
'

test_expect_success 'invalid key' 'test_must_fail shit config inval.2key blabla'

test_expect_success 'correct key' 'shit config 123456.a123 987'

test_expect_success 'hierarchical section' '
	shit config Version.1.2.3eX.Alpha beta
'

cat > expect << EOF
[beta] ; silly comment # another comment
noIndent= sillyValue ; 'nother silly comment

# empty line
		; comment
[nextSection]
	NoNewLine = wow2 for me
[123456]
	a123 = 987
[Version "1.2.3eX"]
	Alpha = beta
EOF

test_expect_success 'hierarchical section value' '
	test_cmp expect .shit/config
'

cat > expect << EOF
beta.noindent=sillyValue
nextsection.nonewline=wow2 for me
123456.a123=987
version.1.2.3eX.alpha=beta
EOF

test_expect_success 'working --list' '
	shit config ${mode_prefix}list > output &&
	test_cmp expect output
'
test_expect_success '--list without repo produces empty output' '
	shit --shit-dir=nonexistent config ${mode_prefix}list >output &&
	test_must_be_empty output
'

cat > expect << EOF
beta.noindent
nextsection.nonewline
123456.a123
version.1.2.3eX.alpha
EOF

test_expect_success '--name-only --list' '
	shit config ${mode_prefix}list --name-only >output &&
	test_cmp expect output
'

cat > expect << EOF
beta.noindent sillyValue
nextsection.nonewline wow2 for me
EOF

test_expect_success '--get-regexp' '
	shit config ${mode_get_regexp} in >output &&
	test_cmp expect output
'

cat > expect << EOF
beta.noindent
nextsection.nonewline
EOF

test_expect_success '--name-only --get-regexp' '
	shit config ${mode_get_regexp} --name-only in >output &&
	test_cmp expect output
'

cat > expect << EOF
wow2 for me
wow4 for you
EOF

test_expect_success '--add' '
	shit config --add nextsection.nonewline "wow4 for you" &&
	shit config ${mode_get_all} nextsection.nonewline > output &&
	test_cmp expect output
'

cat > .shit/config << EOF
[novalue]
	variable
[emptyvalue]
	variable =
EOF

test_expect_success 'get variable with no value' '
	shit config --get novalue.variable ^$
'

test_expect_success 'get variable with empty value' '
	shit config --get emptyvalue.variable ^$
'

echo novalue.variable > expect

test_expect_success 'get-regexp variable with no value' '
	shit config ${mode_get_regexp} novalue > output &&
	test_cmp expect output
'

echo 'novalue.variable true' > expect

test_expect_success 'get-regexp --bool variable with no value' '
	shit config ${mode_get_regexp} --bool novalue > output &&
	test_cmp expect output
'

echo 'emptyvalue.variable ' > expect

test_expect_success 'get-regexp variable with empty value' '
	shit config ${mode_get_regexp} emptyvalue > output &&
	test_cmp expect output
'

echo true > expect

test_expect_success 'get bool variable with no value' '
	shit config --bool novalue.variable > output &&
	test_cmp expect output
'

echo false > expect

test_expect_success 'get bool variable with empty value' '
	shit config --bool emptyvalue.variable > output &&
	test_cmp expect output
'

test_expect_success 'no arguments, but no crash' '
	test_must_fail shit config >output 2>&1 &&
	test_grep usage output
'

cat > .shit/config << EOF
[a.b]
	c = d
EOF

cat > expect << EOF
[a.b]
	c = d
[a]
	x = y
EOF

test_expect_success 'new section is partial match of another' '
	shit config a.x y &&
	test_cmp expect .shit/config
'

cat > expect << EOF
[a.b]
	c = d
[a]
	x = y
	b = c
[b]
	x = y
EOF

test_expect_success 'new variable inserts into proper section' '
	shit config b.x y &&
	shit config a.b c &&
	test_cmp expect .shit/config
'

test_expect_success 'alternative --file (non-existing file should fail)' '
	test_must_fail shit config --file non-existing-config -l &&
	test_must_fail shit config --file non-existing-config test.xyzzy
'

cat > other-config << EOF
[ein]
	bahn = strasse
EOF

cat > expect << EOF
ein.bahn=strasse
EOF

test_expect_success 'alternative shit_CONFIG' '
	shit_CONFIG=other-config shit config ${mode_prefix}list >output &&
	test_cmp expect output
'

test_expect_success 'alternative shit_CONFIG (--file)' '
	shit config ${mode_prefix}list --file other-config >output &&
	test_cmp expect output
'

test_expect_success 'alternative shit_CONFIG (--file=-)' '
	shit config ${mode_prefix}list --file - <other-config >output &&
	test_cmp expect output
'

test_expect_success 'setting a value in stdin is an error' '
	test_must_fail shit config --file - some.value foo
'

test_expect_success 'editing stdin is an error' '
	test_must_fail shit config ${mode_prefix}edit --file -
'

test_expect_success 'refer config from subdirectory' '
	test_when_finished "rm -r x" &&
	mkdir x &&
	test_cmp_config -C x strasse --file=../other-config --get ein.bahn
'

cat > expect << EOF
[ein]
	bahn = strasse
[anwohner]
	park = ausweis
EOF

test_expect_success '--set in alternative file' '
	shit config --file=other-config anwohner.park ausweis &&
	test_cmp expect other-config
'

cat > .shit/config << EOF
# Hallo
	#Bello
[branch "eins"]
	x = 1
[branch.eins]
	y = 1
	[branch "1 234 blabl/a"]
weird
EOF

test_expect_success 'rename section' '
	shit config ${mode_prefix}rename-section branch.eins branch.zwei
'

cat > expect << EOF
# Hallo
	#Bello
[branch "zwei"]
	x = 1
[branch "zwei"]
	y = 1
	[branch "1 234 blabl/a"]
weird
EOF

test_expect_success 'rename succeeded' '
	test_cmp expect .shit/config
'

test_expect_success 'rename non-existing section' '
	test_must_fail shit config ${mode_prefix}rename-section \
		branch."world domination" branch.drei
'

test_expect_success 'rename succeeded' '
	test_cmp expect .shit/config
'

test_expect_success 'rename another section' '
	shit config ${mode_prefix}rename-section branch."1 234 blabl/a" branch.drei
'

cat > expect << EOF
# Hallo
	#Bello
[branch "zwei"]
	x = 1
[branch "zwei"]
	y = 1
[branch "drei"]
weird
EOF

test_expect_success 'rename succeeded' '
	test_cmp expect .shit/config
'

cat >> .shit/config << EOF
[branch "vier"] z = 1
EOF

test_expect_success 'rename a section with a var on the same line' '
	shit config ${mode_prefix}rename-section branch.vier branch.zwei
'

cat > expect << EOF
# Hallo
	#Bello
[branch "zwei"]
	x = 1
[branch "zwei"]
	y = 1
[branch "drei"]
weird
[branch "zwei"]
	z = 1
EOF

test_expect_success 'rename succeeded' '
	test_cmp expect .shit/config
'

test_expect_success 'renaming empty section name is rejected' '
	test_must_fail shit config ${mode_prefix}rename-section branch.zwei ""
'

test_expect_success 'renaming to bogus section is rejected' '
	test_must_fail shit config ${mode_prefix}rename-section branch.zwei "bogus name"
'

test_expect_success 'renaming a section with a long line' '
	{
		printf "[b]\\n" &&
		printf "  c = d %1024s [a] e = f\\n" " " &&
		printf "[a] g = h\\n"
	} >y &&
	shit config ${mode_prefix}rename-section -f y a xyz &&
	test_must_fail shit config -f y b.e
'

test_expect_success 'renaming an embedded section with a long line' '
	{
		printf "[b]\\n" &&
		printf "  c = d %1024s [a] [foo] e = f\\n" " " &&
		printf "[a] g = h\\n"
	} >y &&
	shit config ${mode_prefix}rename-section -f y a xyz &&
	test_must_fail shit config -f y foo.e
'

test_expect_success 'renaming a section with an overly-long line' '
	{
		printf "[b]\\n" &&
		printf "  c = d %525000s e" " " &&
		printf "[a] g = h\\n"
	} >y &&
	test_must_fail shit config ${mode_prefix}rename-section -f y a xyz 2>err &&
	grep "refusing to work with overly long line in .y. on line 2" err
'

cat >> .shit/config << EOF
  [branch "zwei"] a = 1 [branch "vier"]
EOF

test_expect_success 'remove section' '
	shit config ${mode_prefix}remove-section branch.zwei
'

cat > expect << EOF
# Hallo
	#Bello
[branch "drei"]
weird
EOF

test_expect_success 'section was removed properly' '
	test_cmp expect .shit/config
'

cat > expect << EOF
[shitcvs]
	enabled = true
	dbname = %Gshitcvs2.%a.%m.sqlite
[shitcvs "ext"]
	dbname = %Gshitcvs1.%a.%m.sqlite
EOF

test_expect_success 'section ending' '
	rm -f .shit/config &&
	shit config ${mode_set} shitcvs.enabled true &&
	shit config ${mode_set} shitcvs.ext.dbname %Gshitcvs1.%a.%m.sqlite &&
	shit config ${mode_set} shitcvs.dbname %Gshitcvs2.%a.%m.sqlite &&
	test_cmp expect .shit/config

'

test_expect_success numbers '
	shit config ${mode_set} kilo.gram 1k &&
	shit config ${mode_set} mega.ton 1m &&
	echo 1024 >expect &&
	echo 1048576 >>expect &&
	shit config --int --get kilo.gram >actual &&
	shit config --int --get mega.ton >>actual &&
	test_cmp expect actual
'

test_expect_success '--int is at least 64 bits' '
	shit config ${mode_set} giga.watts 121g &&
	echo  >expect &&
	test_cmp_config 129922760704 --int --get giga.watts
'

test_expect_success 'invalid unit' '
	shit config ${mode_set} aninvalid.unit "1auto" &&
	test_cmp_config 1auto aninvalid.unit &&
	test_must_fail shit config --int --get aninvalid.unit 2>actual &&
	test_grep "bad numeric config value .1auto. for .aninvalid.unit. in file .shit/config: invalid unit" actual
'

test_expect_success 'invalid unit boolean' '
	shit config ${mode_set} commit.gpgsign "1true" &&
	test_cmp_config 1true commit.gpgsign &&
	test_must_fail shit config --bool --get commit.gpgsign 2>actual &&
	test_grep "bad boolean config value .1true. for .commit.gpgsign." actual
'

test_expect_success 'line number is reported correctly' '
	printf "[bool]\n\tvar\n" >invalid &&
	test_must_fail shit config -f invalid --path bool.var 2>actual &&
	test_grep "line 2" actual
'

test_expect_success 'invalid stdin config' '
	echo "[broken" | test_must_fail shit config ${mode_prefix}list --file - >output 2>&1 &&
	test_grep "bad config line 1 in standard input" output
'

cat > expect << EOF
true
false
true
false
true
false
true
false
EOF

test_expect_success bool '

	shit config ${mode_set} bool.true1 01 &&
	shit config ${mode_set} bool.true2 -1 &&
	shit config ${mode_set} bool.true3 YeS &&
	shit config ${mode_set} bool.true4 true &&
	shit config ${mode_set} bool.false1 000 &&
	shit config ${mode_set} bool.false2 "" &&
	shit config ${mode_set} bool.false3 nO &&
	shit config ${mode_set} bool.false4 FALSE &&
	rm -f result &&
	for i in 1 2 3 4
	do
	    shit config --bool --get bool.true$i >>result &&
	    shit config --bool --get bool.false$i >>result || return 1
	done &&
	test_cmp expect result'

test_expect_success 'invalid bool (--get)' '

	shit config ${mode_set} bool.nobool foobar &&
	test_must_fail shit config --bool --get bool.nobool'

test_expect_success 'invalid bool (set)' '

	test_must_fail shit config --bool bool.nobool foobar'

cat > expect <<\EOF
[bool]
	true1 = true
	true2 = true
	true3 = true
	true4 = true
	false1 = false
	false2 = false
	false3 = false
	false4 = false
EOF

test_expect_success 'set --bool' '

	rm -f .shit/config &&
	shit config --bool bool.true1 01 &&
	shit config --bool bool.true2 -1 &&
	shit config --bool bool.true3 YeS &&
	shit config --bool bool.true4 true &&
	shit config --bool bool.false1 000 &&
	shit config --bool bool.false2 "" &&
	shit config --bool bool.false3 nO &&
	shit config --bool bool.false4 FALSE &&
	test_cmp expect .shit/config'

cat > expect <<\EOF
[int]
	val1 = 1
	val2 = -1
	val3 = 5242880
EOF

test_expect_success 'set --int' '

	rm -f .shit/config &&
	shit config --int int.val1 01 &&
	shit config --int int.val2 -1 &&
	shit config --int int.val3 5m &&
	test_cmp expect .shit/config
'

test_expect_success 'get --bool-or-int' '
	cat >.shit/config <<-\EOF &&
	[bool]
	true1
	true2 = true
	false = false
	[int]
	int1 = 0
	int2 = 1
	int3 = -1
	EOF
	cat >expect <<-\EOF &&
	true
	true
	false
	0
	1
	-1
	EOF
	{
		shit config --bool-or-int bool.true1 &&
		shit config --bool-or-int bool.true2 &&
		shit config --bool-or-int bool.false &&
		shit config --bool-or-int int.int1 &&
		shit config --bool-or-int int.int2 &&
		shit config --bool-or-int int.int3
	} >actual &&
	test_cmp expect actual
'

cat >expect <<\EOF
[bool]
	true1 = true
	false1 = false
	true2 = true
	false2 = false
[int]
	int1 = 0
	int2 = 1
	int3 = -1
EOF

test_expect_success 'set --bool-or-int' '
	rm -f .shit/config &&
	shit config --bool-or-int bool.true1 true &&
	shit config --bool-or-int bool.false1 false &&
	shit config --bool-or-int bool.true2 yes &&
	shit config --bool-or-int bool.false2 no &&
	shit config --bool-or-int int.int1 0 &&
	shit config --bool-or-int int.int2 1 &&
	shit config --bool-or-int int.int3 -1 &&
	test_cmp expect .shit/config
'

cat >expect <<\EOF
[path]
	home = ~/
	normal = /dev/null
	trailingtilde = foo~
EOF

test_expect_success !MINGW 'set --path' '
	rm -f .shit/config &&
	shit config --path path.home "~/" &&
	shit config --path path.normal "/dev/null" &&
	shit config --path path.trailingtilde "foo~" &&
	test_cmp expect .shit/config'

if test_have_prereq !MINGW && test "${HOME+set}"
then
	test_set_prereq HOMEVAR
fi

cat >expect <<EOF
$HOME/
/dev/null
foo~
EOF

test_expect_success HOMEVAR 'get --path' '
	shit config --get --path path.home > result &&
	shit config --get --path path.normal >> result &&
	shit config --get --path path.trailingtilde >> result &&
	test_cmp expect result
'

cat >expect <<\EOF
/dev/null
foo~
EOF

test_expect_success !MINGW 'get --path copes with unset $HOME' '
	(
		sane_unset HOME &&
		test_must_fail shit config --get --path path.home \
			>result 2>msg &&
		shit config --get --path path.normal >>result &&
		shit config --get --path path.trailingtilde >>result
	) &&
	test_grep "[Ff]ailed to expand.*~/" msg &&
	test_cmp expect result
'

test_expect_success 'get --path barfs on boolean variable' '
	echo "[path]bool" >.shit/config &&
	test_must_fail shit config --get --path path.bool
'

test_expect_success 'get --expiry-date' '
	rel="3.weeks.5.days.00:00" &&
	rel_out="$rel ->" &&
	cat >.shit/config <<-\EOF &&
	[date]
	valid1 = "3.weeks.5.days 00:00"
	valid2 = "Fri Jun 4 15:46:55 2010"
	valid3 = "2017/11/11 11:11:11PM"
	valid4 = "2017/11/10 09:08:07 PM"
	valid5 = "never"
	invalid1 = "abc"
	EOF
	cat >expect <<-EOF &&
	$(test-tool date timestamp $rel)
	1275666415
	1510441871
	1510348087
	0
	EOF
	: "work around heredoc parsing bug fixed in dash 0.5.7 (in ec2c84d)" &&
	{
		echo "$rel_out $(shit config --expiry-date date.valid1)" &&
		shit config --expiry-date date.valid2 &&
		shit config --expiry-date date.valid3 &&
		shit config --expiry-date date.valid4 &&
		shit config --expiry-date date.valid5
	} >actual &&
	test_cmp expect actual &&
	test_must_fail shit config --expiry-date date.invalid1
'

test_expect_success 'get --type=color' '
	rm .shit/config &&
	shit config ${mode_set} foo.color "red" &&
	shit config --get --type=color foo.color >actual.raw &&
	test_decode_color <actual.raw >actual &&
	echo "<RED>" >expect &&
	test_cmp expect actual
'

cat >expect << EOF
[foo]
	color = red
EOF

test_expect_success 'set --type=color' '
	rm .shit/config &&
	shit config --type=color foo.color "red" &&
	test_cmp expect .shit/config
'

test_expect_success 'get --type=color barfs on non-color' '
	echo "[foo]bar=not-a-color" >.shit/config &&
	test_must_fail shit config --get --type=color foo.bar
'

test_expect_success 'set --type=color barfs on non-color' '
	test_must_fail shit config --type=color foo.color "not-a-color" 2>error &&
	test_grep "cannot parse color" error
'

cat > expect << EOF
[quote]
	leading = " test"
	ending = "test "
	semicolon = "test;test"
	hash = "test#test"
EOF
test_expect_success 'quoting' '
	rm -f .shit/config &&
	shit config ${mode_set} quote.leading " test" &&
	shit config ${mode_set} quote.ending "test " &&
	shit config ${mode_set} quote.semicolon "test;test" &&
	shit config ${mode_set} quote.hash "test#test" &&
	test_cmp expect .shit/config
'

test_expect_success 'key with newline' '
	test_must_fail shit config ${mode_get} "key.with
newline" 123'

test_expect_success 'value with newline' 'shit config ${mode_set} key.sub value.with\\\
newline'

cat > .shit/config <<\EOF
[section]
	; comment \
	continued = cont\
inued
	noncont   = not continued ; \
	quotecont = "cont;\
inued"
EOF

cat > expect <<\EOF
section.continued=continued
section.noncont=not continued
section.quotecont=cont;inued
EOF

test_expect_success 'value continued on next line' '
	shit config ${mode_prefix}list > result &&
	test_cmp expect result
'

cat > .shit/config <<\EOF
[section "sub=section"]
	val1 = foo=bar
	val2 = foo\nbar
	val3 = \n\n
	val4 =
	val5
EOF

cat > expect <<\EOF
section.sub=section.val1
foo=barQsection.sub=section.val2
foo
barQsection.sub=section.val3


Qsection.sub=section.val4
Qsection.sub=section.val5Q
EOF
test_expect_success '--null --list' '
	shit config ${mode_prefix}list --null >result.raw &&
	nul_to_q <result.raw >result &&
	echo >>result &&
	test_cmp expect result
'

test_expect_success '--null --get-regexp' '
	shit config ${mode_get_regexp} --null "val[0-9]" >result.raw &&
	nul_to_q <result.raw >result &&
	echo >>result &&
	test_cmp expect result
'

test_expect_success 'inner whitespace kept verbatim, spaces only' '
	echo "foo   bar" >expect &&
	shit config ${mode_set} section.val "foo   bar" &&
	shit config ${mode_get} section.val >actual &&
	test_cmp expect actual
'

test_expect_success 'inner whitespace kept verbatim, horizontal tabs only' '
	echo "fooQQbar" | q_to_tab >expect &&
	shit config ${mode_set} section.val "$(cat expect)" &&
	shit config ${mode_get} section.val >actual &&
	test_cmp expect actual
'

test_expect_success 'inner whitespace kept verbatim, horizontal tabs and spaces' '
	echo "foo Q  bar" | q_to_tab >expect &&
	shit config ${mode_set} section.val "$(cat expect)" &&
	shit config ${mode_get} section.val >actual &&
	test_cmp expect actual
'

test_expect_success SYMLINKS 'symlinked configuration' '
	test_when_finished "rm myconfig" &&
	ln -s notyet myconfig &&
	shit config --file=myconfig test.frotz nitfol &&
	test -h myconfig &&
	test -f notyet &&
	test "z$(shit config --file=notyet test.frotz)" = znitfol &&
	shit config --file=myconfig test.xyzzy rezrov &&
	test -h myconfig &&
	test -f notyet &&
	cat >expect <<-\EOF &&
	nitfol
	rezrov
	EOF
	{
		shit config --file=notyet test.frotz &&
		shit config --file=notyet test.xyzzy
	} >actual &&
	test_cmp expect actual
'

test_expect_success SYMLINKS 'symlink to nonexistent configuration' '
	test_when_finished "rm linktonada linktolinktonada" &&
	ln -s doesnotexist linktonada &&
	ln -s linktonada linktolinktonada &&
	test_must_fail shit config ${mode_prefix}list --file=linktonada &&
	test_must_fail shit config ${mode_prefix}list --file=linktolinktonada
'

test_expect_success 'check split_cmdline return' '
	test_when_finished "rm -rf repo" &&
	shit init repo &&
	(
		cd repo &&
		shit config ${mode_set} alias.split-cmdline-fix "echo \"" &&
		test_must_fail shit split-cmdline-fix &&
		echo foo >foo &&
		shit add foo &&
		shit commit -m "initial commit" &&
		shit config ${mode_set} branch.main.mergeoptions "echo \"" &&
		test_must_fail shit merge main
	)
'

test_expect_success 'shit -c "key=value" support' '
	cat >expect <<-\EOF &&
	value
	value
	true
	EOF
	{
		shit -c section.name=value config section.name &&
		shit -c foo.CamelCase=value config foo.camelcase &&
		shit -c foo.flag config --bool foo.flag
	} >actual &&
	test_cmp expect actual &&
	test_must_fail shit -c name=value config section.name
'

# We just need a type-specifier here that cares about the
# distinction internally between a NULL boolean and a real
# string (because most of shit's internal parsers do care).
# Using "--path" works, but we do not otherwise care about
# its semantics.
test_expect_success 'shit -c can represent empty string' '
	echo >expect &&
	shit -c foo.empty= config --path foo.empty >actual &&
	test_cmp expect actual
'

test_expect_success 'key sanity-checking' '
	test_must_fail shit config ${mode_get} foo=bar &&
	test_must_fail shit config ${mode_get} foo=.bar &&
	test_must_fail shit config ${mode_get} foo.ba=r &&
	test_must_fail shit config ${mode_get} foo.1bar &&
	test_must_fail shit config ${mode_get} foo."ba
				z".bar &&
	test_must_fail shit config ${mode_set} . false &&
	test_must_fail shit config ${mode_set} .foo false &&
	test_must_fail shit config ${mode_set} foo. false &&
	test_must_fail shit config ${mode_set} .foo. false &&
	shit config ${mode_set} foo.bar true &&
	shit config ${mode_set} foo."ba =z".bar false
'

test_expect_success 'shit -c works with aliases of builtins' '
	shit config alias.checkconfig "-c foo.check=bar config foo.check" &&
	echo bar >expect &&
	shit checkconfig >actual &&
	test_cmp expect actual
'

test_expect_success 'aliases can be CamelCased' '
	test_when_finished "rm -rf repo" &&
	shit init repo &&
	(
		cd repo &&
		test_commit A &&
		shit config alias.CamelCased "rev-parse HEAD" &&
		shit CamelCased >out &&
		shit rev-parse HEAD >expect &&
		test_cmp expect out
	)
'

test_expect_success 'shit -c does not split values on equals' '
	echo "value with = in it" >expect &&
	shit -c section.foo="value with = in it" config section.foo >actual &&
	test_cmp expect actual
'

test_expect_success 'shit -c dies on bogus config' '
	test_must_fail shit -c core.bare=foo rev-parse
'

test_expect_success 'shit -c complains about empty key' '
	test_must_fail shit -c "=foo" rev-parse
'

test_expect_success 'shit -c complains about empty key and value' '
	test_must_fail shit -c "" rev-parse
'

test_expect_success 'multiple shit -c appends config' '
	test_config alias.x "!shit -c x.two=2 config ${mode_get_regexp} ^x\.*" &&
	cat >expect <<-\EOF &&
	x.one 1
	x.two 2
	EOF
	shit -c x.one=1 x >actual &&
	test_cmp expect actual
'

test_expect_success 'last one wins: two level vars' '

	# sec.var and sec.VAR are the same variable, as the first
	# and the last level of a configuration variable name is
	# case insensitive.

	echo VAL >expect &&

	shit -c sec.var=val -c sec.VAR=VAL config --get sec.var >actual &&
	test_cmp expect actual &&
	shit -c SEC.var=val -c sec.var=VAL config --get sec.var >actual &&
	test_cmp expect actual &&

	shit -c sec.var=val -c sec.VAR=VAL config --get SEC.var >actual &&
	test_cmp expect actual &&
	shit -c SEC.var=val -c sec.var=VAL config --get sec.VAR >actual &&
	test_cmp expect actual
'

test_expect_success 'last one wins: three level vars' '

	# v.a.r and v.A.r are not the same variable, as the middle
	# level of a three-level configuration variable name is
	# case sensitive.

	echo val >expect &&
	shit -c v.a.r=val -c v.A.r=VAL config --get v.a.r >actual &&
	test_cmp expect actual &&
	shit -c v.a.r=val -c v.A.r=VAL config --get V.a.R >actual &&
	test_cmp expect actual &&

	# v.a.r and V.a.R are the same variable, as the first
	# and the last level of a configuration variable name is
	# case insensitive.

	echo VAL >expect &&
	shit -c v.a.r=val -c v.a.R=VAL config --get v.a.r >actual &&
	test_cmp expect actual &&
	shit -c v.a.r=val -c V.a.r=VAL config --get v.a.r >actual &&
	test_cmp expect actual &&
	shit -c v.a.r=val -c v.a.R=VAL config --get V.a.R >actual &&
	test_cmp expect actual &&
	shit -c v.a.r=val -c V.a.r=VAL config --get V.a.R >actual &&
	test_cmp expect actual
'

test_expect_success 'old-fashioned settings are case insensitive' '
	test_when_finished "rm -f testConfig testConfig_expect testConfig_actual" &&

	cat >testConfig_actual <<-EOF &&
	[V.A]
	r = value1
	EOF
	q_to_tab >testConfig_expect <<-EOF &&
	[V.A]
	Qr = value2
	EOF
	shit config -f testConfig_actual "v.a.r" value2 &&
	test_cmp testConfig_expect testConfig_actual &&

	cat >testConfig_actual <<-EOF &&
	[V.A]
	r = value1
	EOF
	q_to_tab >testConfig_expect <<-EOF &&
	[V.A]
	QR = value2
	EOF
	shit config -f testConfig_actual "V.a.R" value2 &&
	test_cmp testConfig_expect testConfig_actual &&

	cat >testConfig_actual <<-EOF &&
	[V.A]
	r = value1
	EOF
	q_to_tab >testConfig_expect <<-EOF &&
	[V.A]
	r = value1
	Qr = value2
	EOF
	shit config -f testConfig_actual "V.A.r" value2 &&
	test_cmp testConfig_expect testConfig_actual &&

	cat >testConfig_actual <<-EOF &&
	[V.A]
	r = value1
	EOF
	q_to_tab >testConfig_expect <<-EOF &&
	[V.A]
	r = value1
	Qr = value2
	EOF
	shit config -f testConfig_actual "v.A.r" value2 &&
	test_cmp testConfig_expect testConfig_actual
'

test_expect_success 'setting different case sensitive subsections ' '
	test_when_finished "rm -f testConfig testConfig_expect testConfig_actual" &&

	cat >testConfig_actual <<-EOF &&
	[V "A"]
	R = v1
	[K "E"]
	Y = v1
	[a "b"]
	c = v1
	[d "e"]
	f = v1
	EOF
	q_to_tab >testConfig_expect <<-EOF &&
	[V "A"]
	Qr = v2
	[K "E"]
	Qy = v2
	[a "b"]
	Qc = v2
	[d "e"]
	f = v1
	[d "E"]
	Qf = v2
	EOF
	# exact match
	shit config -f testConfig_actual a.b.c v2 &&
	# match section and subsection, key is cased differently.
	shit config -f testConfig_actual K.E.y v2 &&
	# section and key are matched case insensitive, but subsection needs
	# to match; When writing out new values only the key is adjusted
	shit config -f testConfig_actual v.A.r v2 &&
	# subsection is not matched:
	shit config -f testConfig_actual d.E.f v2 &&
	test_cmp testConfig_expect testConfig_actual
'

for VAR in a .a a. a.0b a."b c". a."b c".0d
do
	test_expect_success "shit -c $VAR=VAL rejects invalid '$VAR'" '
		test_must_fail shit -c "$VAR=VAL" config -l
	'
done

for VAR in a.b a."b c".d
do
	test_expect_success "shit -c $VAR=VAL works with valid '$VAR'" '
		echo VAL >expect &&
		shit -c "$VAR=VAL" config --get "$VAR" >actual &&
		test_cmp expect actual
	'
done

test_expect_success 'shit -c is not confused by empty environment' '
	shit_CONFIG_PARAMETERS="" shit -c x.one=1 config ${mode_prefix}list
'

test_expect_success 'shit_CONFIG_PARAMETERS handles old-style entries' '
	v="${SQ}key.one=foo${SQ}" &&
	v="$v  ${SQ}key.two=bar${SQ}" &&
	v="$v ${SQ}key.ambiguous=section.whatever=value${SQ}" &&
	shit_CONFIG_PARAMETERS=$v shit config ${mode_get_regexp} "key.*" >actual &&
	cat >expect <<-EOF &&
	key.one foo
	key.two bar
	key.ambiguous section.whatever=value
	EOF
	test_cmp expect actual
'

test_expect_success 'shit_CONFIG_PARAMETERS handles new-style entries' '
	v="${SQ}key.one${SQ}=${SQ}foo${SQ}" &&
	v="$v  ${SQ}key.two${SQ}=${SQ}bar${SQ}" &&
	v="$v ${SQ}key.ambiguous=section.whatever${SQ}=${SQ}value${SQ}" &&
	shit_CONFIG_PARAMETERS=$v shit config ${mode_get_regexp} "key.*" >actual &&
	cat >expect <<-EOF &&
	key.one foo
	key.two bar
	key.ambiguous=section.whatever value
	EOF
	test_cmp expect actual
'

test_expect_success 'old and new-style entries can mix' '
	v="${SQ}key.oldone=oldfoo${SQ}" &&
	v="$v ${SQ}key.newone${SQ}=${SQ}newfoo${SQ}" &&
	v="$v ${SQ}key.oldtwo=oldbar${SQ}" &&
	v="$v ${SQ}key.newtwo${SQ}=${SQ}newbar${SQ}" &&
	shit_CONFIG_PARAMETERS=$v shit config ${mode_get_regexp} "key.*" >actual &&
	cat >expect <<-EOF &&
	key.oldone oldfoo
	key.newone newfoo
	key.oldtwo oldbar
	key.newtwo newbar
	EOF
	test_cmp expect actual
'

test_expect_success 'old and new bools with ambiguous subsection' '
	v="${SQ}key.with=equals.oldbool${SQ}" &&
	v="$v ${SQ}key.with=equals.newbool${SQ}=" &&
	shit_CONFIG_PARAMETERS=$v shit config ${mode_get_regexp} "key.*" >actual &&
	cat >expect <<-EOF &&
	key.with equals.oldbool
	key.with=equals.newbool
	EOF
	test_cmp expect actual
'

test_expect_success 'detect bogus shit_CONFIG_PARAMETERS' '
	cat >expect <<-\EOF &&
	env.one one
	env.two two
	EOF
	shit_CONFIG_PARAMETERS="${SQ}env.one=one${SQ} ${SQ}env.two=two${SQ}" \
		shit config ${mode_get_regexp} "env.*" >actual &&
	test_cmp expect actual &&

	cat >expect <<-EOF &&
	env.one one${SQ}
	env.two two
	EOF
	shit_CONFIG_PARAMETERS="${SQ}env.one=one${SQ}\\$SQ$SQ$SQ ${SQ}env.two=two${SQ}" \
		shit config ${mode_get_regexp} "env.*" >actual &&
	test_cmp expect actual &&

	test_must_fail env \
		shit_CONFIG_PARAMETERS="${SQ}env.one=one${SQ}\\$SQ ${SQ}env.two=two${SQ}" \
		shit config ${mode_get_regexp} "env.*"
'

test_expect_success 'shit --config-env=key=envvar support' '
	cat >expect <<-\EOF &&
	value
	value
	value
	value
	false
	false
	EOF
	{
		ENVVAR=value shit --config-env=core.name=ENVVAR config core.name &&
		ENVVAR=value shit --config-env core.name=ENVVAR config core.name &&
		ENVVAR=value shit --config-env=foo.CamelCase=ENVVAR config foo.camelcase &&
		ENVVAR=value shit --config-env foo.CamelCase=ENVVAR config foo.camelcase &&
		ENVVAR= shit --config-env=foo.flag=ENVVAR config --bool foo.flag &&
		ENVVAR= shit --config-env foo.flag=ENVVAR config --bool foo.flag
	} >actual &&
	test_cmp expect actual
'

test_expect_success 'shit --config-env with missing value' '
	test_must_fail env ENVVAR=value shit --config-env 2>error &&
	grep "no config key given for --config-env" error &&
	test_must_fail env ENVVAR=value shit --config-env config core.name 2>error &&
	grep "invalid config format: config" error
'

test_expect_success 'shit --config-env fails with invalid parameters' '
	test_must_fail shit --config-env=foo.flag config --bool foo.flag 2>error &&
	test_grep "invalid config format: foo.flag" error &&
	test_must_fail shit --config-env=foo.flag= config --bool foo.flag 2>error &&
	test_grep "missing environment variable name for configuration ${SQ}foo.flag${SQ}" error &&
	sane_unset NONEXISTENT &&
	test_must_fail shit --config-env=foo.flag=NONEXISTENT config --bool foo.flag 2>error &&
	test_grep "missing environment variable ${SQ}NONEXISTENT${SQ} for configuration ${SQ}foo.flag${SQ}" error
'

test_expect_success 'shit -c and --config-env work together' '
	cat >expect <<-\EOF &&
	bar.cmd cmd-value
	bar.env env-value
	EOF
	ENVVAR=env-value shit \
		-c bar.cmd=cmd-value \
		--config-env=bar.env=ENVVAR \
		config ${mode_get_regexp} "^bar.*" >actual &&
	test_cmp expect actual
'

test_expect_success 'shit -c and --config-env override each other' '
	cat >expect <<-\EOF &&
	env
	cmd
	EOF
	{
		ENVVAR=env shit -c bar.bar=cmd --config-env=bar.bar=ENVVAR config bar.bar &&
		ENVVAR=env shit --config-env=bar.bar=ENVVAR -c bar.bar=cmd config bar.bar
	} >actual &&
	test_cmp expect actual
'

test_expect_success '--config-env handles keys with equals' '
	echo value=with=equals >expect &&
	ENVVAR=value=with=equals shit \
		--config-env=section.subsection=with=equals.key=ENVVAR \
		config section.subsection=with=equals.key >actual &&
	test_cmp expect actual
'

test_expect_success 'shit config handles environment config pairs' '
	shit_CONFIG_COUNT=2 \
		shit_CONFIG_KEY_0="pair.one" shit_CONFIG_VALUE_0="foo" \
		shit_CONFIG_KEY_1="pair.two" shit_CONFIG_VALUE_1="bar" \
		shit config ${mode_get_regexp} "pair.*" >actual &&
	cat >expect <<-EOF &&
	pair.one foo
	pair.two bar
	EOF
	test_cmp expect actual
'

test_expect_success 'shit config ignores pairs without count' '
	test_must_fail env shit_CONFIG_KEY_0="pair.one" shit_CONFIG_VALUE_0="value" \
		shit config ${mode_get} pair.one 2>error &&
	test_must_be_empty error
'

test_expect_success 'shit config ignores pairs exceeding count' '
	shit_CONFIG_COUNT=1 \
		shit_CONFIG_KEY_0="pair.one" shit_CONFIG_VALUE_0="value" \
		shit_CONFIG_KEY_1="pair.two" shit_CONFIG_VALUE_1="value" \
		shit config ${mode_get_regexp} "pair.*" >actual 2>error &&
	cat >expect <<-EOF &&
	pair.one value
	EOF
	test_cmp expect actual &&
	test_must_be_empty error
'

test_expect_success 'shit config ignores pairs with zero count' '
	test_must_fail env \
		shit_CONFIG_COUNT=0 shit_CONFIG_KEY_0="pair.one" shit_CONFIG_VALUE_0="value" \
		shit config ${mode_get} pair.one 2>error &&
	test_must_be_empty error
'

test_expect_success 'shit config ignores pairs with empty count' '
	test_must_fail env \
		shit_CONFIG_COUNT= shit_CONFIG_KEY_0="pair.one" shit_CONFIG_VALUE_0="value" \
		shit config ${mode_get} pair.one 2>error &&
	test_must_be_empty error
'

test_expect_success 'shit config fails with invalid count' '
	test_must_fail env shit_CONFIG_COUNT=10a shit config ${mode_prefix}list 2>error &&
	test_grep "bogus count" error &&
	test_must_fail env shit_CONFIG_COUNT=9999999999999999 shit config ${mode_prefix}list 2>error &&
	test_grep "too many entries" error
'

test_expect_success 'shit config fails with missing config key' '
	test_must_fail env shit_CONFIG_COUNT=1 shit_CONFIG_VALUE_0="value" \
		shit config ${mode_prefix}list 2>error &&
	test_grep "missing config key" error
'

test_expect_success 'shit config fails with missing config value' '
	test_must_fail env shit_CONFIG_COUNT=1 shit_CONFIG_KEY_0="pair.one" \
		shit config ${mode_prefix}list 2>error &&
	test_grep "missing config value" error
'

test_expect_success 'shit config fails with invalid config pair key' '
	test_must_fail env shit_CONFIG_COUNT=1 \
		shit_CONFIG_KEY_0= shit_CONFIG_VALUE_0=value \
		shit config ${mode_prefix}list &&
	test_must_fail env shit_CONFIG_COUNT=1 \
		shit_CONFIG_KEY_0=missing-section shit_CONFIG_VALUE_0=value \
		shit config ${mode_prefix}list
'

test_expect_success 'environment overrides config file' '
	test_when_finished "rm -f .shit/config" &&
	cat >.shit/config <<-EOF &&
	[pair]
	one = value
	EOF
	shit_CONFIG_COUNT=1 shit_CONFIG_KEY_0=pair.one shit_CONFIG_VALUE_0=override \
		shit config ${mode_get} pair.one >actual &&
	cat >expect <<-EOF &&
	override
	EOF
	test_cmp expect actual
'

test_expect_success 'shit_CONFIG_PARAMETERS overrides environment config' '
	shit_CONFIG_COUNT=1 shit_CONFIG_KEY_0=pair.one shit_CONFIG_VALUE_0=value \
		shit_CONFIG_PARAMETERS="${SQ}pair.one=override${SQ}" \
		shit config ${mode_get} pair.one >actual &&
	cat >expect <<-EOF &&
	override
	EOF
	test_cmp expect actual
'

test_expect_success 'command line overrides environment config' '
	shit_CONFIG_COUNT=1 shit_CONFIG_KEY_0=pair.one shit_CONFIG_VALUE_0=value \
		shit -c pair.one=override config pair.one >actual &&
	cat >expect <<-EOF &&
	override
	EOF
	test_cmp expect actual
'

test_expect_success 'shit config --edit works' '
	shit config -f tmp test.value no &&
	echo test.value=yes >expect &&
	shit_EDITOR="echo [test]value=yes >" shit config ${mode_prefix}edit -f tmp &&
	shit config ${mode_prefix}list -f tmp >actual &&
	test_cmp expect actual
'

test_expect_success 'shit config --edit respects core.editor' '
	shit config -f tmp test.value no &&
	echo test.value=yes >expect &&
	test_config core.editor "echo [test]value=yes >" &&
	shit config ${mode_prefix}edit -f tmp &&
	shit config ${mode_prefix}list -f tmp >actual &&
	test_cmp expect actual
'

# malformed configuration files
test_expect_success 'barf on syntax error' '
	cat >.shit/config <<-\EOF &&
	# broken key=value
	[section]
	key garbage
	EOF
	test_must_fail shit config --get section.key 2>error &&
	test_grep " line 3 " error
'

test_expect_success 'barf on incomplete section header' '
	cat >.shit/config <<-\EOF &&
	# broken section line
	[section
	key = value
	EOF
	test_must_fail shit config --get section.key 2>error &&
	test_grep " line 2 " error
'

test_expect_success 'barf on incomplete string' '
	cat >.shit/config <<-\EOF &&
	# broken value string
	[section]
	key = "value string
	EOF
	test_must_fail shit config --get section.key 2>error &&
	test_grep " line 3 " error
'

test_expect_success 'urlmatch' '
	cat >.shit/config <<-\EOF &&
	[http]
		sslVerify
	[http "https://weak.example.com"]
		sslVerify = false
		cookieFile = /tmp/cookie.txt
	EOF

	test_expect_code 1 shit config --bool --get-urlmatch doesnt.exist https://good.example.com >actual &&
	test_must_be_empty actual &&
	test_expect_code 1 shit config get --url=https://good.example.com --bool doesnt.exist >actual &&
	test_must_be_empty actual &&

	echo true >expect &&
	shit config --bool --get-urlmatch http.SSLverify https://good.example.com >actual &&
	test_cmp expect actual &&
	shit config get --bool --url=https://good.example.com http.SSLverify >actual &&
	test_cmp expect actual &&

	echo false >expect &&
	shit config --bool --get-urlmatch http.sslverify https://weak.example.com >actual &&
	test_cmp expect actual &&
	shit config get --bool --url=https://weak.example.com http.sslverify >actual &&
	test_cmp expect actual &&

	{
		echo http.cookiefile /tmp/cookie.txt &&
		echo http.sslverify false
	} >expect &&
	shit config --get-urlmatch HTTP https://weak.example.com >actual &&
	test_cmp expect actual &&
	shit config get --url=https://weak.example.com HTTP >actual &&
	test_cmp expect actual
'

test_expect_success 'urlmatch with --show-scope' '
	cat >.shit/config <<-\EOF &&
	[http "https://weak.example.com"]
		sslVerify = false
		cookieFile = /tmp/cookie.txt
	EOF

	cat >expect <<-EOF &&
	local	http.cookiefile /tmp/cookie.txt
	local	http.sslverify false
	EOF
	shit config --get-urlmatch --show-scope HTTP https://weak.example.com >actual &&
	test_cmp expect actual &&
	shit config get --url=https://weak.example.com --show-scope HTTP >actual &&
	test_cmp expect actual
'

test_expect_success 'urlmatch favors more specific URLs' '
	cat >.shit/config <<-\EOF &&
	[http "https://example.com/"]
		cookieFile = /tmp/root.txt
	[http "https://example.com/subdirectory"]
		cookieFile = /tmp/subdirectory.txt
	[http "https://user@example.com/"]
		cookieFile = /tmp/user.txt
	[http "https://averylonguser@example.com/"]
		cookieFile = /tmp/averylonguser.txt
	[http "https://preceding.example.com"]
		cookieFile = /tmp/preceding.txt
	[http "https://*.example.com"]
		cookieFile = /tmp/wildcard.txt
	[http "https://*.example.com/wildcardwithsubdomain"]
		cookieFile = /tmp/wildcardwithsubdomain.txt
	[http "https://*.example.*"]
		cookieFile = /tmp/multiwildcard.txt
	[http "https://trailing.example.com"]
		cookieFile = /tmp/trailing.txt
	[http "https://user@*.example.com/"]
		cookieFile = /tmp/wildcardwithuser.txt
	[http "https://sub.example.com/"]
		cookieFile = /tmp/sub.txt
	EOF

	echo http.cookiefile /tmp/root.txt >expect &&
	shit config --get-urlmatch HTTP https://example.com >actual &&
	test_cmp expect actual &&
	shit config get --url=https://example.com HTTP >actual &&
	test_cmp expect actual &&

	echo http.cookiefile /tmp/subdirectory.txt >expect &&
	shit config --get-urlmatch HTTP https://example.com/subdirectory >actual &&
	test_cmp expect actual &&
	shit config get --url=https://example.com/subdirectory HTTP >actual &&
	test_cmp expect actual &&

	echo http.cookiefile /tmp/subdirectory.txt >expect &&
	shit config --get-urlmatch HTTP https://example.com/subdirectory/nested >actual &&
	test_cmp expect actual &&
	shit config get --url=https://example.com/subdirectory/nested HTTP >actual &&
	test_cmp expect actual &&

	echo http.cookiefile /tmp/user.txt >expect &&
	shit config --get-urlmatch HTTP https://user@example.com/ >actual &&
	test_cmp expect actual &&
	shit config get --url=https://user@example.com/ HTTP >actual &&
	test_cmp expect actual &&

	echo http.cookiefile /tmp/subdirectory.txt >expect &&
	shit config --get-urlmatch HTTP https://averylonguser@example.com/subdirectory >actual &&
	test_cmp expect actual &&
	shit config get --url=https://averylonguser@example.com/subdirectory HTTP >actual &&
	test_cmp expect actual &&

	echo http.cookiefile /tmp/preceding.txt >expect &&
	shit config --get-urlmatch HTTP https://preceding.example.com >actual &&
	test_cmp expect actual &&
	shit config get --url=https://preceding.example.com HTTP >actual &&
	test_cmp expect actual &&

	echo http.cookiefile /tmp/wildcard.txt >expect &&
	shit config --get-urlmatch HTTP https://wildcard.example.com >actual &&
	test_cmp expect actual &&
	shit config get --url=https://wildcard.example.com HTTP >actual &&
	test_cmp expect actual &&

	echo http.cookiefile /tmp/sub.txt >expect &&
	shit config --get-urlmatch HTTP https://sub.example.com/wildcardwithsubdomain >actual &&
	test_cmp expect actual &&
	shit config get --url=https://sub.example.com/wildcardwithsubdomain HTTP >actual &&
	test_cmp expect actual &&

	echo http.cookiefile /tmp/trailing.txt >expect &&
	shit config --get-urlmatch HTTP https://trailing.example.com >actual &&
	test_cmp expect actual &&
	shit config get --url=https://trailing.example.com HTTP >actual &&
	test_cmp expect actual &&

	echo http.cookiefile /tmp/sub.txt >expect &&
	shit config --get-urlmatch HTTP https://user@sub.example.com >actual &&
	test_cmp expect actual &&
	shit config get --url=https://user@sub.example.com HTTP >actual &&
	test_cmp expect actual &&

	echo http.cookiefile /tmp/multiwildcard.txt >expect &&
	shit config --get-urlmatch HTTP https://wildcard.example.org >actual &&
	test_cmp expect actual &&
	shit config get --url=https://wildcard.example.org HTTP >actual &&
	test_cmp expect actual
'

test_expect_success 'urlmatch with wildcard' '
	cat >.shit/config <<-\EOF &&
	[http]
		sslVerify
	[http "https://*.example.com"]
		sslVerify = false
		cookieFile = /tmp/cookie.txt
	EOF

	test_expect_code 1 shit config --bool --get-urlmatch doesnt.exist https://good.example.com >actual &&
	test_must_be_empty actual &&

	echo true >expect &&
	shit config --bool --get-urlmatch http.SSLverify https://example.com >actual &&
	test_cmp expect actual &&

	echo true >expect &&
	shit config --bool --get-urlmatch http.SSLverify https://good-example.com >actual &&
	test_cmp expect actual &&

	echo true >expect &&
	shit config --bool --get-urlmatch http.sslverify https://deep.nested.example.com >actual &&
	test_cmp expect actual &&

	echo false >expect &&
	shit config --bool --get-urlmatch http.sslverify https://good.example.com >actual &&
	test_cmp expect actual &&

	{
		echo http.cookiefile /tmp/cookie.txt &&
		echo http.sslverify false
	} >expect &&
	shit config --get-urlmatch HTTP https://good.example.com >actual &&
	test_cmp expect actual &&

	echo http.sslverify >expect &&
	shit config --get-urlmatch HTTP https://more.example.com.au >actual &&
	test_cmp expect actual
'

# good section hygiene
test_expect_success '--unset last key removes section (except if commented)' '
	cat >.shit/config <<-\EOF &&
	# some generic comment on the configuration file itself
	# a comment specific to this "section" section.
	[section]
	# some intervening lines
	# that should also be dropped

	key = value
	# please be careful when you update the above variable
	EOF

	cat >expect <<-\EOF &&
	# some generic comment on the configuration file itself
	# a comment specific to this "section" section.
	[section]
	# some intervening lines
	# that should also be dropped

	# please be careful when you update the above variable
	EOF

	shit config ${mode_unset} section.key &&
	test_cmp expect .shit/config &&

	cat >.shit/config <<-\EOF &&
	[section]
	key = value
	[next-section]
	EOF

	cat >expect <<-\EOF &&
	[next-section]
	EOF

	shit config ${mode_unset} section.key &&
	test_cmp expect .shit/config &&

	q_to_tab >.shit/config <<-\EOF &&
	[one]
	Qkey = "multiline \
	QQ# with comment"
	[two]
	key = true
	EOF
	shit config ${mode_unset} two.key &&
	! grep two .shit/config &&

	q_to_tab >.shit/config <<-\EOF &&
	[one]
	Qkey = "multiline \
	QQ# with comment"
	[one]
	key = true
	EOF
	shit config ${mode_unset_all} one.key &&
	test_line_count = 0 .shit/config &&

	q_to_tab >.shit/config <<-\EOF &&
	[one]
	Qkey = true
	Q# a comment not at the start
	[two]
	Qkey = true
	EOF
	shit config ${mode_unset} two.key &&
	grep two .shit/config &&

	q_to_tab >.shit/config <<-\EOF &&
	[one]
	Qkey = not [two "subsection"]
	[two "subsection"]
	[two "subsection"]
	Qkey = true
	[TWO "subsection"]
	[one]
	EOF
	shit config ${mode_unset} two.subsection.key &&
	test "not [two subsection]" = "$(shit config ${mode_get} one.key)" &&
	test_line_count = 3 .shit/config
'

test_expect_success '--unset-all removes section if empty & uncommented' '
	cat >.shit/config <<-\EOF &&
	[section]
	key = value1
	key = value2
	EOF

	shit config ${mode_unset_all} section.key &&
	test_line_count = 0 .shit/config
'

test_expect_success 'adding a key into an empty section reuses header' '
	cat >.shit/config <<-\EOF &&
	[section]
	EOF

	q_to_tab >expect <<-\EOF &&
	[section]
	Qkey = value
	EOF

	shit config section.key value &&
	test_cmp expect .shit/config
'

test_expect_success POSIXPERM,PERL 'preserves existing permissions' '
	chmod 0600 .shit/config &&
	shit config imap.pass Hunter2 &&
	perl -e \
	  "die q(badset) if ((stat(q(.shit/config)))[2] & 07777) != 0600" &&
	shit config ${mode_prefix}rename-section imap pop &&
	perl -e \
	  "die q(badrename) if ((stat(q(.shit/config)))[2] & 07777) != 0600"
'

! test_have_prereq MINGW ||
HOME="$(pwd)" # convert to Windows path

test_expect_success 'set up --show-origin tests' '
	INCLUDE_DIR="$HOME/include" &&
	mkdir -p "$INCLUDE_DIR" &&
	cat >"$INCLUDE_DIR"/absolute.include <<-\EOF &&
	[user]
		absolute = include
	EOF
	cat >"$INCLUDE_DIR"/relative.include <<-\EOF &&
	[user]
		relative = include
	EOF
	cat >"$HOME"/.shitconfig <<-EOF &&
	[user]
		global = true
		override = global
	[include]
		path = "$INCLUDE_DIR/absolute.include"
	EOF
	cat >.shit/config <<-\EOF
	[user]
		local = true
		override = local
	[include]
		path = ../include/relative.include
	EOF
'

test_expect_success '--show-origin with --list' '
	cat >expect <<-EOF &&
	file:$HOME/.shitconfig	user.global=true
	file:$HOME/.shitconfig	user.override=global
	file:$HOME/.shitconfig	include.path=$INCLUDE_DIR/absolute.include
	file:$INCLUDE_DIR/absolute.include	user.absolute=include
	file:.shit/config	user.local=true
	file:.shit/config	user.override=local
	file:.shit/config	include.path=../include/relative.include
	file:.shit/../include/relative.include	user.relative=include
	command line:	user.environ=true
	command line:	user.cmdline=true
	EOF
	shit_CONFIG_COUNT=1 shit_CONFIG_KEY_0=user.environ shit_CONFIG_VALUE_0=true\
		shit -c user.cmdline=true config ${mode_prefix}list --show-origin >output &&
	test_cmp expect output
'

test_expect_success '--show-origin with --list --null' '
	cat >expect <<-EOF &&
	file:$HOME/.shitconfigQuser.global
	trueQfile:$HOME/.shitconfigQuser.override
	globalQfile:$HOME/.shitconfigQinclude.path
	$INCLUDE_DIR/absolute.includeQfile:$INCLUDE_DIR/absolute.includeQuser.absolute
	includeQfile:.shit/configQuser.local
	trueQfile:.shit/configQuser.override
	localQfile:.shit/configQinclude.path
	../include/relative.includeQfile:.shit/../include/relative.includeQuser.relative
	includeQcommand line:Quser.cmdline
	trueQ
	EOF
	shit -c user.cmdline=true config ${mode_prefix}list --null --show-origin >output.raw &&
	nul_to_q <output.raw >output &&
	# The here-doc above adds a newline that the --null output would not
	# include. Add it here to make the two comparable.
	echo >>output &&
	test_cmp expect output
'

test_expect_success '--show-origin with single file' '
	cat >expect <<-\EOF &&
	file:.shit/config	user.local=true
	file:.shit/config	user.override=local
	file:.shit/config	include.path=../include/relative.include
	EOF
	shit config ${mode_prefix}list --local --show-origin >output &&
	test_cmp expect output
'

test_expect_success '--show-origin with --get-regexp' '
	cat >expect <<-EOF &&
	file:$HOME/.shitconfig	user.global true
	file:.shit/config	user.local true
	EOF
	shit config ${mode_get_regexp} --show-origin "user\.[g|l].*" >output &&
	test_cmp expect output
'

test_expect_success '--show-origin getting a single key' '
	cat >expect <<-\EOF &&
	file:.shit/config	local
	EOF
	shit config ${mode_get} --show-origin user.override >output &&
	test_cmp expect output
'

test_expect_success 'set up custom config file' '
	cat >"custom.conf" <<-\EOF &&
	[user]
		custom = true
	EOF
	CUSTOM_CONFIG_FILE="$(test-tool path-utils real_path custom.conf)"
'

test_expect_success !MINGW 'set up custom config file with special name characters' '
	WEIRDLY_NAMED_FILE="file\" (dq) and spaces.conf" &&
	cp "$CUSTOM_CONFIG_FILE" "$WEIRDLY_NAMED_FILE"
'

test_expect_success !MINGW '--show-origin escape special file name characters' '
	cat >expect <<-\EOF &&
	file:"file\" (dq) and spaces.conf"	user.custom=true
	EOF
	shit config ${mode_prefix}list --file "$WEIRDLY_NAMED_FILE" --show-origin >output &&
	test_cmp expect output
'

test_expect_success '--show-origin stdin' '
	cat >expect <<-\EOF &&
	standard input:	user.custom=true
	EOF
	shit config ${mode_prefix}list --file - --show-origin <"$CUSTOM_CONFIG_FILE" >output &&
	test_cmp expect output
'

test_expect_success '--show-origin stdin with file include' '
	cat >"$INCLUDE_DIR"/stdin.include <<-EOF &&
	[user]
		stdin = include
	EOF
	cat >expect <<-EOF &&
	file:$INCLUDE_DIR/stdin.include	include
	EOF
	echo "[include]path=\"$INCLUDE_DIR\"/stdin.include" |
	shit config --show-origin --includes --file - user.stdin >output &&

	test_cmp expect output
'

test_expect_success '--show-origin blob' '
	test_when_finished "rm -rf repo" &&
	shit init repo &&
	(
		cd repo &&
		blob=$(shit hash-object -w "$CUSTOM_CONFIG_FILE") &&
		cat >expect <<-EOF &&
		blob:$blob	user.custom=true
		EOF
		shit config ${mode_prefix}list --blob=$blob --show-origin >output &&
		test_cmp expect output
	)
'

test_expect_success '--show-origin blob ref' '
	test_when_finished "rm -rf repo" &&
	shit init repo &&
	(
		cd repo &&
		cat >expect <<-\EOF &&
		blob:main:custom.conf	user.custom=true
		EOF
		cp "$CUSTOM_CONFIG_FILE" custom.conf &&
		shit add custom.conf &&
		shit commit -m "new config file" &&
		shit config ${mode_prefix}list --blob=main:custom.conf --show-origin >output &&
		test_cmp expect output
	)
'

test_expect_success '--show-origin with --default' '
	shit config --show-origin --default foo some.key >actual &&
	echo "command line:	foo" >expect &&
	test_cmp expect actual
'

test_expect_success '--show-scope with --list' '
	cat >expect <<-EOF &&
	global	user.global=true
	global	user.override=global
	global	include.path=$INCLUDE_DIR/absolute.include
	global	user.absolute=include
	local	user.local=true
	local	user.override=local
	local	include.path=../include/relative.include
	local	user.relative=include
	local	core.repositoryformatversion=1
	local	extensions.worktreeconfig=true
	worktree	user.worktree=true
	command	user.cmdline=true
	EOF
	test_when_finished "shit worktree remove wt1" &&
	shit worktree add wt1 &&
	# We need these to test for worktree scope, but outside of this
	# test, this is just noise
	test_config core.repositoryformatversion 1 &&
	test_config extensions.worktreeConfig true &&
	shit config --worktree user.worktree true &&
	shit -c user.cmdline=true config ${mode_prefix}list --show-scope >output &&
	test_cmp expect output
'

test_expect_success !MINGW '--show-scope with --blob' '
	blob=$(shit hash-object -w "$CUSTOM_CONFIG_FILE") &&
	cat >expect <<-EOF &&
	command	user.custom=true
	EOF
	shit config ${mode_prefix}list --blob=$blob --show-scope >output &&
	test_cmp expect output
'

test_expect_success '--show-scope with --local' '
	cat >expect <<-\EOF &&
	local	user.local=true
	local	user.override=local
	local	include.path=../include/relative.include
	EOF
	shit config ${mode_prefix}list --local --show-scope >output &&
	test_cmp expect output
'

test_expect_success '--show-scope getting a single value' '
	cat >expect <<-\EOF &&
	local	true
	EOF
	shit config ${mode_get} --show-scope user.local >output &&
	test_cmp expect output
'

test_expect_success '--show-scope with --show-origin' '
	cat >expect <<-EOF &&
	global	file:$HOME/.shitconfig	user.global=true
	global	file:$HOME/.shitconfig	user.override=global
	global	file:$HOME/.shitconfig	include.path=$INCLUDE_DIR/absolute.include
	global	file:$INCLUDE_DIR/absolute.include	user.absolute=include
	local	file:.shit/config	user.local=true
	local	file:.shit/config	user.override=local
	local	file:.shit/config	include.path=../include/relative.include
	local	file:.shit/../include/relative.include	user.relative=include
	command	command line:	user.cmdline=true
	EOF
	shit -c user.cmdline=true config ${mode_prefix}list --show-origin --show-scope >output &&
	test_cmp expect output
'

test_expect_success '--show-scope with --default' '
	shit config --show-scope --default foo some.key >actual &&
	echo "command	foo" >expect &&
	test_cmp expect actual
'

test_expect_success 'override global and system config' '
	test_when_finished rm -f \"\$HOME\"/.shitconfig &&
	cat >"$HOME"/.shitconfig <<-EOF &&
	[home]
		config = true
	EOF

	test_when_finished rm -rf \"\$HOME\"/.config/shit &&
	mkdir -p "$HOME"/.config/shit &&
	cat >"$HOME"/.config/shit/config <<-EOF &&
	[xdg]
		config = true
	EOF
	cat >.shit/config <<-EOF &&
	[local]
		config = true
	EOF
	cat >custom-global-config <<-EOF &&
	[global]
		config = true
	EOF
	cat >custom-system-config <<-EOF &&
	[system]
		config = true
	EOF

	cat >expect <<-EOF &&
	global	xdg.config=true
	global	home.config=true
	local	local.config=true
	EOF
	shit config ${mode_prefix}list --show-scope >output &&
	test_cmp expect output &&

	cat >expect <<-EOF &&
	system	system.config=true
	global	global.config=true
	local	local.config=true
	EOF
	shit_CONFIG_NOSYSTEM=false shit_CONFIG_SYSTEM=custom-system-config shit_CONFIG_GLOBAL=custom-global-config \
		shit config ${mode_prefix}list --show-scope >output &&
	test_cmp expect output &&

	cat >expect <<-EOF &&
	local	local.config=true
	EOF
	shit_CONFIG_NOSYSTEM=false shit_CONFIG_SYSTEM=/dev/null shit_CONFIG_GLOBAL=/dev/null \
		shit config ${mode_prefix}list --show-scope >output &&
	test_cmp expect output
'

test_expect_success 'override global and system config with missing file' '
	test_must_fail env shit_CONFIG_GLOBAL=does-not-exist shit_CONFIG_SYSTEM=/dev/null shit config ${mode_prefix}list --global &&
	test_must_fail env shit_CONFIG_GLOBAL=/dev/null shit_CONFIG_SYSTEM=does-not-exist shit config ${mode_prefix}list --system &&
	shit_CONFIG_GLOBAL=does-not-exist shit_CONFIG_SYSTEM=does-not-exist shit version
'

test_expect_success 'system override has no effect with shit_CONFIG_NOSYSTEM' '
	# `shit config --system` has different semantics compared to other
	# commands as it ignores shit_CONFIG_NOSYSTEM. We thus test whether the
	# variable has an effect via a different proxy.
	cat >alias-config <<-EOF &&
	[alias]
		hello-world = !echo "hello world"
	EOF
	test_must_fail env shit_CONFIG_NOSYSTEM=true shit_CONFIG_SYSTEM=alias-config \
		shit hello-world &&
	shit_CONFIG_NOSYSTEM=false shit_CONFIG_SYSTEM=alias-config \
		shit hello-world >actual &&
	echo "hello world" >expect &&
	test_cmp expect actual
'

test_expect_success 'write to overridden global and system config' '
	cat >expect <<EOF &&
[config]
	key = value
EOF

	shit_CONFIG_GLOBAL=write-to-global shit config --global config.key value &&
	test_cmp expect write-to-global &&

	shit_CONFIG_SYSTEM=write-to-system shit config --system config.key value &&
	test_cmp expect write-to-system
'

for opt in --local --worktree
do
	test_expect_success "$opt requires a repo" '
		# we expect 128 to ensure that we do not simply
		# fail to find anything and return code "1"
		test_expect_code 128 nonshit shit config $opt foo.bar
	'
done

cat >.shit/config <<-\EOF &&
[section]
foo = true
number = 10
big = 1M
EOF

test_expect_success 'identical modern --type specifiers are allowed' '
	test_cmp_config 1048576 --type=int --type=int section.big
'

test_expect_success 'identical legacy --type specifiers are allowed' '
	test_cmp_config 1048576 --int --int section.big
'

test_expect_success 'identical mixed --type specifiers are allowed' '
	test_cmp_config 1048576 --int --type=int section.big
'

test_expect_success 'non-identical modern --type specifiers are not allowed' '
	test_must_fail shit config --type=int --type=bool section.big 2>error &&
	test_grep "only one type at a time" error
'

test_expect_success 'non-identical legacy --type specifiers are not allowed' '
	test_must_fail shit config --int --bool section.big 2>error &&
	test_grep "only one type at a time" error
'

test_expect_success 'non-identical mixed --type specifiers are not allowed' '
	test_must_fail shit config --type=int --bool section.big 2>error &&
	test_grep "only one type at a time" error
'

test_expect_success '--type allows valid type specifiers' '
	test_cmp_config true  --type=bool section.foo
'

test_expect_success '--no-type unsets type specifiers' '
	test_cmp_config 10 --type=bool --no-type section.number
'

test_expect_success 'unset type specifiers may be reset to conflicting ones' '
	test_cmp_config 1048576 --type=bool --no-type --type=int section.big
'

test_expect_success '--type rejects unknown specifiers' '
	test_must_fail shit config --type=nonsense section.foo 2>error &&
	test_grep "unrecognized --type argument" error
'

test_expect_success '--type=int requires at least one dishit' '
	test_must_fail shit config --type int --default m some.key >out 2>error &&
	grep "bad numeric config value" error &&
	test_must_be_empty out
'

test_expect_success '--replace-all does not invent newlines' '
	q_to_tab >.shit/config <<-\EOF &&
	[abc]key
	QkeepSection
	[xyz]
	Qkey = 1
	[abc]
	Qkey = a
	EOF
	q_to_tab >expect <<-\EOF &&
	[abc]
	QkeepSection
	[xyz]
	Qkey = 1
	[abc]
	Qkey = b
	EOF
	shit config ${mode_replace_all} abc.key b &&
	test_cmp expect .shit/config
'

test_expect_success 'set all config with value-pattern' '
	test_when_finished rm -f config initial &&
	shit config --file=initial abc.key one &&

	# no match => add new entry
	cp initial config &&
	shit config --file=config abc.key two a+ &&
	shit config ${mode_prefix}list --file=config >actual &&
	cat >expect <<-\EOF &&
	abc.key=one
	abc.key=two
	EOF
	test_cmp expect actual &&

	# multiple matches => failure
	test_must_fail shit config --file=config abc.key three o+ 2>err &&
	test_grep "has multiple values" err &&

	# multiple values, no match => add
	shit config --file=config abc.key three a+ &&
	shit config ${mode_prefix}list --file=config >actual &&
	cat >expect <<-\EOF &&
	abc.key=one
	abc.key=two
	abc.key=three
	EOF
	test_cmp expect actual &&

	# single match => replace
	shit config --file=config abc.key four h+ &&
	shit config ${mode_prefix}list --file=config >actual &&
	cat >expect <<-\EOF &&
	abc.key=one
	abc.key=two
	abc.key=four
	EOF
	test_cmp expect actual
'

test_expect_success '--replace-all and value-pattern' '
	test_when_finished rm -f config &&
	shit config --file=config --add abc.key one &&
	shit config --file=config --add abc.key two &&
	shit config --file=config --add abc.key three &&
	shit config --file=config --replace-all abc.key four "o+" &&
	shit config ${mode_prefix}list --file=config >actual &&
	cat >expect <<-\EOF &&
	abc.key=four
	abc.key=three
	EOF
	test_cmp expect actual
'

test_expect_success 'refuse --fixed-value for incompatible actions' '
	test_when_finished rm -f config &&
	shit config --file=config dev.null bogus &&

	# These modes do not allow --fixed-value at all
	test_must_fail shit config --file=config --fixed-value --add dev.null bogus &&
	test_must_fail shit config --file=config --fixed-value --get-urlmatch dev.null bogus &&
	test_must_fail shit config --file=config --fixed-value --get-urlmatch dev.null bogus &&
	test_must_fail shit config ${mode_prefix}rename-section --file=config --fixed-value dev null &&
	test_must_fail shit config ${mode_prefix}remove-section --file=config --fixed-value dev &&
	test_must_fail shit config ${mode_prefix}list --file=config --fixed-value &&
	test_must_fail shit config --file=config --fixed-value --get-color dev.null &&
	test_must_fail shit config --file=config --fixed-value --get-colorbool dev.null &&

	# These modes complain when --fixed-value has no value-pattern
	test_must_fail shit config ${mode_set} --file=config --fixed-value dev.null bogus &&
	test_must_fail shit config ${mode_replace_all} --file=config --fixed-value dev.null bogus &&
	test_must_fail shit config ${mode_prefix}get --file=config --fixed-value dev.null &&
	test_must_fail shit config ${mode_get_all} --file=config --fixed-value dev.null &&
	test_must_fail shit config ${mode_get_regexp} --file=config --fixed-value "dev.*" &&
	test_must_fail shit config ${mode_unset} --file=config --fixed-value dev.null &&
	test_must_fail shit config ${mode_unset_all} --file=config --fixed-value dev.null
'

test_expect_success '--fixed-value uses exact string matching' '
	test_when_finished rm -f config initial &&
	META="a+b*c?d[e]f.g" &&
	shit config --file=initial fixed.test "$META" &&

	cp initial config &&
	shit config --file=config fixed.test bogus "$META" &&
	shit config ${mode_prefix}list --file=config >actual &&
	cat >expect <<-EOF &&
	fixed.test=$META
	fixed.test=bogus
	EOF
	test_cmp expect actual &&

	cp initial config &&
	shit config --file=config --fixed-value fixed.test bogus "$META" &&
	shit config ${mode_prefix}list --file=config >actual &&
	cat >expect <<-\EOF &&
	fixed.test=bogus
	EOF
	test_cmp expect actual &&

	cp initial config &&
	test_must_fail shit config --file=config --unset fixed.test "$META" &&
	shit config --file=config --fixed-value --unset fixed.test "$META" &&
	test_must_fail shit config ${mode_get} --file=config fixed.test &&

	cp initial config &&
	test_must_fail shit config unset --file=config --value="$META" fixed.test &&
	shit config unset --file=config --fixed-value --value="$META" fixed.test &&
	test_must_fail shit config ${mode_get} --file=config fixed.test &&

	cp initial config &&
	test_must_fail shit config --file=config --unset-all fixed.test "$META" &&
	shit config --file=config --fixed-value --unset-all fixed.test "$META" &&
	test_must_fail shit config ${mode_get} --file=config fixed.test &&

	cp initial config &&
	shit config --file=config fixed.test bogus "$META" &&
	shit config ${mode_prefix}list --file=config >actual &&
	cat >expect <<-EOF &&
	fixed.test=$META
	fixed.test=bogus
	EOF
	test_cmp expect actual &&

	shit config --file=config --fixed-value --replace-all fixed.test bogus "$META" &&
	shit config ${mode_prefix}list --file=config >actual &&
	cat >expect <<-EOF &&
	fixed.test=bogus
	fixed.test=bogus
	EOF
	test_cmp expect actual
'

test_expect_success '--get and --get-all with --fixed-value' '
	test_when_finished rm -f config &&
	META="a+b*c?d[e]f.g" &&
	shit config --file=config fixed.test bogus &&
	shit config --file=config --add fixed.test "$META" &&

	shit config --file=config --get fixed.test bogus &&
	shit config get --file=config --value=bogus fixed.test &&
	test_must_fail shit config --file=config --get fixed.test "$META" &&
	test_must_fail shit config get --file=config --value="$META" fixed.test &&
	shit config --file=config --get --fixed-value fixed.test "$META" &&
	shit config get --file=config --fixed-value --value="$META" fixed.test &&
	test_must_fail shit config --file=config --get --fixed-value fixed.test non-existent &&

	shit config --file=config --get-all fixed.test bogus &&
	shit config get --all --file=config --value=bogus fixed.test &&
	test_must_fail shit config --file=config --get-all fixed.test "$META" &&
	test_must_fail shit config get --all --file=config --value="$META" fixed.test &&
	shit config --file=config --get-all --fixed-value fixed.test "$META" &&
	shit config get --all --file=config --value="$META" --fixed-value fixed.test &&
	test_must_fail shit config --file=config --get-all --fixed-value fixed.test non-existent &&

	shit config --file=config --get-regexp fixed+ bogus &&
	shit config get --regexp --file=config --value=bogus fixed+ &&
	test_must_fail shit config --file=config --get-regexp fixed+ "$META" &&
	test_must_fail shit config get --regexp --file=config --value="$META" fixed+ &&
	shit config --file=config --get-regexp --fixed-value fixed+ "$META" &&
	shit config get --regexp --file=config --fixed-value --value="$META" fixed+ &&
	test_must_fail shit config --file=config --get-regexp --fixed-value fixed+ non-existent
'

test_expect_success 'includeIf.hasconfig:remote.*.url' '
	shit init hasremoteurlTest &&
	test_when_finished "rm -rf hasremoteurlTest" &&

	cat >include-this <<-\EOF &&
	[user]
		this = this-is-included
	EOF
	cat >dont-include-that <<-\EOF &&
	[user]
		that = that-is-not-included
	EOF
	cat >>hasremoteurlTest/.shit/config <<-EOF &&
	[includeIf "hasconfig:remote.*.url:foourl"]
		path = "$(pwd)/include-this"
	[includeIf "hasconfig:remote.*.url:barurl"]
		path = "$(pwd)/dont-include-that"
	[remote "foo"]
		url = foourl
	EOF

	echo this-is-included >expect-this &&
	shit -C hasremoteurlTest config --get user.this >actual-this &&
	test_cmp expect-this actual-this &&

	test_must_fail shit -C hasremoteurlTest config --get user.that
'

test_expect_success 'includeIf.hasconfig:remote.*.url respects last-config-wins' '
	shit init hasremoteurlTest &&
	test_when_finished "rm -rf hasremoteurlTest" &&

	cat >include-two-three <<-\EOF &&
	[user]
		two = included-config
		three = included-config
	EOF
	cat >>hasremoteurlTest/.shit/config <<-EOF &&
	[remote "foo"]
		url = foourl
	[user]
		one = main-config
		two = main-config
	[includeIf "hasconfig:remote.*.url:foourl"]
		path = "$(pwd)/include-two-three"
	[user]
		three = main-config
	EOF

	echo main-config >expect-main-config &&
	echo included-config >expect-included-config &&

	shit -C hasremoteurlTest config --get user.one >actual &&
	test_cmp expect-main-config actual &&

	shit -C hasremoteurlTest config --get user.two >actual &&
	test_cmp expect-included-config actual &&

	shit -C hasremoteurlTest config --get user.three >actual &&
	test_cmp expect-main-config actual
'

test_expect_success 'includeIf.hasconfig:remote.*.url globs' '
	shit init hasremoteurlTest &&
	test_when_finished "rm -rf hasremoteurlTest" &&

	printf "[user]\ndss = yes\n" >double-star-start &&
	printf "[user]\ndse = yes\n" >double-star-end &&
	printf "[user]\ndsm = yes\n" >double-star-middle &&
	printf "[user]\nssm = yes\n" >single-star-middle &&
	printf "[user]\nno = no\n" >no &&

	cat >>hasremoteurlTest/.shit/config <<-EOF &&
	[remote "foo"]
		url = https://foo/bar/baz
	[includeIf "hasconfig:remote.*.url:**/baz"]
		path = "$(pwd)/double-star-start"
	[includeIf "hasconfig:remote.*.url:**/nomatch"]
		path = "$(pwd)/no"
	[includeIf "hasconfig:remote.*.url:https:/**"]
		path = "$(pwd)/double-star-end"
	[includeIf "hasconfig:remote.*.url:nomatch:/**"]
		path = "$(pwd)/no"
	[includeIf "hasconfig:remote.*.url:https:/**/baz"]
		path = "$(pwd)/double-star-middle"
	[includeIf "hasconfig:remote.*.url:https:/**/nomatch"]
		path = "$(pwd)/no"
	[includeIf "hasconfig:remote.*.url:https://*/bar/baz"]
		path = "$(pwd)/single-star-middle"
	[includeIf "hasconfig:remote.*.url:https://*/baz"]
		path = "$(pwd)/no"
	EOF

	shit -C hasremoteurlTest config --get user.dss &&
	shit -C hasremoteurlTest config --get user.dse &&
	shit -C hasremoteurlTest config --get user.dsm &&
	shit -C hasremoteurlTest config --get user.ssm &&
	test_must_fail shit -C hasremoteurlTest config --get user.no
'

test_expect_success 'includeIf.hasconfig:remote.*.url forbids remote url in such included files' '
	shit init hasremoteurlTest &&
	test_when_finished "rm -rf hasremoteurlTest" &&

	cat >include-with-url <<-\EOF &&
	[remote "bar"]
		url = barurl
	EOF
	cat >>hasremoteurlTest/.shit/config <<-EOF &&
	[includeIf "hasconfig:remote.*.url:foourl"]
		path = "$(pwd)/include-with-url"
	EOF

	# test with any shit command
	test_must_fail shit -C hasremoteurlTest status 2>err &&
	grep "fatal: remote URLs cannot be configured in file directly or indirectly included by includeIf.hasconfig:remote.*.url" err
'

test_expect_success 'negated mode causes failure' '
	test_must_fail shit config --no-get 2>err &&
	grep "unknown option \`no-get${SQ}" err
'

test_expect_success 'specifying multiple modes causes failure' '
	cat >expect <<-EOF &&
	error: options ${SQ}--get-all${SQ} and ${SQ}--get${SQ} cannot be used together
	EOF
	test_must_fail shit config --get --get-all 2>err &&
	test_cmp expect err
'

done

test_done
