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
#  $Id: Makefile.PL.pl,v 1.26 2006/01/28 04:37:25 aspeer Exp $

#
#  Installation component of the ExtUtils::Bundle module - installs
#  distribution bundles made by that module.
#


#  Compiler Pragma. Note WRITEMAKEFILE is not a real var name, it
#  is substituted out my the Text::Template fill in code
#
use strict qw(vars);
use vars qw ($VERSION $WRITEMAKEFILE $Cwd);
no warnings qw(redefine);


#  Use CPAN library in our cwd
#
use FindBin;
use lib $FindBin::Bin;


#  External Modules. We must be fairly much self-contained, so
#  only modules in the main Perl distribution are used, and some
#  methods below are pulled stright from WebMod::Library modules
#  etc.
#
use CPAN;
use Cwd qw(cwd);
use Carp;
use IO::File;
use File::Spec;
use ExtUtils::MakeMaker;
use Data::Dumper;
use POSIX qw(strftime);
use Config;


#  Try the CPAN Config files, but not fatal if unavailable. Needed
#  before we try and load local Config file below
#
require CPAN::Config;


#  Version info
#
$VERSION=(qw$Revision: 1.26 $)[1];


#  Some constants
#
use constant	OK		 =>  \undef;


#  Make sure language set, or will not build on RH9
#
$ENV{'LANG'}='C';


#  Index vars used to lookup bundle attrs
#
my($name_ix, $have_ix, $want_ix, $upgrade_ix)=(0..4);


#  Vars we need to share across the module
#
my %Makeflags;
my @Inc;


#  Set Cwd var so we know where we started from
#
$Cwd=cwd();


#  Additional modules to be treated as CORE
#
my @Module_CORE=qw(Data::Dumper File::Spec IO::File IPC::SysV);


#  Read data from __DATA__ area into hash
#
my $Data_hr=eval( join(undef, <DATA>) );


#  Call main sub if supplied with arg
#
@ARGV ? __PACKAGE__->main(@ARGV) : &makefile;


#------------------------------------------------------------------------------


sub makefile {


    #  Create the Makefile
    #
    WriteMakefile(

    	%{$Data_hr},
	SKIP   =>  ['top_targets'],

       );




}


#  Set install target to run custom script
#
sub MY::install {


    package MY;
    my @install=(

	'install :: pm_to_blib',
	"\t\$(PERL)  -I\$(INST_ARCHLIB) -I\$(INST_LIB) -M\$(NAME) ".
	    __FILE__ . ' ' . $Data_hr->{'NAME'} . ' $(MAKE)',

       );

    my $install=join("\n", undef, @install, undef);
    return $install


}



#  Replacement libscan section
#
sub MY::libscan {


    #  Change package name space
    #
    package MY;


    #  Get self ref
    #
    my $self=shift();


    #  Check if building CPAN module, take special steps
    #
    ($self->{'BASEEXT'} eq 'CPAN') && ($self->{'PMLIBDIRS'} ||= [qw(lib)]);


    #  Return whatever our parent does
    #
    return $self->SUPER::libscan(@_);


}


#------------------------------------------------------------------------------


sub main {


    #  Main program
    #
    my ($self, $bundle, $make)=@_;
    $bundle || 	return err("no bundle name supplied");


    #  Get makeflags
    #
    if (my $makeflags=$ENV{'MAKEFLAGS'}) {
    	my($key, $value);
    	my @makeflags=split(/\=/, $makeflags);
    	my @temp;
    	foreach my $temp (@makeflags) {
	    if ($temp=~/(.*)\s(\w+)$/) {
		push @temp, $1, uc($2)
	    }
	    else {
		push @temp, $temp;
	    }
    	}
    	%Makeflags=(@temp);
    }
    foreach my $makeflag (qw(PREFIX NOPROMPT NOBAIL)) {
    	$Makeflags{$makeflag}=$ENV{$makeflag} if $ENV{$makeflag};
    }


    #  If quiet option set, enforce now by making prompt program a
    #  stub that just returns the default value immediately
    #
    if ($Makeflags{'NOPROMPT'}) {

	*ExtUtils::MakeMaker::prompt=sub ($;$) {


	    #  Stub the prompt. Print it out though
	    #
	    printf("\n\n$_[0] [$_[1]]\n\n");


	    #  Return default
	    #
	    return $_[1]

	}

    }


    #  If prefix option set, push onto CPAN config
    #
    if (my $prefix_dn=$Makeflags{'PREFIX'} || $ENV{'PREFIX'}) {


	#  Update CPAN configs to include PREFIX arg
	#
	$CPAN::Config->{'makepl_arg'} .=
	    join(' ', grep {$_} $CPAN::Config->{'makepl_arg'}, "PREFIX=$prefix_dn");



    }


    #  Update CPAN::Config make param with what was used to make us
    #
    $CPAN::Config->{'make'}=$make;



    #  Null out library vars to ensure we do not pick up files in
    #  the blib directory as installed
    #
    local @INC=grep {!/^blib/} @INC;


    #  We need to check for the CPAN::Method::uptodate class and
    #  emulate it if not present. It is not available in stock
    #  5.00404 distribution
    #
    unless (UNIVERSAL::can('CPAN::Module','uptodate')) {
	print "CPAN::Module::uptodate not present ! Will Emulate.\n";
	*CPAN::Module::uptodate=sub { $self->uptodate(@_) }
    }


    #  Fix version comparator, seems to be broken as of 1.63. If using
    #  plain numerics, it returns "1.3" is > "1.21", where really 1.3
    #  is the 3rd iteration of program, and 1.21 is the twenty-first.
    #
    #  Seems to work OK using "v1.3" vs "v1.21", ie correct result  is
    #  returned. So we make everything sent to comparator be prefixed
    #  with "v" if it is not already.
    #
    #  This is more than likely not a real bug, just my mis-understanding
    #  of how things are supposed to work
    #
    my $cpan_vcmp_cr=UNIVERSAL::can('CPAN::Version', 'vcmp') ||
        return err('unable to get code ref for CPAN::Version::vcmp');
    *CPAN::Version::vcmp=sub {
        my @vcmp=map { /^v/ ? $_ : "v$_"   } @_[1,2];
        $cpan_vcmp_cr->($_[0], @vcmp);
    };


    #  Now read in the db created for us by the packager - "Dumper.pm"
    #
    my $dumper_ar=do(File::Spec->catfile($Cwd, 'Dumper.pm')) ||
	return err("unable to read 'Dumper.pm', $!");
    unless (@{$dumper_ar}) {
	return err('empty Dumper.pm file !')};


    #  Check for PPD files. Only do under Windows at the moment;
    #
    my %ppd_file;
    if ($^O=~/^MSWin[32|64]/) {
	my @ppd_cn=glob(File::Spec->catfile($Cwd, 'PPD', '*.ppd'));
	foreach my $ppd_cn (@ppd_cn) {
	    my ($module, $version);
	    my $ppd_fh=IO::File->new($ppd_cn, O_RDONLY) ||
		return err("unable to open file $ppd_cn, $!");
	    while (my $ppd_ln=<$ppd_fh>) {
		if ($ppd_ln=~/NAME=\"(.*?)\".*VERSION=\"(.*?)\"/i) {
		    ($module, $version)=($1,$2);
		    $version=~s/(?:[\.,]0)*$//;
		    $version.= '.0' unless ($version=~/[\.,]/ or $version='');
		    $version=~tr/,/./;
		    last;
		}
	    }
	    $ppd_fh->close();
	    unless ($module) {
		return err("unable to find module info from file '$ppd_cn'") };
	    $module=~s/\-/::/g;
	    $dumper_ar->[0]{$module}=$version;
	    $ppd_file{$module}=$ppd_cn;

	}
    }


    #  Update CPAN perl method to our custom one
    #
    *CPAN::Distribution::perl=\&perl;


    #  Now load that hash into the CPAN.pm module data space
    #
    $self->cpan_store({

	dumper_ar	=> $dumper_ar,

    }) || return err();


    #  Get bundle contents
    #
    my $bundle_hr=$self->bundle_contains({

	bundle	   =>  $bundle,

    }) || return err();


    #  Flag to indicate user wants to force install of
    #  all modules, even if apparently up-to-date
    #
    my $force_all_fg;


    #  Ask user if they want to continue the upgrade
    #
    my $upgrade_hr=$self->bundle_upgrade_display({

	bundle		=>  $bundle,
	bundle_hr	=>  $bundle_hr,
	force_all_sr	=>  \$force_all_fg,

    }) || return err();



    #  User has agreed to install, so run it
    #
    $self->bundle_install({

	bundle		=>  $bundle,
	bundle_hr	=>  $bundle_hr,
	upgrade_hr	=>  $upgrade_hr,
	dumper_ar	=>  $dumper_ar,
	cwd		=>  $Cwd,
	force_all_sr	=>  \$force_all_fg,
	ppd_file_hr	=>  \%ppd_file,

    }) || return err();



    #  Empty CPAN db to force re-read of. Unsafe. Clean up later - we are
    #  probably deleting more than needed.
    #
    my ($module_hr, $dist_hr)=@{$dumper_ar};
    foreach my $dist (keys %{$dist_hr}) {
	delete $CPAN::META->{'readonly'}{'CPAN::Distribution'}{$dist};
	delete $CPAN::META->{'readwrite'}{'CPAN::Distribution'}{$dist};
    }
    foreach my $module (keys %{$module_hr}) {
	delete $CPAN::META->{'readonly'}{'CPAN::Module'}{$module};
	delete $CPAN::META->{'readwrite'}{'CPAN::Module'}{$module};
    }



    #  Now reload CPAN.pm module data space
    #
    $self->cpan_store({

	dumper_ar   => $dumper_ar

       }) || return err();


    #  Re-read bundle contents
    #
    $bundle_hr=$self->bundle_contains({

	bundle	   =>  $bundle,

    }) || return err();


    #  Reget upgrade hash
    #
    $upgrade_hr=$self->bundle_upgrade_status({

	bundle_hr   =>  $bundle_hr,

    }) || return err();


    #  If any failues, go through now, set force flag so user
    #  will be give option to force install of a module
    #
    if (0 && (grep {$_} values %{$upgrade_hr}) && !$force_all_fg ) {

        $self->bundle_install({

	    bundle	     => $bundle,
	    bundle_hr	     => $bundle_hr,
	    upgrade_hr	     => $upgrade_hr,
	    dumper_ar	     => $dumper_ar,
	    cwd		     => $Cwd,
	    force	     => 1,
	    force_all_sr     => \$force_all_fg,

        }) || return err();
    }


    #  Now load that hash into the CPAN.pm module data space
    #
    $self->cpan_store({

	dumper_ar   => $dumper_ar

       }) || return err();


    #  Re-read bundle contents for last time
    #
    $bundle_hr=$self->bundle_contains({

	bundle	   =>  $bundle,

    }) || return err();


    #  Display final status
    #
    $self->bundle_upgrade_result({

	bundle	    =>  $bundle,
	bundle_hr   =>  $bundle_hr,

    }) || return err();


    #  Reget upgrade hash
    #
    $upgrade_hr=$self->bundle_upgrade_status({

	bundle_hr   =>  $bundle_hr,

    }) || return err();


    #  Done
    #
    exit (grep {$_} values %{$upgrade_hr}) ? 1 : 0;


}



sub bundle_inst_version {


    my($self, $module) = @_;
    my(@me);
    @me = split /::/, $module;
    $me[-1] .= ".pm";
    local %INC=();
    my $foundv;


    #  Hash of local inc dirs
    #
    my 	%inc;


    #  This must be done every time, as some subdirs are created as we go
    #
    @Inc=();
    if (my $prefix_dn=$Makeflags{'PREFIX'}) {

	#  Juggle to get correct INC dir
	#
	my $sitelib_dn=$Config{'sitelib'};
        my @sitelib_dn=File::Spec->splitdir($sitelib_dn);
        my @prefix_dn=File::Spec->splitdir($prefix_dn);
        my @prefix_perl_dn=File::Spec->splitdir($Config{'prefix'});
        for (@prefix_perl_dn) {shift @sitelib_dn};
        my $sitelib=File::Spec->catdir(@prefix_dn, @sitelib_dn);
	push @Inc, $sitelib;


        my $privlib_dn=$Config{'privlib'};
        my @privlib_dn=File::Spec->splitdir($privlib_dn);
        for (@prefix_perl_dn) {shift @privlib_dn};
        my $privlib=File::Spec->catdir(@prefix_dn, @privlib_dn);
	push @Inc,$privlib;


	#  Seem to need for earlier versions of Perl
	#
	$sitelib=~s/perl5//;
	$privlib=~s/perl5//;
	# Catdir cleans up paths, gets rid of stray //'s
	#
	push @Inc, File::Spec->catdir($sitelib);
	push @Inc, File::Spec->catdir($privlib);
	#  Need arch libs added manually for earlier versions too
	#
	push @Inc, File::Spec->catdir($sitelib, $Config{'archname'});
	push @Inc, File::Spec->catdir($privlib, $Config{'archname'});
	push @Inc, File::Spec->catdir($prefix_dn, 'lib', $Config{'version'}, $Config{'archname'});



	#  Add to @INC, add exclusive to %Inc, used to search
	#  for installed version.
	#
	'lib'->import(@Inc);
	%inc=map { $_=>1 } @INC;
	map { delete $inc{$_} } @lib::ORIG_INC;

    }
    else {

	%inc=map { $_=>1 } @INC;

    }



    foreach my $incdir (keys %inc) {
        my $bfile = File::Spec->catfile($incdir, @me);
        CPAN->debug("bfile[$bfile]") if $CPAN::DEBUG;
        next unless -f $bfile;
        $foundv = MM->parse_version($bfile);
	$foundv=~s/\s+//g;
        $self->{INST_VERSION}=$foundv;
    }


    #  Hardcoded fix for miscreant CGI versioning system
    #
    if (($module eq 'CGI') && grep { $foundv eq $_ } qw(2.751 2.752 2.753)) {
	$self->{'INST_VERSION'}='2.75';
    }
    $self->{INST_VERSION};

}


sub dist_install_force {


    #  Force a dist install after failure
    #
    my ($self, $param)=@_;


    #  Get module
    #
    my ($cpan_file, $force_all_sr)=@{$param}{qw(cpan_file force_all_sr)};


    #  Bad news, it is not. Offer to force install, this one only or all
    #
    print "\n";
    my $yesno=ExtUtils::MakeMaker::prompt(
	"Distribution $cpan_file is still not up to date.\n".
	    'Do you wish to force installation anyway (yes|no|all|quit) ?','yes');


    #  Return result
    #
    if ($yesno=~/^y|yes$/i)  { return \1 }
    if ($yesno=~/^a|all$/i)  { ${$force_all_sr}++; return \1 }
    if ($yesno=~/^q|quit$/i) { exit 0; }
    return \undef;

}


sub cpan_upgrade {


    #  Force upgrade of CPAN.pm
    #
    my ($self, $param)=@_;


    #  Get cwd param
    #
    my $cwd=$param->{'cwd'};


    #  Upgrade CPAN if needed
    #
    my $cpan_module_or=CPAN::Shell->expand('Module', 'CPAN') ||
	return err('unable to expand (via CPAN::Shell->expand) module CPAN');


    #  Print version
    #
    print "\n";
    print "Checking CPAN.pm status\n\n";
    my $format='  @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<  @>>>>>>>>>>>>>>>>>>>>>>@';


    #  Check up to date status
    #
    unless ($cpan_module_or->uptodate()) {


	#  Print upgrade version with *
	#
	formline "$format\n", 'CPAN',
	    sprintf('[%s -> %s]*', $cpan_module_or->inst_version()||'Unknown',
		    $cpan_module_or->cpan_version());
	print $^A; undef $^A;


	#  Give user choice to bail on module upgrades
	#
	print "\n",
	    "The CPAN module needs to be upgraded.\n";
	my $yesno=ExtUtils::MakeMaker::prompt('Do you wish to continue ?','yes');
	$yesno=~/^y|yes$/i || exit 0;


	#  Upgrade. Do not bother to check return code, is always 1 even if
	#  install fails
	#
	$cpan_module_or->force();
	$cpan_module_or->install();


	#  Reload
	#
	$self->cpan_reload({

	    cwd	    => $cwd,

	}) || return err();


    }
    else {


	#  Print version, OK
	#
	formline "$format\n", 'CPAN',
	    sprintf('[%s - OK]', $cpan_module_or->inst_version());
	print $^A; undef $^A;


	#
	#
	print "\n";
	print "CPAN is up to date\n";

    }


    #  All done
    #
    return OK

}


sub bundle_upgrade_display {


    #  Method to check installed modules, and then offer to upgrade
    #  them for user if they are out of date
    #
    my ($self, $param)=@_;


    #  Get the module list array
    #
    my ($bundle, $bundle_hr, $force_all_sr)=@{$param}{qw(bundle bundle_hr force_all_sr)};


    #  Flag to indicate one or more modules needs a downgrade, so
    #  we can tell user
    #
    my $downgrade_fg;


    #  Code ref to pretty print bundle info
    #
    my $format_cr=sub {


	#  Get self ref, module array ref
	#
	my ($self, $bundle_name, $module_ar)=@_;


	#  Get details
	#
	my ($name, $have_version, $want_version, $upgrade)=
	    @{$module_ar}[$name_ix, $have_ix, $want_ix, $upgrade_ix];


	#  Work out if upgrade or downgrade, remember downgrades
	#
        my $ug_icon=['!','*','*']->[CPAN::Version->vcmp(

	    "v${want_version}",
	    "v${have_version}",

	   )+1 || do {$downgrade_fg++; 0} ];


	#  Var to hold result
	#
	my $return;


	#  Format result
	#
	unless ($upgrade) {
	    $return=sprintf('[%s - OK] ', $have_version);
	}
	else {
	    $return=sprintf('[%s -> %s]%s', $have_version || 'Unknown',
			    $want_version, $ug_icon)
	}


	#  Return
	#
	return \$return;

    };


    #  Show the user a list of what will be upgraded
    #
    print "\n";
    print "This distribution contains the following bundles and modules:\n\n";


    #  Allow bundle_print to keep track of bundles already printed my supplying
    #  hash for it to store printed bundle names into
    #
    my %bundle_done;


    #  Do it
    #
    $self->bundle_print({

	bundle		=>  $bundle,
	bundle_hr	=>  $bundle_hr,
	format_cr	=>  $format_cr,
	bundle_done_hr	=>  \%bundle_done,

    }) || return err();


    #  Get a list of modules that are out of date
    #
    my $upgrade_hr=$self->bundle_upgrade_status({

	bundle_hr   =>	$bundle_hr,

    }) || return err();



    #  If any keys > 0 means we need an upgrade
    #
    if (grep {$_} values %{$upgrade_hr}) {


	#  We need some upgrades, so ask user if they wish to continue
	#
	my $text='Modules marked with an asterisk(*) will be installed or upgraded. ';
	$downgrade_fg && (
	    $text.="Modules marked \nwith (!) will only be downgraded if you ".
		"select the \"all\" option, or force \ninstallation at end of the upgrade.\n");
	print "\n${text}\n";
	my $yesno=ExtUtils::MakeMaker::prompt('Do you wish to continue (yes|all|quit) ? ','yes');
	#print "yn $yesno\n";
	$yesno=~/^q|quit$/i && exit 0;
	$yesno=~/^a|all$/i  && ($force_all_sr && ${$force_all_sr}++);


    }
    else {


	#  Everything appears to be up to date, but give user a chance to
	#  continue anyway
	#
	print "\n",
	    "All modules appear to be up to date.\n";
	my $yesno=ExtUtils::MakeMaker::prompt('Do you wish to continue anyway?','no');


	#  Quit unless they insist, in which case force
	#
        ($yesno=~/^y|yes$/i) || exit 0;
	$force_all_sr && ${$force_all_sr}++;

    }


    #  If we get here user wants to upgrade, so return OK
    #
    return $upgrade_hr

}


sub bundle_upgrade_result {


    #  Method to check installed modules, and then offer to upgrade
    #  them for user if they are out of date
    #
    my ($self, $param)=@_;


    #  Get the module list array
    #
    my ($bundle, $bundle_hr)=@{$param}{qw(bundle bundle_hr)};


    #  Code ref to pretty print bundle info
    #
    my $format_cr=sub {


	#  Get self ref, module array ref
	#
	my ($self, $bundle_name, $module_ar)=@_;


	#  Get details
	#
	my ($name, $have_version, $want_version, $upgrade)=
	    @{$module_ar}[$name_ix, $have_ix, $want_ix, $upgrade_ix];


	#  Var to hold result
	#
	my $return;


	#  Format result
	#
	#  Format result
	#
	unless ($upgrade) {
	    $return=sprintf('[%s -  OK ]', $have_version);
	}
	else {
	    $return=sprintf('[%s - FAIL]', $want_version || 'Unknown',
			    $want_version)
	}


	#  Return
	#
	return \$return;

    };


    #  Show the user a list of what will be upgraded
    #
    print "\n";
    print "Results of distributrion installation:\n\n";


    #  Allow bundle_print to keep track of bundles already printed my supplying
    #  hash for it to store printed bundle names into
    #
    my %bundle_done;


    #  Do it
    #
    $self->bundle_print({

	bundle		=>  $bundle,
	bundle_hr	=>  $bundle_hr,
	format_cr	=>  $format_cr,
	bundle_done_hr	=>  \%bundle_done,

    }) || return err();


    #
    #
    print "\n";


    #  Done
    #
    return OK;

}


sub cpan_reload {


    #  Create module and bundle instances in the CPAN.pm name space
    #
    my ($self, $param)=@_;


    #  Get cwd
    #
    my $cwd=$param->{'cwd'};


    #  And reload CPAN
    #
    CPAN::Config->unload();
    undef %CPAN::Config::;
    chdir $cwd ||
	return err("unable to return to cwd $cwd");
    CPAN::Shell->reload('cpan'); # ||
    #return err('unable to reload CPAN module');
    require CPAN::Config;
    print "CPAN Reloaded !\n";


    #  Done
    #
    return OK;

}


sub bundle_install {


    #  Create module and bundle instances in the CPAN.pm name space
    #
    my ($self, $param)=@_;


    #  Get the module list array
    #
    my ($bundle, $bundle_hr, $upgrade_hr, $cwd, $cpan_hr, $force, $force_all_sr, $bundle_seen_hr, $dumper_ar, $ppd_file_hr)=
	@{$param}{qw(bundle bundle_hr upgrade_hr cwd cpan_hr force force_all_sr bundle_seen_hr dumper_ar ppd_file_hr)};



    #  Now read in the Bundle dump file
    #
    unless (@{$dumper_ar}) {
	return err('Bundle dump file empty !')};
    my ($module_hr, $cpan_file_hr, $module_order_ar)=@{$dumper_ar};


    #  Make module->cpan file map
    #
    my %mod2cpan_file;
    while (my ($cpan_file, $module_ar) = each %{$cpan_file_hr}) {
	foreach my $module (@{$module_ar}) {
	    $mod2cpan_file{$module}=$cpan_file;
	}
    }


    #  Check for PPD files, remove alster dist's for those if present
    #
    my %ppd_file;
    while (my ($module, $ppd_file_cn)=each %{$ppd_file_hr}) {
	my $cpan_file=$mod2cpan_file{$module} ||
	    return err("unable to find CPAN dist file associated with module '$module'");
	$ppd_file{$cpan_file}=$ppd_file_cn;
    }



    #  Set up hash for bundles we have already seen so do not do twice
    #
    my %dist_seen;


    #  Go through
    #
    foreach my $module (@{$module_order_ar}) {


	#  Skip if no need to upgrade
	#
	next unless $upgrade_hr->{$module};


        #  Now reload CPAN.pm module data space, as CPAN has annoying habit
        #  of restarting if it installs a module it uses
        #
        $self->cpan_store({

	    dumper_ar	=> $dumper_ar,

        }) || return err();


	#  Get CPAN object, dist file, skip if already done
	#
	my $cpan_module_or=CPAN::Shell->expand('Module', $module) || do {
	    next if $module=~/^Bundle::/;
	    return err("unable to expand (via CPAN::Shell->expand bundle $module");
	};
	my $cpan_file=$mod2cpan_file{$module} ||
	    return err("unable to get CPAN file for module $module");
	next if $dist_seen{$cpan_file}++;



	#  If PPD file available use that
	#
	if (my $ppd_cn=$ppd_file{$cpan_file}) {
	    $self->ppd_install($ppd_cn) ||
		return err("unable to install PPD file '$ppd_cn'");
	    next;
	}


	#  No PPD file, just use CPAN to install
	#
        my $cpan_dist_or=CPAN::Shell->expand('Distribution', $cpan_file) ||
	    return err("unable to expand (via CPAN::Shell->expand distribution $cpan_file");



        #  Are we forcing, if handle differently. Special check for CPAN module, 
        #  must force installation because we include latest CPAN.pm in bundle, this
        #  Makefile.PL uses latest one and thinks installed CPAN alreaduy uptodate,
        #  which is not neccessarily true
        #
        if ($force && !(${$force_all_sr})) { 


            #  Check with user before forcing, only force if user agrees
            #
            if (${$self->dist_install_force({

                cpan_file		=> $cpan_file,
                force_all_sr		=> $force_all_sr,


            }) || return err()}) {


                #  We are forcing this dist
                #
                $cpan_dist_or->force();

            }
	    else {

		next;

	    }

        }
        elsif (${$force_all_sr} || ($module eq 'CPAN') || $Makeflags{'PREFIX'} || $ENV{'PREFIX'}) {


            #  We are forcing all
            #
            $cpan_dist_or->force();

        }


        #  Install. Do not bother checking return code, CPAN seems to
        #  always returns 1
        #
        $cpan_dist_or->install();


    }


    #  Done
    #
    return OK;

}



#  Install using PPD
#
sub ppd_install {


    my ($self, $ppd_cn)=@_;


    #  Need the PPD modules here
    #
    require PPM::UI;
    require PPM::Config;
    require Storable;



    #  Get target name
    #
    my $target=(&PPM::UI::target_list()->result_l)[0];


    #  If installing to user dir alter target
    #
    if (my $prefix_dn=$Makeflags{'PREFIX'}) {


	#  Name of our new temporary target
	#
	my $target_new="TEMP_$$";


	#  Munge it in
	#
	my $target_hr=&PPM::Config::load_config_file('targets', 'ro') ||
	    return err("unable to load PPM::Config 'targets' config");
	#return err("target '$target_new' already exists - please remove or rename")
	#    if $target_hr->{'DATA'}{$target_new};
	my $target_new_hr=Storable::dclone($target_hr->{'DATA'}{$target});
	&PPM::UI::target_add($target_new, %{$target_new_hr});
	&PPM::UI::target_config_set($target_new, 'root', $prefix_dn );
	$target=$target_new;

    }


    #  PPD install options
    #
    my %ppd_opt=(

	verbose	    =>  1,
	dryrun	    =>  0,
	follow	    =>  0,
	force	    =>  1,

       );


    #  Do it
    #
    my $ppd_result_or=&PPM::UI::install(undef, $target, $ppd_cn, \%ppd_opt, sub {}) ||
	return err("no result returned from PPD install of '$ppd_cn'");


    #  We do not check results here at the moment, we will check correct module is installed
    #  later;
    #
    return OK;

}



#  Populate CPAN database with local modules
#
sub cpan_store {


    #  Create module and bundle instances in the CPAN.pm name space
    #
    my ($self,$param)=@_;


    #  Go through each module in the hash, add it as a CPAN instance
    #
    my $dumper_ar=$param->{'dumper_ar'} ||
	return err('empty dumper array');
    my ($module_hr, $dist_hr)=@{$dumper_ar};
    while (my ($cpan_file, $module_ar)=each %{$dist_hr}) {


	#  Create the dist object
	#
	$CPAN::META->instance('CPAN::Distribution', $cpan_file) ||
	    return err("unable to create CPAN::Distribution instance for $cpan_file");


	#  Create the module objects for this dist
	#
	foreach my $module (@{$module_ar}) {


	    #  Get module version
	    #
	    my $version=$module_hr->{$module} ||
		return err("unable to get version information for module $module");


	    #  Set in a CPAN instance
	    #
	    my $cpan_module_or=$CPAN::META->instance('CPAN::Module', $module) ||
		return err("unable to create CPAN::Module instance for $module");
	    $cpan_module_or->set(

		'CPAN_FILE'	    =>  $cpan_file,
		'CPAN_VERSION'  =>   $version

	       );

	    #  Is the module actually a bundle ?
	    #
	    if ($module=~/^Bundle::/) {


		#  Yes, it is a bundle, so create a Bundle instance also - seem to have to
		#
		my $cpan_bundle_or=$CPAN::META->instance('CPAN::Bundle', $module) ||
		    return err("unable to create CPAN::Bundle instance for $module");
		$cpan_bundle_or->set(

		    'CPAN_FILE'	    =>  $cpan_file,
		    'CPAN_VERSION'  =>   $version

		   );
	    }
	}
    }


    #  All done
    #
    return OK

}



#  Pulled straight from dist module
#
sub bundle_contains {


    #  Method to expand a CPAN bundle into a list of modules to
    #  be installed
    #
    my ($self, $param)=@_;


    #  Call the expand method that actually does the work
    #
    my $bundle=$param->{'bundle'} ||
	return err("empty bundle param");


    #  Hash to hold contents
    #
    my %bundle;


    #  Get core modules, so we do not try to install them. Get perl distribution
    #  file name via subterfuge of getting "strict" module (we know is in core)
    #  info
    #
    my $cpan_strict_or=CPAN::Shell->expand('Module', 'strict') ||
	return err('unable to expand strict module');
    my $perl_dist_fn=$cpan_strict_or->cpan_file() ||
	return err('unable to get CPAN perl core file location');


    #  Now expand
    #
    my $cpan_perl_or=CPAN::Shell->expand('Distribution', $perl_dist_fn) ||
	return err("unable to expand perl core $perl_dist_fn");
    my @module_core=($cpan_perl_or->containsmods(), @Module_CORE);
    my %module_core=map { $_=>1 } @module_core;


    #  Expand
    #
    $self->bundle_contains_expand({

	bundle		=>  $bundle,
	bundle_hr	=>  \%bundle,
	module_core_hr	=>  \%module_core,

    }) || return err();


    #  Check the upgrade bit for this bundle. If undefined install version
    #  *and* all defined module are uptodate, the reset to 0 (no upgrade)
    #
    my $bundle_ar=$bundle{$bundle};
    my $bundle_module_ar=$bundle_ar->[0];


    #  Get details
    #
    my ($have_version, $want_version, $upgrade)=
	@{$bundle_module_ar}[$have_ix, $want_ix, $upgrade_ix];


    #  Now check that we were able to get something, if OK, populate modlist
    #  ref
    #
    (keys %bundle) || return err("$bundle appears empty, or could not expand");


    #  All done
    #
    return \%bundle;

}



#  Pulled straight from dist module
#
sub bundle_contains_expand {


    #  Recursive method that expands a CPAN bundle
    #
    my ($self, $param)=@_;


    #  Get bundle from param
    #
    my ($bundle, $bundle_hr, $module_core_hr)=
	@{$param}{qw(bundle bundle_hr module_core_hr)};
    my @modlist;


    #  Get a bundle reference for the supplied bundle name, or
    #  return warning
    #
    my $cpan_bundle_or=CPAN::Shell->expand('Bundle', $bundle) ||
	return err("unable to create CPAN::Bundle instance for $bundle");


    #  Get versions, strip leading 0's
    #
    my $want_version=$cpan_bundle_or->cpan_version();
    my $have_version=&bundle_inst_version($cpan_bundle_or, $bundle);
    $want_version=~s/^0+(?!\.)//;
    $have_version=~s/^0+(?!\.)//;


    #  Compare versions, but only if we already have one
    #
    my $upgrade=$have_version ? CPAN::Version->vcmp($want_version, $have_version) : 0;


    #  Store into arrau
    #
    my @bundle;
    @bundle[$name_ix, $have_ix, $want_ix, $upgrade_ix]=
	( $bundle, $have_version, $want_version, $upgrade);


    #  And store into modlist array
    #
    push @modlist, \@bundle;


    #  Go through each module in the bundle, checking if it
    #  is actually another Bundle
    #
    foreach my $module ($cpan_bundle_or->contains()) {


	#  Var to hold module type
	#
	my $cpan_type;


	#  This bundle contains the name of another bundle,
	#  so call ourselves recursively after checking we
	#  are not going to go in an endless loop
	#
	if ($module=~/^Bundle::/) {


	    #  It is a bundle. Recurse
	    #
	    $self->bundle_contains_expand({

		bundle		=>  $module,
		bundle_hr	=>  $bundle_hr,
		module_core_hr	=>  $module_core_hr,

	    }) || return err();



	    #  Push whatever the recurse for that bundle thinks is
	    #  appropriate, move onto next
	    #
	    push @modlist, $bundle_hr->{$module}->[0];
	    next;

	}


	#  Get a Cpan instace for this module
	#
	my $cpan_module_or=CPAN::Shell->expand('Module', $module) ||
	    return err("unable to expand (via CPAN::Shell->expand module $module");


	#  Get versions
	#
	my $want_version=$cpan_module_or->cpan_version();
	my $have_version=&bundle_inst_version($cpan_module_or, $module);


	#  Compare versions, add result to bundle upgrade flag
	#
	my $upgrade=CPAN::Version->vcmp($want_version, $have_version);



	#  Special case if core module
	#
	if ($module_core_hr->{$module}) {


	    #  Core module, ignore
	    #
	    $have_version='CORE';
	    $upgrade=0;

	}
	$bundle[$upgrade_ix]+=$upgrade;


	#  Store away
	#
	my @module;
	@module[$name_ix, $have_ix, $want_ix, $upgrade_ix]=
	    ( $module, $have_version, $want_version, $upgrade);


	#  Push all onto modlist
	#
	push @modlist,\@module;

    }


    #  If bundle does not need to be upgraded, but has no defined version
    #  installed, make the inst version = have version
    #
    $bundle[$upgrade_ix] || do {
	$bundle[$have_ix] ||= $bundle[$want_ix] };


    #  Done, push modlist onto hash
    #
    $bundle_hr->{$bundle}=\@modlist;


    #  Done
    #
    return OK;

}


sub bundle_upgrade_status {


    #  Get a single hash giving update status
    #
    my ($self, $param)=@_;


    #  Get the params
    #
    my $bundle_hr=$param->{'bundle_hr'};


    #  Hash to hold results
    #
    my %upgrade;


    #  Start going through each bundle
    #
    foreach my $bundle_ar (values %{$bundle_hr}) {


	#  Go through modules
	#
	foreach my $module_ar (@{$bundle_ar}) {


	    #  Get status
	    #
	    my ($name, $upgrade)=
		@{$module_ar}[$name_ix, $upgrade_ix];


	    #  Save into hash
	    #
	    $upgrade{$name}+=$upgrade;

	}
    }


    #  Return
    #
    return \%upgrade;

}


sub bundle_print {


    #  Print bundle and module structure (indented) and status
    #  ie version info etc
    #
    my ($self, $param)=@_;


    #  Shortuct params to vars
    #
    my ($bundle, $bundle_hr, $bundle_done_hr, $format_cr, $indent)=
	@{$param}{qw(bundle bundle_hr bundle_done_hr format_cr indent)};


    #  Set formline template and work out space padding based on
    #  current indent
    #
    my $format='  @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<  @>>>>>>>>>>>>>>>>>>>>>>@';
    my $padding=('  ' x ($indent *2));


    #  Get bundle module array
    #
    my $bundle_ar=$bundle_hr->{$bundle} ||
	return err("unable to get module list for bundle $bundle");


    #  Get whatever text should be printed about this bundle, details
    #  of which (name ver etc) are always index 0 of the array, print it
    #
    my $format_text_sr=$format_cr->($self, $bundle, $bundle_ar->[0]) ||
	return err();
    formline "$format\n", $padding."[$bundle]", ${$format_text_sr};
    print $^A; undef $^A;


    #  Skip rest if already done *and* bundle_done hr supplied as part of
    #  call
    #
    $bundle_done_hr && ($bundle_done_hr->{$bundle}++ && return OK);


    #  Iterate through all modules in the bundle
    #
    foreach my $module_ix (1 .. $#{$bundle_ar}) {


	#  Get array ref
	#
	my $module_ar=$bundle_ar->[$module_ix];


	#  Get name
	#
	my $module=$module_ar->[$name_ix];


	#  If this module is actually a bundle, then recursively call ourselves
	#  to print out *that* bunlde structure *unless* we have already done
	#  so before.
	#
	if ($module=~/^Bundle\:\:/) {


	    #  Recursively call ourselves
	    #
	    $self->bundle_print({

		bundle		=>  $module,
		bundle_hr	=>  $bundle_hr,
		bundle_done_hr	=>  $bundle_done_hr,
		format_cr	=>  $format_cr,
		indent		=>  ($indent+1),

	    }) || return err();


	}
	else {


	    #  Not a bundle. Get module info, print status depending of whether the
	    #  module is up to date or not
	    #
	    my $format_text_sr=$format_cr->($self, $bundle, $module_ar) ||
		return err();


	    #  Print
	    #
	    formline "$format\n", "$padding $module", ${$format_text_sr};
	    print $^A; undef $^A;

	}
    }


    #  If we are at the end, print a nice trailer
    #
    unless ($indent) {
	print "  [End]\n";
    }


    #  Done
    #
    return OK;


}


sub err {

    #  Error and die methods, very simple. We used to return errors, now
    #  we just croak
    #
    croak(sprintf(shift,@_));

}


sub log {


    #  Get self ref, message
    #
    my ($self, $message, @param)=@_;


    #  Log messages. Get file handle
    #
    my $log_fh=($self->{'_log_fh'} ||= IO::File->new(
	File::Spec->catfile($Cwd, 'bundle.log'), O_WRONLY|O_CREAT|O_TRUNC) ||
	    return err("unable to open bundle log file, $!"));

    #  Get time
    #
    my $time=strftime('%Y-%m-%d %T ', localtime());


    #  Write message
    #
    print $log_fh $time . sprintf($message, @param) . "\n";


}


sub uptodate {

    #  Only called if uptodate not present in CPAN::Module
    #
    shift;
    my($self) = @_;
    my($latest) = $self->cpan_version;
    $latest ||= 0;
    my($inst_file) = $self->inst_file;
    my($have) = 0;
    if (defined $inst_file) {
	$have = $self->inst_version;
    }
    local($^W)=0;
    if ($inst_file
	    &&
		$have >= $latest
	       ) {
	return 1;
    }
    return;

}


#-> sub CPAN::Distribution::perl ;
#
#  Ripped direct from CPAN.pm, but modified to include patch module
#  in perl program that runs Makefile.PL when building modules
#
sub perl {
    my($self) = @_;
    my($package_build_name, $package_id) = @{$self}{qw(CALLED_FOR ID)};
    my($perl) = MM->file_name_is_absolute($^X) ? $^X : "";
    my $getcwd = $CPAN::Config->{'getcwd'} || 'cwd';
    my $pwd  = CPAN->$getcwd();
    #my $pwd  = CPAN::anycwd();
    my $candidate = MM->catfile($pwd,$^X);
    $perl ||= $candidate if MM->maybe_command($candidate);
    unless ($perl) {
	my ($component,$perl_name);
	DIST_PERLNAME: foreach $perl_name ($^X, 'perl', 'perl5', "perl$]") {
	    PATH_COMPONENT: foreach $component (MM->path(),
						$Config::Config{'binexp'}) {
		next unless defined($component) && $component;
		my($abs) = MM->catfile($component,$perl_name);
		if (MM->maybe_command($abs)) {
		    $perl = $abs;
		    last DIST_PERLNAME;
		}
	    }
	}
    }
    my $inc;
    map { $inc.=" -I$_" } @Inc;
    $perl.= "$inc -I$main::Cwd -MPatch=$perl,$package_build_name,$package_id ";
    $perl;
}


#-> sub CPAN::Bundle::inst_file
#
#  Ensures that we do not find old Bundle files in the @INC path when we
#  are installing. Having this stub means than CPAN will always think it
#  needs to expand the Bundle file from our package, rather than getting
#  an old one from @INC.
#
sub CPAN::Distribution::test { shift()->make() }
sub CPAN::Bundle::inst_file  { }

__DATA__

$_ = {
  'NAME' => 'Bundle::WebDyne::Dist',
  'AUTHOR' => 'Andrew Speer <andrew.speer@isolutions.com.au>',
  'depend' => {
    'Makefile' => '$(VERSION_FROM)'
  },
  'dist' => {
    'COMPRESS' => 'gzip -9f',
    'SUFFIX' => '.gz'
  },
  'PM' => {
    'lib/Bundle/WebDyne/Dist.pm' => '$(INST_LIBDIR)/Dist.pm',
    'LICENSE' => '$(INST_LIBDIR)/Dist/LICENSE',
    'Dumper.pm' => '$(INST_LIBDIR)/Dumper.pm'
  },
  'VERSION' => '1.26',
  'VERSION_FROM' => 'lib/Bundle/WebDyne/Dist.pm',
  'macro' => {
    'CPAN_FILE' => 'A/AS/ASPEER/Bundle-WebDyne-Dist-1.26.tar.gz',
    'TEMPLATE_RPM' => '$(DISTNAME).spec',
    'COPYRIGHT' => 'Copyright (c) 2003 Andrew Speer, All rights reserved',
    'VENDOR' => 'Andrew Speer <andrew.speer@isolutions.com.au>',
    'PACKAGER' => 'Andrew Speer <andrew.speer@isolutions.com.au>',
    'LICENSE' => 'GPL: GNU General Public License'
  },
  'ABSTRACT_FROM' => 'lib/Bundle/WebDyne/Dist.pm'
};

