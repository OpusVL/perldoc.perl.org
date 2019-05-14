# Perl Documentation Website

This repo contains all the scrips that are necessary to develop the documentation website locally and then just deploy with a simple copy/paste to the server.

## gen-perldoc.pm

A script to download perl versions, compile them and convert base perl pod files into html

Using the scripts

Running the script bellow will create the `builds` and `outputs` folders that contain each version of Perl released and its documentation.

```bash
perl gen-perldoc.pm
```

This script will run once per day so that if a new version is release this is downloaded, compiled and it's documentation released to the site automatically.

To force recompiling the whole thing (in case of templates being updated) you can run

```bash
perl gen-perldoc.pm force
```

## Developing locally and modifying the templates

### Template modifying

There are 2 major files that can modified to change the structural integrity of the static html files.

`***default.tt***` - template for the actual documentation pages

- navigation automatically generated
- links on the sidebar automatically generated
- content automatically generated
- footer automatically generated

`***main_index.tt***` main landing pages for each release

- navigation automatically generated
- landing page content links automatically generated
- footer automatically generated

Modifying the templates while developing will require rebuilding the actual html files

Using `perl gen-perldoc.pm force` will rewrite the html files so please use it with caution as it will recreate all the html files inside the Outputs folder

### Assets developing

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

this will watch all the souRce folders and recreate/ recompile files as needed

```bash
grunt
```

this command will run all tasks (sass, js, images) and compile the build into the outputs/public folder

local simple http server

```bash
python -m SimpleHTTPServer 8000
```

