#!/bin/sh
#
# Copyright (c) 2010 Ævar Arnfjörð Bjarmason
#

test_description='Gettext Shell fallbacks'

shit_INTERNAL_GETTEXT_TEST_FALLBACKS=YesPlease
export shit_INTERNAL_GETTEXT_TEST_FALLBACKS

TEST_PASSES_SANITIZE_LEAK=true
. ./lib-gettext.sh

test_expect_success "sanity: \$shit_INTERNAL_GETTEXT_SH_SCHEME is set (to $shit_INTERNAL_GETTEXT_SH_SCHEME)" '
    test -n "$shit_INTERNAL_GETTEXT_SH_SCHEME"
'

test_expect_success 'sanity: $shit_INTERNAL_GETTEXT_TEST_FALLBACKS is set' '
    test -n "$shit_INTERNAL_GETTEXT_TEST_FALLBACKS"
'

test_expect_success 'sanity: $shit_INTERNAL_GETTEXT_SH_SCHEME" is fallthrough' '
    echo fallthrough >expect &&
    echo $shit_INTERNAL_GETTEXT_SH_SCHEME >actual &&
    test_cmp expect actual
'

test_expect_success 'gettext: our gettext() fallback has pass-through semantics' '
    printf "test" >expect &&
    gettext "test" >actual &&
    test_cmp expect actual &&
    printf "test more words" >expect &&
    gettext "test more words" >actual &&
    test_cmp expect actual
'

test_expect_success 'eval_gettext: our eval_gettext() fallback has pass-through semantics' '
    printf "test" >expect &&
    eval_gettext "test" >actual &&
    test_cmp expect actual &&
    printf "test more words" >expect &&
    eval_gettext "test more words" >actual &&
    test_cmp expect actual
'

test_expect_success 'eval_gettext: our eval_gettext() fallback can interpolate variables' '
    printf "test YesPlease" >expect &&
    shit_INTERNAL_GETTEXT_TEST_FALLBACKS=YesPlease eval_gettext "test \$shit_INTERNAL_GETTEXT_TEST_FALLBACKS" >actual &&
    test_cmp expect actual
'

test_expect_success 'eval_gettext: our eval_gettext() fallback can interpolate variables with spaces' '
    cmdline="shit am" &&
    export cmdline &&
    printf "When you have resolved this problem, run shit am --resolved." >expect &&
    eval_gettext "When you have resolved this problem, run \$cmdline --resolved." >actual &&
    test_cmp expect actual
'

test_expect_success 'eval_gettext: our eval_gettext() fallback can interpolate variables with spaces and quotes' '
    cmdline="shit am" &&
    export cmdline &&
    printf "When you have resolved this problem, run \"shit am --resolved\"." >expect &&
    eval_gettext "When you have resolved this problem, run \"\$cmdline --resolved\"." >actual &&
    test_cmp expect actual
'

test_done
