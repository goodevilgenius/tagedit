#!/bin/sh -eu

# tagedit -- allows batch editing of vorbis comments and id3 tags with an editor
#
# Copyright © Dan Jones <djones109@gmail.com>
# Released under the terms of the New BSD License
#
# Based on vorbistagedit copyright © martin f. krafft <madduck@madduck.net>
#

VERSION=0.6.2.1
ME=${0##*/}

versioninfo() {
  echo "tagedit $VERSION" >&2
  echo "\$Id$" >&2
  echo "$ME is copyright © Dan Jones" >&2
  echo Released under the terms of the New BSD License >&2
}

usage() {
  versioninfo
  echo
  echo Usage: $ME file1 [file2 [file3 ...]] >&2
  echo .oga, .ogg, .ogv, .ogx, and .spx are the >&2
  echo supported file extensions >&2
  echo 
  echo If no filenames are given, the list of filenames >&2
  echo is read from stdin, one per line. >&2
}

if [ $# -eq 0 ]; then
  usage
  exit 1
fi

for opt in $(getopt -n $ME -l version,help -o Vh? -- $@); do
  case $opt in
    --version|-V)
      versioninfo
      exit 0;;
    --help|-h|-\?)
      usage
      exit 0;;
    --) :;;
    -*)
      echo "E: $ME: invalid argument: $opt" >&2
      usage
      exit 1;;
    *) :;;
  esac
done

if ! command -v vorbiscomment >/dev/null; then
  echo "E: $ME: vorbiscomment not found in \$PATH." >&2
  exit -1
fi
if ! command -v id3v2 >/dev/null; then
  echo "E: $ME: id3v2 not found in \$PATH." >&2
  exit -1
fi

old_IFS="$IFS"
IFS="
"
[ $# -eq 0 ] && set -- $(cat)
IFS="$old_IFS"

if [ $# -eq 0 ]; then
  exit 0
fi

TMPFILE=$(mktemp /tmp/tagedit.XXXXXX)
trap "rm -f $TMPFILE" 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15

cat <<_eof > $TMPFILE
# tagedit (\$Id$)
#
# Edit the lines in this file to your desire, but
# DO NOT touch lines starting with a colon (:)!
# You may use lines starting with a plus (+) to rename files.
#
# ID3 tags are appended to the current tags, rather than 
# replacing all tags, as with vorbis comments.
# Therefore, to remove an ID3 tag, simply set it to an 
# empty value.
#
# ID3 comments (COMM) should be formatted as 
# <Description>:<Comment>:<lng>, where lng is a three-letter
# language code, e.g., eng. <Comment> should not have any colons
# (:) in it, due to a limitation of id3v2.
#
# We are in directory:
#  $(pwd)
#
# Tags that should be applied to all files can be specified
# before the first per-file tag definiton starts.
# Be aware that using global tags when mixing id3 tags and 
# vorbis comments can have unexpected results.

_eof

for i in "$@"; do
  case "$i" in
    *.ogg|*.oga|*.ogv|*.ogx|*.spx|*.mp3)
      if [ ! -r "$i" ]; then
        echo "E: $ME: unreadable file: $i" >&2
        exit 2
      fi

      if [ ! -w "$i" ]; then
        echo "E: $ME: unwriteable file: $i" >&2
        exit 3
      fi

      echo ": $i"
      echo "+ $i"
      if [ "${i##*.}" = "mp3" ];then
	  id3v2 -R "$i" | sed -nr -e 's/^(COMM): \((.*)\)\[(.*)\]: (.*)/\1=\2:\4:\3/p' -e 's/^([A-Z0-9]{3,4}): (.+)/\1=\2/p' | egrep -v '^(PRIV|APIC)'
      else
	  vorbiscomment -l "$i"
      fi
      echo
      ;;

    *)
      echo "E: $ME: invalid argument: $i" >&2
      exit 1
      ;;
  esac
done >> $TMPFILE
echo : EOF >> $TMPFILE

MD5SUM=$(md5sum $TMPFILE)

[ -n "${DISPLAY:-}" ] && [ -n "${VISUAL:-}" ] && EDITOR="$VISUAL"
if [ -z "${EDITOR:-}" ]; then
  for i in sensible-editor editor vim emacs nano vi; do
    P="$(command -v $i)"
    [ -x "$P" ] && EDITOR="$P" && break
  done
fi

if [ -z "${EDITOR}" ]; then
  echo "E: $ME: no editor found." >&2
  exit 4
fi

eval $EDITOR $TMPFILE

if echo "$MD5SUM" | md5sum -c >/dev/null 2>&1; then
  echo "I: $ME: no changes, exiting..." >&2
  exit 0
fi

tags=''

echo "I: processing files..." >&2

write_tags() {
  echo -n "I:   processing $file... " >&2
  local file="$1"; shift
  if [ "${file##*.}" = "mp3" ]; then
      while [ $# -gt 0 ]; do
      echo "$1" | while read tag; do
	  [ -z "$tag" ] && continue
	  id3v2 --"${tag%%=*}" "${tag#*=}" "$file"
      done
      shift
      done
  else
      for tag; do [ -n "${tag:-}" ] && echo "$tag"; done | \
	  vorbiscomment -w "$file"
  fi
  if [ -n "${filename_new:-}" ] && [ "${filename_new:-}" != "$file" ]; then
    echo; echo -n "I:     renaming to $filename_new... " >&2
    mv "$file" "$filename_new"
    unset filename_new
  fi
}

filename_new=
global_tags=

while read line; do
  case "$line" in
    ': EOF')
      write_tags "$file" "$global_tags" "$tags"
      echo "done." >&2
      ;;

    :*)
      if [ -n "${file:-}" ]; then
        write_tags "$file" "$global_tags" "$tags"
        echo "done." >&2
        tags=''
      fi
      file="${line#: }"
      ;;

    +*)
      filename_new="${line#* }";;

    *=*)
      if [ -z "${file:-}" ]; then  # global scope
        global_tags="${global_tags:+$global_tags
}$line"
      else                         # file scope
        tags="${tags:+$tags
}$line"
      fi
      ;;

    *|'#*') :;;
  esac
done < $TMPFILE

echo "I: done." >&2

rm -f $TMPFILE
trap - 0

exit 0
