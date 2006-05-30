%define _fc %(grep -s -c -i fedora /etc/issue)
%define _su %(grep -s -c -i suse   /etc/issue)
%define _rh %(grep -s -c -i redhat /etc/issue)
%define _ce %(grep -s -c -i centos /etc/issue)
%if %{_fc} || %{_rh} || %{_ce}
%define _dist %(%{__perl} -nle '/^(\\w+).*?(\\d+\\.?\\d*).*\\((\\w+)\\)/ && print lc("$1.$2.$3")' /etc/issue)
%endif
%if %{_su} 
%define _dist %(%{__perl} -nle '/^(\\w+).*?(\\d+\\.?\\d*).*\\((\\w+)\\)/ && print lc("$1.$2")' /etc/SuSE-release)
%endif

Name: 		<!-- $DISTNAME -->
Version: 	<!-- $VERSION -->
Release: 	1.%{_dist}
Packager: 	<!-- $PACKAGER -->
Summary: 	<!-- $DISTNAME -->
License: 	<!-- $LICENSE -->
Group: 		Applications/Internet
Buildroot: 	%{_tmppath}/%{name}-root
BuildArch: 	<!-- $ARCH -->
BuildRequires: 	perl >= 0:5.8
Source0: 	<!-- $DISTVNAME -->.tar.gz
Provides:	perl(<!-- $NAME -->)
Prefix:		<!-- $PREFIX -->
AutoProv:	0
AutoReq:	0


%if %{_fc} || %{_rh} || %{_ce}
Requires:	perl,mod_perl,httpd
BuildPreReq:	perl,patch,db4-devel,gcc
%endif
%if %{_su}
Requires:	perl,apache2-mod_perl
BuildPreReq:	perl,patch,db-devel,gcc
%endif

%description
<!-- $DISTNAME --> bundle. Webdyne is an Apache/Perl (mod_perl) integration engine


#  Installation dest dir
#
%define __inst_dir <!-- $PREFIX -->


#  Preparation stage, customise our find_provides and find_depends. Because
#  we are installing into our own /opt directory the supplied ones are not
#  accurate.
#
%prep
echo Dist %{_dist}
%setup -q -n <!-- $DISTVNAME -->
cat <<EOF > %{_builddir}/%{name}-%{version}/my-findprov
#!/bin/sh
%{__find_provides} > /dev/null
EOF
%define __find_provides %{_builddir}/%{name}-%{version}/my-findprov
chmod +x %{__find_provides}

cat <<EOF > %{_builddir}/%{name}-%{version}/my-finddep
#!/bin/sh
%{__find_depends} > /dev/null
EOF
%define __find_depends %{_builddir}/%{name}-%{version}/my-finddep
chmod +x %{__find_depends}


%clean
[ "$RPM_BUILD_ROOT" != "/" ] && rm -rf $RPM_BUILD_ROOT


%build
CFLAGS="$RPM_OPT_FLAGS" %{__perl} Makefile.PL 


%install

[ "$RPM_BUILD_ROOT" != "/" ] && rm -rf $RPM_BUILD_ROOT
eval `perl '-V:installarchlib'`
mkdir -p $RPM_BUILD_ROOT/$installarchlib
make PREFIX=$RPM_BUILD_ROOT%{__inst_dir} install NOPROMPT=1

[ -x /usr/lib/rpm/brp-compress ] && /usr/lib/rpm/brp-compress

find $RPM_BUILD_ROOT/ -name '.packlist'    -exec rm -f {} \;
find $RPM_BUILD_ROOT/ -name 'perlocal.pod' -exec rm -f {} \;
find $RPM_BUILD_ROOT%{__inst_dir} -type f -print | \
sed "s@^$RPM_BUILD_ROOT@@g" > <!-- $DISTVNAME -->-filelist
if [ "$(cat <!-- $DISTVNAME -->-filelist)X" = "X" ] ; then
echo "ERROR: EMPTY FILE LIST"
exit 1
fi
find $RPM_BUILD_ROOT%{__inst_dir} -type d -print | \
sed "s@^$RPM_BUILD_ROOT@@g" | \
sed "s@^.*\$@%dir &@" >> <!-- $DISTVNAME -->-filelist


%postun
rmdir <!-- $PREFIX --> 2>/dev/null
/bin/true


%files -f <!-- $DISTVNAME -->-filelist
%defattr(-,root,root)


%changelog
* <!-- require POSIX; POSIX::strftime('%a %b %d %Y  ', localtime()) . $PACKAGER -->
- Specfile auto-generated.
