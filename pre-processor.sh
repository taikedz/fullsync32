#! /bin/bash

cat <<EOF
Rsync pre-processor for backing up to FAT32

$0 -b -live=LVIEDIR -archive=ARCHIVEDIR [--rmexclude]
$0 -r -archive=ARCHIVEDIR -live-LIVEDIR [--keeprawbkp] 

LIVEDIR is the directory that is normally in use.
ARCHIVEDIR is the directory on the backup medium.

Pre-process the directories to backup:

---TAR files that have resource forks into archives to preserve these

Mac OS X files can have resource forks (courtesy of HFS+ filesystem)

Using the OS X tar utility allows packaging the file into a *.tgz file for archiving to prevent the loss of these.

Note that you can only restore the resource forks if you are restoring to a HFS+ filesystem. This is presumably done on a Mac in the first place too. tar utilities other than that bundled with OS X may not support writing the resource forks back.... you are warned.

---split files larger than 4GB into smaller files

The FAT32 file system has an upper limit of 4GB per file.

We split these large files using the "split" utility after saving the MD5 sum and the original name.


OPTIONS

-b specifies backup mode - hunts for resource forks and large files. Simply excludes the original files without deleting them. Hardlinks not recognized at the moment -- 2 files hardlinked to the same data will become 2 separate files in this backup process. To remove original files and leave their archival copies in place, specify --rmexclude as final option

-r specifies restore mode - hunts for *.master.split and *.rsrcfork.tgz files to restore them. By default removes these files unless --keeprawbkp is specified as final option


BACKUP

Uses rsync to perform the backup, with options -avz and an exclusion file

EOF

alias performbackup='rsync -avz'

# ==============================
# generic handles

maybefail() { # arg1=exit code // arg2=message
	if [ $1 != 0 ]; then echo "$2"; exit 1; fi
}

touchorfail() { # argument - path to file to touch
	touch $1
	maybefail $? "Could not create temp file for exclusion: $1"
}

# serious issues with this command when testing in OS X terminal shell. retest as script
filesize() {
	if [ $ISMAC = 'yes' ]; then
		echo $(stat -s $1 | sed -E -e "s/.*st_size=([0-9]+).*/\1/")
	else # assumes Linux
		echo $(stat -c%s $1)
	fi
}

function randomString {
	# adapted from http://utdream.org/post.cfm/bash-generate-a-random-string
	
	# if a param was passed, it's the length of the string we want
	if [[ -n $1 ]] && [[ "$1" -lt 20 ]]; then
		local myStrLength=$1;
	else
		# otherwise set to default
		local myStrLength=8;
	fi

	local mySeedNumber=$$`date +%N`; # seed will be the pid + nanoseconds
	local myRandomString=$( echo $mySeedNumber | md5sum | md5sum );
	# create our actual random string
	echo "${myRandomString:2:myStrLength}"
}

getmd5() {
	NODE=$1
	local md5res=$(md5sum $NODE)
	if [ $ISMAC = 'yes' ]; then
		echo $md5res | sed -E -e 's/MD5 \(.+\) = (.+)$/\1/g')
	else
		echo $md5res | sed -E -e 's/^(.+) .+/\1/g')
	fi
}

rexclude() {
	# exclude a file, then check if it should also be deleted
	echo $1 >> $BKPEXCLUSIONS
	if [ 'empty'"$(echo $@ | grep -e \"--rmexclude\")" != 'empty' ]; then # is this syntax nesting properly?
		rm $1 # do not use force.
		if [ $? -ne 0 ]; then echo "Could not delete $1 for exclusion"; fi
	fi
}

# ==============================
# necessary temp files and vars

BKPEXCLUSIONS=/tmp/preprocessedrsyncexclusions
RSRCTARS=/tmp/preprocessedrsynctars

touchorfail $BKPEXCLUSIONS
touchorfail $RSRCTARS

ISMAC=''
if [ 'empty'$(echo $OSTYPE | grep darwin) != 'empty' ]; then
	ISMAC="yes";
	else ISMAC="no";
fi

if [ $ISMAC = 'yes' ]; then
	alias md5sum='md5'
fi

# ==============================
# resource fork identification
# OS X uses the resource fork construct on some files, which is a hangover from design from the Mac OS Classic days.
# files with resource forks are found on OS X systems, which have their own TAR that can handle them
# TAR the files; exclude the originals


RSRCSTR="/..namedfork/rsrc"
if [ $ISMAC = 'yes' ]; then
	if [ "old"$(sw_vers | grep -Po "10\.[0-6]\.") = "old" ]; then
		RSRCSTR="/rsrc" # different format pre-10.7
	fi
fi

hasrsrc() {
	MYFILE="$1$RSRCSTR"
	FOUNDRES=yes$(ls -l "$MYFILE" | grep -Po "0\s+[0-9]+\s+[a-zA-Z]");
	# resource fork found to be zero length - returns string

	# FOUNDRES is exactly "yes" if resource is non-zero
	if [ "$FOUNDRES" = "yes" ]; then
		echo "yes"
	else
		echo "no"
	fi
}
# ==============================
# check for RSRC presence

RSRC_CHECK=$(hasrsrc $RSRCTARS)
echo "Check for resources? --> $RSRC_CHECK"

# ==============================
# the actual backup and restore processes

# recurse DIR for prep to archive
# $1 is the directory we want to process
prearchive() {
	CURDIR=$1
	cd "$CURDIR"
	# if RSRC_CHECK
	if [ '_'$RSRC_CHECK = '_yes' ]; then
		# iterate over FILES
		for NODE in *; do
			if [ -d "$NODE" ]; then continue; fi
			# if FILE has resource fork
			if [ hasrsrc "$NODE" = 'yes' ]; then
				# compress as TGZ
				tar -cf "${NODE}.rsrcfork.tgz" "$NODE"
				# exclude original FILE
				rexclude "$CURDIR/$NODE"
			fi
		done
	fi

	# iterate over both files and directories
	for NODE in *; do
		if [ -d "$NODE" ]; then
			prearchive "$NODE"
		# if FILE larger than 4000000 bytes
		if [ filesize "$NODE" -gt 4294967295 ]; then
			# random string STRP
			STRP=$(randomString)
			# get MD5 and write STRP + md5 + file name to <STRP>.master.split
			echo $STRP $(getmd5 $NODE) $NODE > $STRP.master.split
			# split with <STRP> as prefix
			split -b 4000m "$NODE" "${STRP}-" # use explicitly 4000M instead of 4G to be safe
			# exclude original FILE
			rexclude "$CURDIR"
		fi
	done
	
	# recurse into directories
	# ......
}

restorearchive() {
}

# TO DO
# restore script
# archive vs restore modes

# archive is: recur dir, rsync, process backup intermediaries (with checksumming)
# 