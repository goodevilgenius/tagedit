tagedit
=======

This, program, based on the fantastic vorbistagedit, written by martin f. krafft
and included with the vorbis-tools package, allows a person to batch edit
metadata within ogg and mp3 files from the person's preferred text editor.

The basic usage is thus:

    tagedit <file.ogg> <file2.mp3> <file3.mp3> <file4.ogg> ...

A file containing all the current tags within each file is opened within the
user's $EDITOR. The tags can be edited directly within the file. When the file
is saved, and the $EDITOR is closed, the tags are written back to the file.

Any vorbis comments are written back to the ogg file completely, i.e., the
original vorbis comments are lost.

ID3 tags, on the other hand, are appended to the current metadata.

The actual tag writing requires vorbiscomment and id3v2 to be installed on the
user's system, and within the $PATH.

Plans
-----

I'd like to make the program modular, so that support for additional formats can
be more easily added. I plan to add that feature to the next version.

Bugs/Features
-------------

Please report any bugs, or request new features at the
[Issue Tracker](https://github.com/goodevilgenius/tagedit/issues) on the
project's [GitHub](https://github.com/goodevilgenius/tagedit) page.

