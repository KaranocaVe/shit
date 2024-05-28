#!/usr/bin/perl -w

while (<>) {
	if (/^\@setfilename/) {
		$_ = "\@setfilename shit.info\n";
	} elsif (/^\@direntry/) {
		print '@dircategory Development
@direntry
* shit: (shit).           A fast distributed revision control system
@end direntry
';	}
	unless (/^\@direntry/../^\@end direntry/) {
		print;
	}
}
