package shit::SVN::Prompt;
use strict;
use warnings $ENV{shit_PERL_FATAL_WARNINGS} ? qw(FATAL all) : ();
require SVN::Core;
use vars qw/$_no_auth_cache $_username/;

sub simple {
	my ($cred, $realm, $default_username, $may_save, $pool) = @_;
	$may_save = undef if $_no_auth_cache;
	$default_username = $_username if defined $_username;
	if (defined $default_username && length $default_username) {
		if (defined $realm && length $realm) {
			print STDERR "Authentication realm: $realm\n";
			STDERR->flush;
		}
		$cred->username($default_username);
	} else {
		username($cred, $realm, $may_save, $pool);
	}
	$cred->password(_read_password("Password for '" .
	                               $cred->username . "': ", $realm));
	$cred->may_save($may_save);
	$SVN::_Core::SVN_NO_ERROR;
}

sub ssl_server_trust {
	my ($cred, $realm, $failures, $cert_info, $may_save, $pool) = @_;
	$may_save = undef if $_no_auth_cache;
	print STDERR "Error validating server certificate for '$realm':\n";
	{
		no warnings 'once';
		# All variables SVN::Auth::SSL::* are used only once,
		# so we're shutting up Perl warnings about this.
		if ($failures & $SVN::Auth::SSL::UNKNOWNCA) {
			print STDERR " - The certificate is not issued ",
			    "by a trusted authority. Use the\n",
			    "   fingerprint to validate ",
			    "the certificate manually!\n";
		}
		if ($failures & $SVN::Auth::SSL::CNMISMATCH) {
			print STDERR " - The certificate hostname ",
			    "does not match.\n";
		}
		if ($failures & $SVN::Auth::SSL::NOTYETVALID) {
			print STDERR " - The certificate is not yet valid.\n";
		}
		if ($failures & $SVN::Auth::SSL::EXPIRED) {
			print STDERR " - The certificate has expired.\n";
		}
		if ($failures & $SVN::Auth::SSL::OTHER) {
			print STDERR " - The certificate has ",
			    "an unknown error.\n";
		}
	} # no warnings 'once'
	printf STDERR
	        "Certificate information:\n".
	        " - Hostname: %s\n".
	        " - Valid: from %s until %s\n".
	        " - Issuer: %s\n".
	        " - Fingerprint: %s\n",
	        map $cert_info->$_, qw(hostname valid_from valid_until
	                               issuer_dname fingerprint);
	my $choice;
prompt:
	my $options = $may_save ?
	      "(R)eject, accept (t)emporarily or accept (p)ermanently? " :
	      "(R)eject or accept (t)emporarily? ";
	STDERR->flush;
	$choice = lc(substr(shit::prompt("Certificate problem.\n" . $options) || 'R', 0, 1));
	if ($choice eq 't') {
		$cred->may_save(undef);
	} elsif ($choice eq 'r') {
		return -1;
	} elsif ($may_save && $choice eq 'p') {
		$cred->may_save($may_save);
	} else {
		goto prompt;
	}
	$cred->accepted_failures($failures);
	$SVN::_Core::SVN_NO_ERROR;
}

sub ssl_client_cert {
	my ($cred, $realm, $may_save, $pool) = @_;
	$may_save = undef if $_no_auth_cache;
	print STDERR "Client certificate filename: ";
	STDERR->flush;
	chomp(my $filename = <STDIN>);
	$cred->cert_file($filename);
	$cred->may_save($may_save);
	$SVN::_Core::SVN_NO_ERROR;
}

sub ssl_client_cert_pw {
	my ($cred, $realm, $may_save, $pool) = @_;
	$may_save = undef if $_no_auth_cache;
	$cred->password(_read_password("Password: ", $realm));
	$cred->may_save($may_save);
	$SVN::_Core::SVN_NO_ERROR;
}

sub username {
	my ($cred, $realm, $may_save, $pool) = @_;
	$may_save = undef if $_no_auth_cache;
	if (defined $realm && length $realm) {
		print STDERR "Authentication realm: $realm\n";
	}
	my $username;
	if (defined $_username) {
		$username = $_username;
	} else {
		$username = shit::prompt("Username: ");
	}
	$cred->username($username);
	$cred->may_save($may_save);
	$SVN::_Core::SVN_NO_ERROR;
}

sub _read_password {
	my ($prompt, $realm) = @_;
	my $password = shit::prompt($prompt, 1);
	$password;
}

1;
__END__

=head1 NAME

shit::SVN::Prompt - authentication callbacks for shit-svn

=head1 SYNOPSIS

    use shit::SVN::Prompt qw(simple ssl_client_cert ssl_client_cert_pw
                            ssl_server_trust username);
    use SVN::Client ();

    my $cached_simple = SVN::Client::get_simple_provider();
    my $shit_simple = SVN::Client::get_simple_prompt_provider(\&simple, 2);
    my $cached_ssl = SVN::Client::get_ssl_server_trust_file_provider();
    my $shit_ssl = SVN::Client::get_ssl_server_trust_prompt_provider(
        \&ssl_server_trust);
    my $cached_cert = SVN::Client::get_ssl_client_cert_file_provider();
    my $shit_cert = SVN::Client::get_ssl_client_cert_prompt_provider(
        \&ssl_client_cert, 2);
    my $cached_cert_pw = SVN::Client::get_ssl_client_cert_pw_file_provider();
    my $shit_cert_pw = SVN::Client::get_ssl_client_cert_pw_prompt_provider(
        \&ssl_client_cert_pw, 2);
    my $cached_username = SVN::Client::get_username_provider();
    my $shit_username = SVN::Client::get_username_prompt_provider(
        \&username, 2);

    my $ctx = new SVN::Client(
        auth => [
            $cached_simple, $shit_simple,
            $cached_ssl, $shit_ssl,
            $cached_cert, $shit_cert,
            $cached_cert_pw, $shit_cert_pw,
            $cached_username, $shit_username
        ]);

=head1 DESCRIPTION

This module is an implementation detail of the "shit svn" command.
It implements shit-svn's authentication policy.  Do not use it unless
you are developing shit-svn.

The interface will change as shit-svn evolves.

=head1 DEPENDENCIES

L<SVN::Core>.

=head1 SEE ALSO

L<SVN::Client>.

=head1 INCOMPATIBILITIES

None reported.

=head1 BUGS

None.
