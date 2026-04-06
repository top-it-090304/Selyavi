Name:       harbour-tanks2026
# >> macros
%define __requires_exclude ^lib(freetype|SDL2).*$
%define __provides_exclude_from ^/usr/share/%{name}/lib/$
# << macros
Summary:    Tanks_2026
Version:    1.0.0
Release:    1
Group:      Game
License:    Proprietary
BuildArch:  armv7hl
URL:        http://example.org/

%define _topdir /home/markc_ubuntu/Desktop/GodotProjects/Tanks_2026/Tanks_2026_arm.rpm_buildroot

%description

%prep
echo "Nothing to do here. Skip this step"
%build
echo "Nothing to do here. Skip this step"
%install
rm -rf %{buildroot}
mkdir -p "%{buildroot}"
mkdir -p "%{buildroot}/usr/bin"
rm -fr "%{buildroot}/usr/bin"
mv "%{_topdir}/BUILD/usr/bin" "%{buildroot}/usr/bin"
mv  "%{_topdir}/BUILD/usr/share" "%{buildroot}/usr/share"
mkdir -p "%{buildroot}/usr/share/applications"
[ -f "%{_topdir}/BUILD/usr/share/applications/%{name}.desktop" ] && mv -f "%{_topdir}/BUILD/usr/share/applications/%{name}.desktop" "%{buildroot}/usr/share/applications/%{name}.desktop"||echo "File moved already"
chmod 755 %{buildroot}/usr/share/icons/hicolor/*
chmod 755 %{buildroot}/usr/share/icons/hicolor/*/apps

%files
%defattr(644,root,root,-)
%attr(755,root,root) /usr/bin/%{name}
/usr/share/icons/hicolor/*
%attr(644,root,root) /usr/share/%{name}/%{name}.pck
%attr(644,root,root) /usr/share/applications/%{name}.desktop
%changelog
* Thu Dec 19 2019 Godot Game Engine
- application %{name} packed to RPM
#$changelog$