# This repository has been moved into a new location!

## The engine (public repository*)

perldoc.perl.org-engine is the repository you need for the new docker/pretty version of this repository

* currently private scheduled to be made public

## The output (public internet clonable of the output)

perldoc.perl.org-export is the repository you need for the 'site'

## Reasons for this repository being cleared and split

During the development of this project at times it was neccesary for large binary files and 200k+ sets of smaller files be created,
beacause of this the '.git' is an enourmous 400MiB and is incredible slow to work with, infact shells that automatically do fancy
things with git (like zsh) will take seconds to even change directories.

# OLD Readme information 

# Perldoc website builder

The Perldoc website is built from the Perl documentation created buy the developers. This repo contains all the scripts that are necessary to build the static HTML used by the perldoc.perl.org website.

## Generating Perldoc

The gen-perldoc.pm script is used to download Perl pod documentation, compile, index, and convert the content into html.

Running the script will create the `builds` and `outputs` folders that contain each version of Perl released and its documentation.

```bash
perl gen-perldoc.pm
```

It is scheduled to run run once per day to automatically update the site with changes to the documentation. 

To force a recompilation of the whole site (in case the templates have been updated) you can run:

```bash
perl gen-perldoc.pm force
```

> Using `perl gen-perldoc.pm force` will rewrite the html files so please use it with caution as it will recreate all the html files inside the Outputs folder

This may take some time...

## Modifying the site template

There are 2 major files that can modified to change the structure of the generated html files:

`***default.tt***` - template for the documentation content pages

- navigation automatically generated
- links on the sidebar automatically generated
- content automatically generated
- footer automatically generated

`***main_index.tt***` main landing pages for releases

- navigation automatically generated
- landing page content links automatically generated
- footer automatically generated

Once changed, the whole site will require a rebuild.

## Optimising JS assets

If you want to optimise the js libraries, there are a few popular options: 

### Grunt

Using Grunt to compile / optimize Sass, JS and Images

This will install the required dependencies that will allow you to update / optimize / improve and remove code from the website

```bash
npm install
```

There are a few tasks that have been created by default

- image - optimize and copy images from the root into the outputs folder
- sass - compile, optimize and export code into the outputs folder
- uglify - compile, optimize, transpile and export code into the outputs folder
  For development, open up a terminal and navigate to the current project

```bash
grunt watch
```

this will watch all the source folders and recreate/ recompile files as needed

```bash
grunt
```

this command will run all tasks (sass, js, images) and compile the build into the outputs/public folder


### Perl JS optimisation tools

[JS minify](https://metacpan.org/pod/JavaScript::Minifier)
[CSS minify](https://metacpan.org/pod/CSS::Minifier)


