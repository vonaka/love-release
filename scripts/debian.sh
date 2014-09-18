# Debian package
init_module "Debian"


PACKAGE_NAME=$(echo $PROJECT_NAME | sed -e 's/[^-a-zA-Z0-9_]/-/g' | tr '[:upper:]' '[:lower:]')

# Configuration
if [ "$CONFIG" =  true ]; then
    if [ -n "${INI__debian__package_version}" ]; then
        PACKAGE_VERSION=${INI__debian__package_version}
    fi
    if [ -n "${INI__debian__maintainer_name}" ]; then
        MAINTAINER_NAME=${INI__debian__maintainer_name}
    fi
    if [ -n "${INI__debian__maintainer_email}" ]; then
        MAINTAINER_EMAIL=${INI__debian__maintainer_email}
    fi
    if [ -n "${INI__android__package_name}" ]; then
        PACKAGE_NAME=${INI__debian__package_name}
    fi
    if [ -n "${INI__debian__icon}" ]; then
        IFS=$'\n'
        ICON_DIR=${INI__debian__icon}
        ICON_FILES=( $(ls -AC1 "$ICON_DIR") )
    fi
fi


# Options
while getoptex "$SCRIPT_ARGS" "$@"
do
    if [ "$OPTOPT" = "deb-package-version" ]; then
        PACKAGE_VERSION=$OPTARG
    elif [ "$OPTOPT" = "deb-maintainer-name" ]; then
        MAINTAINER_NAME=$OPTARG
    elif [ "$OPTOPT" = "maintainer-email" ]; then
        MAINTAINER_EMAIL=$OPTARG
    elif [ "$OPTOPT" = "deb-package-name" ]; then
        PACKAGE_NAME=$OPTARG
        package_name_defined_argument=true
    elif [ "$OPTOPT" = "deb-icon" ]; then
        IFS=$'\n'
        ICON_DIR=$OPTARG
        ICON_FILES=( $(ls -AC1 "$ICON_DIR") )
    fi
done


# Debian
MISSING_INFO=0
ERROR_MSG="Could not build Debian package."
if [ -z "$PACKAGE_VERSION" ]; then
    MISSING_INFO=1
    ERROR_MSG="$ERROR_MSG\nMissing project's version. Use --deb-package-version."
fi
if [ -z "$PROJECT_HOMEPAGE" ]; then
    MISSING_INFO=1
    ERROR_MSG="$ERROR_MSG\nMissing project's homepage. Use --homepage."
fi
if [ -z "$PROJECT_DESCRIPTION" ]; then
    MISSING_INFO=1
    ERROR_MSG="$ERROR_MSG\nMissing project's description. Use --description."
fi
if [ -z "$MAINTAINER_NAME" ]; then
    MISSING_INFO=1
    ERROR_MSG="$ERROR_MSG\nMissing maintainer's name. Use --deb-maintainer-name."
fi
if [ -z "$MAINTAINER_EMAIL" ]; then
    MISSING_INFO=1
    ERROR_MSG="$ERROR_MSG\nMissing maintainer's email. Use --maintainer-email."
fi
if [ "$MISSING_INFO" -eq 1  ]; then
    exit_module "$MISSING_INFO" "$ERROR_MSG"
fi


create_love_file 9


TEMP=`mktemp -d`
mkdir -p $TEMP/DEBIAN

echo "Package: $PACKAGE_NAME"    >  $TEMP/DEBIAN/control
echo "Version: $PACKAGE_VERSION" >> $TEMP/DEBIAN/control
echo "Architecture: all"         >> $TEMP/DEBIAN/control
echo "Maintainer: $MAINTAINER_NAME <$MAINTAINER_EMAIL>" >> $TEMP/DEBIAN/control
echo "Installed-Size: $(echo "$(stat -c %s "$PROJECT_NAME".love) / 1024" | bc)" >> $TEMP/DEBIAN/control
echo "Depends: love (>= $LOVE_VERSION)"   >> $TEMP/DEBIAN/control
echo "Priority: extra"                    >> $TEMP/DEBIAN/control
echo "Homepage: $PROJECT_HOMEPAGE"        >> $TEMP/DEBIAN/control
echo "Description: $PROJECT_DESCRIPTION"  >> $TEMP/DEBIAN/control
chmod 0644 $TEMP/DEBIAN/control

DESKTOP=$TEMP/usr/share/applications/"$PACKAGE_NAME".desktop
mkdir -p $TEMP/usr/share/applications
echo "[Desktop Entry]"              >  $DESKTOP
echo "Name=$PROJECT_NAME"           >> $DESKTOP
echo "Comment=$PROJECT_DESCRIPTION" >> $DESKTOP
echo "Exec=$PACKAGE_NAME"           >> $DESKTOP
echo "Type=Application"             >> $DESKTOP
echo "Categories=Game;"             >> $DESKTOP
chmod 0644 $DESKTOP

PACKAGE_DIR=/usr/share/games/"$PACKAGE_NAME"/
PACKAGE_LOC=$PACKAGE_NAME-$PACKAGE_VERSION.love

mkdir -p $TEMP"$PACKAGE_DIR"
cp "$LOVE_FILE" $TEMP"$PACKAGE_DIR""$PACKAGE_LOC"
chmod 0644 $TEMP"$PACKAGE_DIR""$PACKAGE_LOC"

BIN_LOC=/usr/bin/
mkdir -p $TEMP$BIN_LOC
echo "#!/usr/bin/env bash" >  $TEMP$BIN_LOC"$PACKAGE_NAME"
echo "set -e"              >> $TEMP$BIN_LOC"$PACKAGE_NAME"
echo "love $PACKAGE_DIR$PACKAGE_LOC" >> $TEMP$BIN_LOC"$PACKAGE_NAME"
chmod 0755 $TEMP$BIN_LOC"$PACKAGE_NAME"

ICON_LOC=/usr/share/icons/hicolor/
mkdir -p $TEMP$ICON_LOC
if [ -n "$ICON_DIR" ]; then
    echo "Icon=$PACKAGE_NAME" >> $DESKTOP
    for ICON in "${ICON_FILES[@]}"
    do
        RES=$(echo "$ICON" | grep -Eo "[0-9]+x[0-9]+")
        EXT=$(echo "$ICON" | sed -e 's/.*\.//g')
        if [ "$EXT" = "svg" ]; then
            mkdir -p $TEMP${ICON_LOC}scalable/apps
            cp "$PROJECT_DIR"/"$ICON_DIR"/"$ICON" $TEMP${ICON_LOC}scalable/apps/"$PACKAGE_NAME".$EXT
            chmod 0644 $TEMP${ICON_LOC}scalable/apps/"$PACKAGE_NAME".EXT
        else
            if [ -n "$RES" ]; then
                mkdir -p $TEMP$ICON_LOC$RES/apps
                cp "$PROJECT_DIR"/"$ICON_DIR"/"$ICON" $TEMP$ICON_LOC$RES/apps/"$PACKAGE_NAME".$EXT
                chmod 0644 $TEMP$ICON_LOC$RES/apps/"$PACKAGE_NAME".$EXT
            fi
        fi
    done
else
    echo "Icon=love" >> $DESKTOP
fi


cd $TEMP
for line in $(find usr/ -type f); do
    md5sum $line >> $TEMP/DEBIAN/md5sums
done
chmod 0644 $TEMP/DEBIAN/md5sums

for line in $(find usr/ -type d); do
    chmod 0755 $line
done

fakeroot dpkg-deb -b $TEMP "$RELEASE_DIR"/"$PACKAGE_NAME"-"$PACKAGE_VERSION"_all.deb
cd "$RELEASE_DIR"
rm -rf $TEMP


unset MAINTAINER_NAME MAINTAINER_EMAIL PACKAGE_NAME PACKAGE_VERSION
exit_module

