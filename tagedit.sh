#!/bin/sh -eu

# vorbistagedit -- allows batch editing of vorbis comments with an editor
#
# Copyright © martin f. krafft <madduck@madduck.net>
# Released under the terms of the Artistic Licence 2.0
#

VERSION=0.6
ME=${0##*/}

versioninfo() {
  echo "vorbistagedit $VERSION" >&2
  echo "\$Id$" >&2
  echo "$ME is copyright © martin f. krafft" >&2
  echo Released under the terms of the Artistic Licence 2.0 >&2
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

old_IFS="$IFS"
IFS="
"
[ $# -eq 0 ] && set -- $(cat)
IFS="$old_IFS"

if [ $# -eq 0 ]; then
  exit 0
fi

TMPFILE=$(mktemp /tmp/vorbistagedit.XXXXXX)
trap "rm -f $TMPFILE" 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15

cat <<_eof > $TMPFILE
# vorbistagedit (\$Id$)
#
# Edit the lines in this file to your desire, but
# DO NOT touch lines starting with a colon (:)!
# You may use lines starting with a plus (+) to rename files.
#
# We are in directory:
#  $(pwd)
#
# Tags that should be applied to all files can be specified
# before the first per-file tag definiton starts.

_eof

for i in "$@"; do
  case "$i" in
    *.ogg|*.oga|*.ogv|*.ogx|*.spx)
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
      vorbiscomment -l "$i"
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
  for tag; do [ -n "${tag:-}" ] && echo "$tag"; done | \
    vorbiscomment -w "$file"
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
