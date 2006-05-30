#
#
#  Copyright (c) 2003 Andrew W. Speer <andrew.speer@isolutions.com.au>. All rights 
#  reserved.
#
#  This file is part of Bundle::WebDyne::Dist.
#
#  Bundle::WebDyne is free software; you can redistribute it and/or modify
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
#  $Id: Dist.pm,v 1.26 2006/05/28 14:45:22 aspeer Exp $


#
#
package Bundle::WebDyne::Dist;


#  Compiler Pragma
#
use strict qw(vars);
use vars qw($VERSION);


#  Version information in a formate suitable for CPAN etc. Must be
#  all on one line
#
$VERSION=(qw$Revision: 1.26 $)[1];


__END__


=head1 NAME

Bundle::WebDyne::Dist - WebDyne Bundle

=head1 SYNOPSIS

C<perl -MCPAN -e 'install Bundle::WebDyne::Dist'>

=head1 CONTENTS

Digest::base

Net::FTP	#  In Bundle::LWP, but here to override explict version set (but not needed) in LWP

URI		#  In Bundle::LWP, but here to override explict version set (but not needed) in LWP

Bundle::LWP

Bundle::WebMod::Base

BerkeleyDB

HTML::TreeBuilder

Text::Template

Time::HiRes

Tie::IxHash

Storable

CGI

WebDyne

WebDyne::Chain

WebDyne::Err

WebDyne::Template

WebDyne::Session

WebDyne::State

WebDyne::Install

=head1 DESCRIPTION

=head1 AUTHOR

Andrew Speer E<lt>F<andrew.speer@isolutions.com.au>E<gt>

=cut
