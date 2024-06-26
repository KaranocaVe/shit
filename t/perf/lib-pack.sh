# Helpers for dealing with large numbers of packs.

# create $1 nonsense packs, each with a single blob
create_packs () {
	perl -le '
		my ($n) = @ARGV;
		for (1..$n) {
			print "blob";
			print "data <<EOF";
			print "$_";
			print "EOF";
			print "checkpoint"
		}
	' "$@" |
	shit fast-import
}

# create a large number of packs, disabling any gc which might
# cause us to repack them
setup_many_packs () {
	shit config gc.auto 0 &&
	shit config gc.autopacklimit 0 &&
	shit config fastimport.unpacklimit 0 &&
	create_packs 500
}
