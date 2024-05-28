package shit::LoadCPAN::Error;
use 5.008001;
use strict;
use warnings $ENV{shit_PERL_FATAL_WARNINGS} ? qw(FATAL all) : ();
use shit::LoadCPAN (
	module => 'Error',
	import => 1,
);

1;
