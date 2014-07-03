Impplementation notes
=====================

Some notes after the first script draft...

Language choice
---------------

Recursing and control flow in bash is not quite as bad as I thought it was, so I will stick to it for now.

Optimization of resources
-------------------------

One thing that I am concerned about presently is that the pre-processing technique of going through the entire dir tree and creating new files is that this can add a ginormous overhead... worst case scenario the user might need 50% of their disk space free just to run this ...

An alternative method could be to

1. archive with rsync and excluding large files
2. THEN recurse the directory and
	a. swap out the archived RSRC files for their TAR equivalents (tar directly)
	b. cause split on large files to write the result files directly to the destination

This means that a lot of RSRC files will be double-copied, but that shouldn't be too problematic, as the proportion of RSRC should be fairly low in any sane environment...

In restoring, we

1. exclude the middle-files from the initial rsync task
2. post-process the archive directory
	a. check MD5 sums - if matching don't bother processing
	b. unpack/cat the file direct to live disk
	c. check final MD5
	e. rm old, mv new

Hmmm....  yes this is a much better idea...!

Run command
-----------

The command should now look like this:

fullsync32 { -a | -r } live=LIVEDIR archive=BACKUPDIR

mode "a" : archival
mode "r" : restore

Very, very simple.