[![](https://github.com/imagej/ij1-builds/actions/workflows/build-main.yml/badge.svg)](https://github.com/imagej/ij1-builds/actions/workflows/build-main.y

Polls the ImageJ 1.x [notes.html](https://wsr.imagej.net/notes.html) page once a day. 
When changes are detected:
1) the updated notes are committed to ImageJA's 'imagej' branch 
2) the ImageJA's 'master' branch is updated
3) build is deployed to Nexus

## Manual Synchronization Testing

Synchronization from IJ1 > IJA is done with the `sync-with-imagej.sh` script. Of particular interest is the [file manipulation logic](https://github.com/imagej/ij1-builds/blob/a950440dcfaf8e67b3b21752d6d6ff26f2b346a6/sync-with-imagej.sh#L111-L118). This behavior is both nebulous and automated, so it can be helpful to manually test translation before changes go live.

1. Switch to the `dev/testing` branch: `git checkout dev/testing`
1. Clone the ImageJA repo: `git clone https://github.com/imagej/ImageJA.git`
1. Move to the IJA subdir: `cd ImageJA`
1. Add the ImageJ1 remote: `git remote add ij1 https://github.com/imagej/imagej1.git`
1. Fetch the IJ1 repo: `git fetch ij1`
1. Create the imagej branch: `git checkout -b imagej`
1. Set tracking: `git branch --set-upstream-to ij1/master && git reset --hard ij1/master`
1. Return to the ImageJA branch: `git checkout master`

At this point you will have a `master` branch pointing to ImageJA and an `imagej` branch pointing to IJ1. From `master` you can run the `sync-with-imagej.sh` script in this repo to convert the state of `imagej` to `master`.

If you want to change the starting point of the `master` branch you can `git reset --hard tagname` where `tagname` is an imagej release, e.g. `v1.53e`.

If you want to change the sync point of the `imagej` branch you'll have to look through the commits, e.g. for `release v1.53e` and reset to that commit.

Remember to port any changes to `sync-with-imagej.sh` back to the `ij1-builds` `master` branch.
