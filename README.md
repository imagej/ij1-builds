[![](https://travis-ci.org/imagej/ij1-builds.svg?branch=master)](https://travis-ci.org/imagej/ij1-builds)

Polls the ImageJ 1.x [notes.html](https://wsr.imagej.net/notes.html) page once a day. 
When changes are detected:
1) the updated notes are committed to ImageJA's 'imagej' branch 
2) the ImageJA's 'master' branch is updated
3) javadocs are generated and uploaded to the [scijava javadocs](https://javadoc.scijava.org/ImageJ1) site
4) build is deployed to Nexus

