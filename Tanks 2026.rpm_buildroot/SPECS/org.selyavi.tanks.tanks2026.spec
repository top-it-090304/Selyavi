Name:       org.selyavi.tanks.tanks2026
# >> macros
%define __requires_exclude ^libfreetype\.so.*|.*libxkbcommon\.so.*$
%define __provides_exclude_from ^/usr/share/%{name}/lib/.*\.so.*$
%define debug_package %{nil}
# << macros
Summary:    Tanks 2026
Version:    1.0.0
Release:    1
Group:      Game
License:    Proprietary
BuildArch:  aarch64
BuildRequires: patchelf

%define _topdir /home/markc_ubuntu/Desktop/GodotProjects/Tanks_2026/Tanks 2026.rpm_buildroot

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
chmod -R 755 %{buildroot}/usr/share/%{name}
patchelf --force-rpath --set-rpath /usr/share/%{name}/lib %{buildroot}/usr/bin/%{name}
# dependencies
install -D %{_libdir}/libfreetype.so.* -t %{buildroot}/usr/share/%{name}/lib/
install -D %{_libdir}/libxkbcommon.so.* -t %{buildroot}/usr/share/%{name}/lib/

%files
%defattr(644,root,root,-)
%attr(755,root,root) /usr/bin/%{name}
/usr/share/icons/hicolor/86x86/apps/%{name}.png
/usr/share/icons/hicolor/108x108/apps/%{name}.png
/usr/share/icons/hicolor/128x128/apps/%{name}.png
/usr/share/icons/hicolor/172x172/apps/%{name}.png
%attr(644,root,root) /usr/share/%{name}/%{name}.pck
/usr/share/%{name}/lib
%attr(644,root,root) /usr/share/applications/%{name}.desktop
%changelog
* Thu Dec 19 2019 Godot Game Engine
- application %{name} packed to RPM
#$changelog$