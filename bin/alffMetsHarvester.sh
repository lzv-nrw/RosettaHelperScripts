#!/bin/sh

# a simple script to download content of OA-Repositories into the deposit_storage if direct 
# access via OAI Harvest Job is not successful due to limitations of Rosetta Harvesting facilities

oaipath="/ingest_storage/usb/SIPs4Upload_after_oai_harvesting"
depositpath="/ingest_storage/source_file_streams/usb/"

echo "Schritt 1: Lösche alte Hilfsdateien";
find $oaipath -name flocation.txt -type f -execdir rm {} \;
find $oaipath -name urls.txt -type f -execdir rm {} \;

echo "Schritt 2: Erzeuge aktuelle Hilfsdateien";
find $oaipath -name "ie*.xml" -printf "%h\t" -printf "%p\n" | while read -r pname fname; 
do 
     grep '<mets:FLocat' $fname >> $pname/flocation.txt ;
     sed -e 's/<mets:FLocat LOCTYPE=\"URL\" xlin:href=\"\|\"\/>\|amp\;//g' $pname/flocation.txt >> $pname/urls.txt;
done;

echo "Schritt 3: Harveste URLs aus Repository"; 
# Variante mit wget - macht zuviele Roundtrips
#find $oaipath -name urls.txt -execdir wget --no-check-certificate --trust-server-names --content-disposition -nv -i {} \;

# Variante mit cUrl - etwas komplexerer Code nötig
currentdir = `pwd`;
find $oaipath -name "urls.txt" -printf "%h\t" -printf "%p\n" | while read -r pname urlfile;
do
    mkdir "$pname/streams"
    cd "$pname/streams"
    for url in `cat $urlfile`;
    do
        curl -k $url -O --remote-header-name;
    done;
done;
cd $currentdir;

#rm ~/dc_source.txt; rm ~/urls.txt;
#cd ~/;

echo "Script abgeschlossen";

