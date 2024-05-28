# BEGIN RUNTIME_PREFIX generated code.
#
# This finds our shit::* libraries relative to the script's runtime path.
sub __shit_system_path {
	my ($relpath) = @_;
	my $shitexecdir_relative = '@@shitEXECDIR_REL@@';

	# shit_EXEC_PATH is supplied by `shit` or the test suite.
	my $exec_path;
	if (exists $ENV{shit_EXEC_PATH}) {
		$exec_path = $ENV{shit_EXEC_PATH};
	} else {
		# This can happen if this script is being directly invoked instead of run
		# by "shit".
		require FindBin;
		$exec_path = $FindBin::Bin;
	}

	# Trim off the relative shitexecdir path to get the system path.
	(my $prefix = $exec_path) =~ s/\Q$shitexecdir_relative\E$//;

	require File::Spec;
	return File::Spec->catdir($prefix, $relpath);
}

BEGIN {
	use lib split /@@PATHSEP@@/,
	(
		$ENV{shitPERLLIB} ||
		do {
			my $perllibdir = __shit_system_path('@@PERLLIBDIR_REL@@');
			(-e $perllibdir) || die("Invalid system path ($relpath): $path");
			$perllibdir;
		}
	);

	# Export the system locale directory to the I18N module. The locale directory
	# is only installed if NO_GETTEXT is set.
	$shit::I18N::TEXTDOMAINDIR = __shit_system_path('@@LOCALEDIR_REL@@');
}

# END RUNTIME_PREFIX generated code.
