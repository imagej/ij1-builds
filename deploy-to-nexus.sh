#!/bin/bash
set +e

export GIT_AUTHOR_NAME="Curtis Rueden"
export GIT_AUTHOR_EMAIL="ctrueden@wisc.edu"


NEXUS_URL=http://maven.imagej.net/
SONATYPE_PROXY=$NEXUS_URL/service/local/data_cache/repositories/sonatype/content

git clean -fdx

mvn clean &&
mvn -Psonatype-oss-release deploy &&
curl --netrc -i -X DELETE \
       $SONATYPE_PROXY/net/imagej/ij/maven-metadata.xml

