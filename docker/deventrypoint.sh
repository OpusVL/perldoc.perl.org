#!/bin/bash

shopt -s expand_aliases

mkdir -p /root/perldoc.perl.org/work
cd /root/perldoc.perl.org/work
export GIT_DISCOVERY_ACROSS_FILESYSTEM=1
rm -Rf output-tmp
git clone git@github.com:OpusVL/perldoc.perl.org-export.git output-tmp
cp -fr output-tmp/. output/
rm -Rf output-tmp
rm -f /root/perldoc.perl.org/syntax.cache

while true
do
    cd /root/perldoc.perl.org
    git checkout local-dev
    perl sitegen.pl
    cd /root/perldoc.perl.org/work/output
    latest_perl=$(perl -MJSON -MData::Dumper -e 'local $/;open($fh,"<","versions.json");$j=decode_json(<$fh>);print join(".",5,$j->{latest}->{major},$j->{latest}->{minor})')
    ln -sf $latest_perl .default
    git add .
    git commit -am "AutoCommit"
    git push -f origin master
    echo "Sleeping for 24 hours before retrying";
    perl -e 'print "Sleeping 24 hours\n"; sleep(60*60*24)'
done
