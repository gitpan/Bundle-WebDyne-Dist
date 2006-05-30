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
#  $Id: Config.pm.inc,v 1.4 2004/03/27 06:55:20 aspeer Exp $


#  We need the File::Spec and Cwd modules for some path "math"
#

use ExtUtils::MakeMaker;
use Cwd qw(cwd);


#  Work out the various directory names based on our current dir
#
my $cpan_home=ExtUtils::MM_Unix->catdir(cwd(), 'CPAN');
my $build_dir=ExtUtils::MM_Unix->catdir($cpan_home, 'build');
my $keep_source_where=ExtUtils::MM_Unix->catdir($cpan_home, 'sources'); ;
my $urllist=join('///', 'file:', $cpan_home);


# This is CPAN.pm's systemwide configuration file. This file provides
# defaults for users, and the values can be changed in a per-user
# configuration file. The user-config file is being looked for as
# ~/.cpan/CPAN/MyConfig.pm.

$CPAN::Config = {
  'build_cache' => q[100],
  'cache_metadata' => q[0],
  'build_dir' => $build_dir,
  'cpan_home' => $cpan_home,
  'ftp' => q[],
  'ftp_proxy' => q[],
  'getcwd' => q[cwd],
  'gzip' => q[/bin/gzip],
  'http_proxy' => q[],
  'inactivity_timeout' => q[0],
  'index_expire' => q[0],
  'inhibit_startup_message' => q[0],
  'keep_source_where' => $keep_source_where,
  'lynx' => q[],
  'make' => q[/usr/bin/make],
  'make_arg' => q[],
  'make_install_arg' => q[],
  'makepl_arg' => q[],
  'ncftpget' => q[],
  'no_proxy' => q[],
  'pager' => q[/usr/bin/less],
  'prerequisites_policy' => q[never],
  'scan_cache' => q[never],
  'shell' => q[/bin/bash],
  'tar' => q[/bin/tar],
  'unzip' => q[],
  'urllist' => [$urllist],
  'wait_list' => [],
};
1;
__END__
