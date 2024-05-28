#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 7;

require_ok 'shit::SVN';
require_ok 'shit::SVN::Utils';
require_ok 'shit::SVN::Ra';
require_ok 'shit::SVN::Log';
require_ok 'shit::SVN::Migration';
require_ok 'shit::IndexInfo';
require_ok 'shit::SVN::GlobSpec';
