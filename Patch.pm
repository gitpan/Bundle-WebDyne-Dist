#
#
#  Copyright (c) 2003 Andrew W. Speer <andrew.speer@isolutions.com.au>. All rights 
#  reserved.
#
#  This file is part of ExtUtils::Bundle.
#
#  ExtUtils::Bundle is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
#
#  $Id: Patch.pm.inc,v 1.10 2005/10/23 07:25:40 aspeer Exp $

#
#  Package called when CPAN invoking Makefile.PL to build a bundled
#  module, invoked as perl -MPatch,<package>,<perl_binary> Makefile.PL
#
package Patch;


#  Only use the File::Spec package
#
use File::Spec;
use File::Find;
use IO::File;
use Cwd qw(cwd);


#  Use strict vars
#
use strict qw(vars);



#  Done
#
1;


#  The guts, called before CPAN actually opens the Makefile.PL file,
#  gives us a chance to intercept
#
sub import {


    #  Get self ref, name of package we are patching and
    #  perl binary location. We no longer use the build
    #  name, but it may come in handy one day.
    #
    #  ID is in the form AUTHOR/ID/Perl-ModuleName.tar.gz
    #  Buildname is in the form Perl::ModuleName.
    #
    my ($self, $bin_perl, $package_build_name, $package_id)=@_;


    #  Get patch directory, which should sit below us, var to hold patch path
    #
    my $patch_dn=(File::Spec->splitpath($INC{'Patch.pm'}))[1];


    #  Get package name, version from tar.gz file name
    #
    ($package_id=~ /^(.+?)\-([0-9.-]+)\w?\.tar\.gz$/) ||
	die("unable to determine module name and/or version for file $package_id");
    my ($name, $version)=((File::Spec->splitpath($1))[2], $2);
    $version=(split(/\-/, $version))[0];
    
    
    #  Patch can be either "name.diff", or "name-ver.diff" (applied to all or specific
    #  versions of a module respectively
    #
    my @patch_cn=grep { -e $_ } map { File::Spec->catfile($patch_dn, 'patch', $_) } (
    	"${name}.diff", "${name}-${version}.diff");
    if ($^O eq 'MSWin32') {
	my $volume=(File::Spec->splitpath(cwd()))[0];
	map { $_=$volume.$_ } @patch_cn;
    }


    #  If either exist, patch
    #
    if (@patch_cn) {

	#  Can we find patch binary
	#
	if (my $bin_patch=&bin_find('patch')) {


	    #  Yes, do the patch
	    #
	    foreach my $patch_cn (@patch_cn) {


		#  Run the patch command
		#
		my @cmd=($bin_patch, '-p1', '-f', '-i', $patch_cn);


		#  Do, chech for Any errors ..
		#
		if (my $system_rc = system (@cmd)) {
		    if (($system_rc = $? >> 8) !=0) {
			die("error applying patch '$patch_cn' to $name, return code '$system_rc' from $bin_patch")
		    }
		}
	    }
	}
	else {

	    #  Could not find patch binary
	    #
	    print "ERROR: Unable to find patch binary. No patching will be undertaken\n";
	    sleep 2;

	}

    }
    
    
    #  Look for perl patches also
    #
    @patch_cn=grep { -e $_ } map { File::Spec->catfile($patch_dn, 'patch', $_) } (
    	"${name}.pl", "${name}-${version}.pl");
    foreach my $patch_pl (@patch_cn) { do ($patch_pl) ||
        die("error applying patch '$patch_pl' to $name, $!") }

    #  Make args can be either "name.make", or "name-ver.make" (applied to all or specific
    #  versions of a module respectively. Only one should be present
    #
    my @make_cn=map { File::Spec->catfile($patch_dn, 'patch', $_) } (
    	"${name}.make", "${name}-${version}.make");


    #  Look for a .make file, which contains args to be added the make
    #  command
    #
    foreach my $make_cn (grep { -e $_ } @make_cn) {


	#  Do it, so read in args
	#
	print "patching $name make file with args from $make_cn\n";
	my $arg_ar=do($make_cn) ||
	    die("unable to get array ref from make spec file $make_cn");


	#  Add tp ARGS
	#
	unshift @ARGV, @{$arg_ar};

    }


    #  Add INC dirs to perl path;
    #
    my @inc=map { "-I$_" } @INC;


    #  Now run the Makefile.PL, with any args
    #
    if ($^O eq 'MSWin32') {
	system($bin_perl, @inc, 'Makefile.PL', @ARGV);
	exit 0;
    }
    else {
	exec($bin_perl, @inc, 'Makefile.PL', @ARGV);
    }

}


sub bin_find {


    #  Find a binary file
    #
    my $bin=shift();
    my $bin_fn;


    #  Find the httpd bin file
    #
    my $wanted_cr=sub {
        if ($File::Find::name=~/\/\Q$bin\E(\.exe)?$/ && !$bin_fn) {
	    $bin_fn=$File::Find::name;
	}
    };
    my @dir=grep { -d $_ } split(/:|;/, $ENV{'PATH'});
    find($wanted_cr, @dir);


    #  Return
    #
    return $bin_fn;

};
