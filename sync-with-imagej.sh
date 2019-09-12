#!/bin/sh

URL=git://github.com/imagej/ImageJA
BRANCH=refs/heads/master
IJ1BRANCH=refs/heads/imagej

die () {
	echo "$*" >&2
	exit 1
}

debug () {
	if [ "$DEBUG" ]; then echo "[DEBUG] $*"; fi
}

test a--wayne = "a$1" && {
	git fetch git://github.com/imagej/imagej1.git master
	IJ1BRANCH=$(git rev-parse FETCH_HEAD)
	shift
}

debug "BRANCH = $BRANCH"
NEED_TO_UPDATE_WORKING_TREE=
test $(git config --bool core.bare) = true ||
test $BRANCH != "$(git symbolic-ref HEAD 2> /dev/null)" || {
	git update-index -q --refresh &&
        git diff-files --quiet ||
	die "The work tree is dirty"
	NEED_TO_UPDATE_WORKING_TREE=t
}
debug "NEED_TO_UPDATE_WORKING_TREE = $NEED_TO_UPDATE_WORKING_TREE"

ERROR="$(git fetch $URL $BRANCH 2>&1)" ||
die "${ERROR}No branch $BRANCH at $URL?"

HEAD=$(git rev-parse $BRANCH) || {
	HEAD=$(git rev-parse FETCH_HEAD) &&
	git update-ref -m "Initialize synchronization" $BRANCH $HEAD
} ||
die "Could not initialize $BRANCH"
debug "HEAD = $HEAD"

if test "$NEED_TO_UPDATE_WORKING_TREE"
then
	test $HEAD = $(git rev-parse FETCH_HEAD) ||
	die "Branch $BRANCH is not up-to-date!"
fi

IJ1HEAD=$(git rev-parse $IJ1BRANCH) ||
die "No ImageJ1 branch?"
debug "IJ1HEAD = $IJ1HEAD"

test $IJ1HEAD != "$(git merge-base $IJ1HEAD $HEAD)" ||
die "ImageJ1 already fully merged!"

VERSION=$(git log -1 --pretty=format:%s $IJ1HEAD |
	sed -n "s/^[^0-9]*\([^ 0-9A-Za-z] \)\?\([1-9][\\.0-9]*.\)[^0-9A-Za-z].*$/\2/p")

test "$VERSION" || die "Could not determine ImageJ version from branch $IJ1BRANCH"
debug "VERSION = $VERSION"

# write an update without checking anything out
export GIT_INDEX_FILE="$(git rev-parse --git-dir)"/IJ1INDEX &&
git read-tree $IJ1HEAD ||
die "Could not read current ImageJ1 tree"
debug "GIT_INDEX_FILE = $GIT_INDEX_FILE"

# Obtain newest pom-scijava version
MAVEN_URL=https://maven.scijava.org/content/groups/public
POM_SCIJAVA_URL=$MAVEN_URL/org/scijava/pom-scijava
POM_SCIJAVA_VERSION="$(curl -s $POM_SCIJAVA_URL/maven-metadata.xml |
	sed -n 's/.*<release>\(.*\)<\/release>.*/\1/p')"
debug "POM_SCIJAVA_VERSION = $POM_SCIJAVA_VERSION"

# rewrite version in pom.xml
git show $HEAD:pom.xml > "$GIT_INDEX_FILE.pom" &&
sed -e '/^\t</s/\(<version>\).*\(<\/version>\)/\1'"$VERSION"'\2/' \
	-e "/<parent>/,/<\/pa/s/\(<version>\)[^<]*/\1$POM_SCIJAVA_VERSION/" \
	-e "/<parent>/,/<\/pa/s/\(<groupId>\)[^<]*/\1org.scijava/" \
	-e "/<parent>/,/<\/pa/s/\(<artifactId>\)[^<]*/\1pom-scijava/" \
	< "$GIT_INDEX_FILE.pom" > "$GIT_INDEX_FILE.pom.new" &&
POMHASH=$(git hash-object -w "$GIT_INDEX_FILE.pom.new") &&
printf "100644 $POMHASH 0\tpom.xml\n" > "$GIT_INDEX_FILE.list.new" ||
die "Could not update pom.xml"
debug "POMHASH = $POMHASH"

# copy important files from previous HEAD
for file in \
	.gitignore \
	.travis.yml \
	.travis/build.sh \
	.travis/signingkey.asc.enc \
	README.md
do
	REV=$(git rev-parse $HEAD:$file 2>/dev/null) &&
	printf "100644 $REV 0\t$file\n" >> "$GIT_INDEX_FILE.list.new" ||
	die "Could not find $file in the current HEAD"
	debug "Preserving $file (revision=$REV)"
done

git ls-files --stage > "$GIT_INDEX_FILE.list.old" &&
mv "$GIT_INDEX_FILE" "$GIT_INDEX_FILE.old" &&
sed -e 's~\t\(.*\.java\)$~\tsrc/main/java/\1~' \
	-e 's~\tplugins/\(.*\)\.source$~\tsrc/main/java/\1.java~' \
	-e 's~\t\(IJ_Props.txt\|macros/\)~\tsrc/main/resources/\1~' \
	-e 's~\timages/~\tsrc/main/resources/~' \
	-e 's~\t\(MANIFEST.MF\)$~\tsrc/main/resources/META-INF/\1~' \
	-e '/\t\(plugins\/.*\.class\|.FBCIndex\|ij\/plugin\/RandomOvals.txt\)$/d' \
< "$GIT_INDEX_FILE.list.old" >> "$GIT_INDEX_FILE.list.new" &&
git update-index --index-info  < "$GIT_INDEX_FILE.list.new" ||
die "Could not transform $IJ1BRANCH's tree"

echo "Synchronize with ImageJ $VERSION" > "$GIT_INDEX_FILE.message" &&
TREE=$(git write-tree) &&
NEWHEAD="$(git commit-tree $TREE -p $HEAD -p $IJ1HEAD \
	< "$GIT_INDEX_FILE.message")" &&
git update-ref -m "Synchronize with ImageJ1" $BRANCH $NEWHEAD $HEAD ||
die "Could not update $BRANCH"

git tag -a -m "v$VERSION" "v$VERSION" $NEWHEAD ||
die "Could not tag $VERSION"

test -z "$NEED_TO_UPDATE_WORKING_TREE" || {
	echo "Updating work-tree" &&
	unset GIT_INDEX_FILE &&
	git stash
} ||
die "Could not update the working tree"
