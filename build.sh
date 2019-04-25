#!/bin/sh
set -e

export GIT_AUTHOR_NAME="ImageJA Builder Travis"
export GIT_AUTHOR_EMAIL="travis@travis-ci.com"

# w3m on mac buggy, use http
URL=http://wsr.imagej.net
SRC_URL=$URL/src
NOTES_URL=$URL/notes.html

echo "*** Get version of uploaded src zip"
VERSION="$(curl $SRC_URL/ | \
	sed -n "s/^.*ij\([0-9a-z]*\)-src.zip.*$/\1/p" | \
	tail -n 1)"
test "$VERSION" || {
	echo "Could not extract version from $SRC_URL" >&2
	exit 1
}
echo "*** Get version from notes and check if this version already exists"
DOTVERSION=$(echo $VERSION | sed "s/^./&./")
git fetch https://github.com/imagej/ImageJA.git master
git log FETCH_HEAD | grep "^      .[^ ]\? $DOTVERSION,\? " && {
	echo "Already have $DOTVERSION"
#	exit 0
}
echo "*** Get src zip"
ZIP=ij$VERSION-src.zip
test -f $ZIP || curl $SRC_URL/$ZIP > $ZIP || {
	echo "Could not get $SRC_URL/$ZIP"
	exit 1
}
echo "*** Get notes zip"
NOTES=notes$VERSION.txt
test -f $NOTES || w3m -cols 72 -dump $NOTES_URL >$NOTES || {
	echo "Could not get notes"
	exit 1
}

# make sure that the sed call succeeds to extract the commit message
LANG=en_US.utf-8
export LANG

echo "Checkout ImageJA"
git clone https://github.com/imagej/ImageJA

cd ImageJA
git tag -a -f -m "Travis Build $TRAVIS_BUILD_NUMBER" travis-ImageJ1-sync-with-notes-$TRAVIS_BUILD_NUMBER

echo "Calling commit-new-version"
(cat ../$NOTES | \
 sed -n \
	-e "s/^  [^ ] $DOTVERSION,\? /•&/" \
	-e "/^[^ ]  [^ ] $DOTVERSION,\? /,\$p" |
 sed \
	-e "/^  [^ ] /,\$d" \
	-e "/^Version/,\$d" \
	-e "s/^[^ ]\(  [^ ] $DOTVERSION,\? \)/\1/" |
 sh -x ../commit-new-version.sh ../$ZIP) || {
	echo "Could not commit!"
	exit 1
}

echo "Calling sync-with-imagej"
sh -x ../sync-with-imagej.sh || {
	echo "Could not update 'master'"
	exit 1
}
test -n "$NO_PUSH" && exit

for REMOTE in \
	git@github.com:imagej/ImageJA
do
	ERR="$(git push $REMOTE imagej master "v$DOTVERSION" 2>&1 ||
	  case "$REMOTE $ERR" in *repo.or.cz*"Connection refused"*)
		  echo "Warning: repo.or.cz was not reachable"
		  ;;
	  *)
		  echo "${ERR}Could not push"
		  exit 1
		;;
	esac
done

#echo "Deploying to Nexus"
#sh deploy-to-nexus.sh

