# This repository is for bug tracking issues only

While developing [perldoc.perl.org](https://perldoc.perl.org/), it was more convenient to split the engine away from the exported static site.

These are the three repositories and how they interact:

## The engine (public repository\*)

[perldoc.perl.org-engine](https://github.com/OpusVL/perldoc.perl.org-engine) is the repository you need for the new docker/pretty version of this repository.

This repository is for code storage only.

## The output (public internet cloneable of the output)

[perldoc.perl.org-export](https://github.com/OpusVL/perldoc.perl.org-export) repository is simply the auto-created statically created version of the site and is not interactable (although you can clone it).

## The website

[perldoc.perl.org](https://github.com/OpusVL/perldoc.perl.org) is this repository and this is where you should interact with the project to submit issues or pull requests.

## Reasons for this repository being cleared and split

During the development of this project at times it was neccesary for large binary files and 200k+ sets of smaller files be created. Because of this, the '.git' is an enormous 400MiB and is incredible slow to work with. In fact, shells that automatically do fancy things with git (like zsh) will take seconds to even change directories.
