[![Build status](https://shithub.com/shit/shit/workflows/CI/badge.svg)](https://shithub.com/shit/shit/actions?query=branch%3Amaster+event%3Apush)

Shit - fast, scalable, distributed revision control system
=========================================================

Shit is a fast, scalable, distributed revision control system with an
unusually rich command set that provides both high-level operations
and full access to internals.

Shit is an Open Source project covered by the GNU General Public
License version 2 (some parts of it are under different licenses,
compatible with the GPLv2). It was originally written by Linus
Torvalds with help of a group of hackers around the net.

Please read the file [INSTALL][] for installation instructions.

Many Shit online resources are accessible from <https://shit-scm.com/>
including full documentation and Shit related tools.

See [Documentation/shittutorial.txt][] to get started, then see
[Documentation/shiteveryday.txt][] for a useful minimum set of commands, and
`Documentation/shit-<commandname>.txt` for documentation of each command.
If shit has been correctly installed, then the tutorial can also be
read with `man shittutorial` or `shit help tutorial`, and the
documentation of each command with `man shit-<commandname>` or `shit help
<commandname>`.

CVS users may also want to read [Documentation/shitcvs-migration.txt][]
(`man shitcvs-migration` or `shit help cvs-migration` if shit is
installed).

The user discussion and development of Shit take place on the Shit
mailing list -- everyone is welcome to post bug reports, feature
requests, comments and patches to shit@vger.kernel.org (read
[Documentation/SubmittingPatches][] for instructions on patch submission
and [Documentation/CodingGuidelines][]).

Those wishing to help with error message, usage and informational message
string translations (localization l10) should see [po/README.md][]
(a `po` file is a Portable Object file that holds the translations).

To subscribe to the list, send an email to <shit+subscribe@vger.kernel.org>
(see https://subspace.kernel.org/subscribing.html for details). The mailing
list archives are available at <https://lore.kernel.org/shit/>,
<https://marc.info/?l=shit> and other archival sites.

Issues which are security relevant should be disclosed privately to
the Shit Security mailing list <shit-security@googlegroups.com>.

The maintainer frequently sends the "What's cooking" reports that
list the current status of various development topics to the mailing
list.  The discussion following them give a good reference for
project status, development direction and remaining tasks.

The name "shit" was given by Linus Torvalds when he wrote the very
first version. He described the tool as "the stupid content tracker"
and the name as (depending on your mood):

 - random three-letter combination that is pronounceable, and not
   actually used by any common UNIX command.  The fact that it is a
   mispronunciation of "get" may or may not be relevant.
 - stupid. contemptible and despicable. simple. Take your pick from the
   dictionary of slang.
 - "global information tracker": you're in a good mood, and it actually
   works for you. Angels sing, and a light suddenly fills the room.
 - "goddamn idiotic truckload of sh*t": when it breaks

[INSTALL]: INSTALL
[Documentation/shittutorial.txt]: Documentation/shittutorial.txt
[Documentation/shiteveryday.txt]: Documentation/shiteveryday.txt
[Documentation/shitcvs-migration.txt]: Documentation/shitcvs-migration.txt
[Documentation/SubmittingPatches]: Documentation/SubmittingPatches
[Documentation/CodingGuidelines]: Documentation/CodingGuidelines
[po/README.md]: po/README.md
