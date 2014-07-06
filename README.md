fullsync32
==========

Post-processor for rsync to identify files that need special treatment when backing up to FAT32

Reason
======

FAT32 remains the only file system that can be read from and written to without any external libraries on pretty much all the main desktop platforms (Mac, Windows, Linux).

It does however have some limitations, and other filesystems have their own quirks...

This post processor is a project to stymie these bad behaviours and prevent data loss

It's written in bash, partly because I don't like how python does not make it easy to call external processes, partly because I wanted to learn some proper bash scripting...

Problems addressed
------------------

Currently, two main issues are being addressed by this tool:

1. Mac OS X uses resource forks, file data that are not on the regular file track, and that only HFS/HFS+ support. Copying files over to FAT32 strips this extra data, making applications unusable from the backup. Which is not a backup then...

2. FAT32 only supports files up to, and not including, 4GiB in size. Most ISOs and virtual machine libraries are lost in the backup.

Method
======

fullsync32 uses the rsync utility to sync directories as normal, whilst excluding large files.

The post processor then iterates through the source directory:

If in archive mode (live directory to archive), files with resource forks are identified and TAR'd directly to the destination in the backup; the corresponding file in the backup is then removed. Large files are also identified, and are processed through split, directly to the destination. If a large file with resource is found, it is both TAR'd and SPLIT'd directly to destination. When splitting, a meta file with the MD5 and original name (or the original name of the resource TAR) is also written.

In restore mode, (archive directory to live environment), the middle-man files and their MD5 reminders are excluded by name from the rsync restore. Then the post-processor iterates through the archive directories, unpacking TARs and CAT-ing split files, where MD5 sums do not match.

Future versions
===============

Support for other backup utilities is envisaged, but not the main focus right now.

Specifically, I'm thinking of porting this to python; the main reason I am not doing so is because of the obtuseness of the way external commands are called. I can never wrap my head around it, and have to fumble a lot with nested quotes...

However, by porting to python, the solution can be made to work on Windows. The alternative would be to require cygwin or such.

Or, I might look at shipping a set of executables that would make this tool standalone - running, say, from a USB stick.