#!/bin/sh

# a simple script to download content of OA-Repositories into the deposit_storage if direct 
# access via OAI Harvest Job is not successful due to limitations of Rosetta Harvesting facilities

mode="devel"
if [ "$mode" == "devel" ] 
   then
   cp -r ./resources/* ./target/;
   echo "Entwicklungsmodus eingeschaltet. Für Produktion bitte Variable mode ändern";
fi;

ingestPath="./target";

echo "Schritt 1: Lösche alte Hilfsdateien";
find $ingestPath -name flocation.txt -type f -execdir rm {} \;
find $ingestPath -name urls.txt -type f -execdir rm {} \;
find $ingestPath -name streams -type d -execdir rm -rf {} \;

echo "Schritt 2: Erzeuge aktuelle Hilfsdateien";
find $ingestPath -name "ie*.xml" -printf "%h\t" -printf "%p\n" | while read -r pname fname; 
do 
     grep '<mets:FLocat' $fname >> $pname/flocation.txt ;
     sed -e 's/<mets:FLocat LOCTYPE=\"URL\" xlin:href=\"\|\"\/>\|amp\;//g' $pname/flocation.txt >> $pname/urls.txt;
done;

echo "Schritt 3: Harveste URLs aus Repository"; 
# Variante mit wget - macht zuviele Roundtrips
#find $ingestPath -name urls.txt -execdir wget --no-check-certificate --trust-server-names --content-disposition -nv -i {} \;

# Variante mit cUrl - etwas komplexerer Code nötig
currentdir=`pwd`;
echo $currentdir;
find $ingestPath -name "urls.txt" -printf "%h\t" -printf "%p\n" | while read -r pname urlfile;
do
    mkdir "$pname/streams"
    for url in `cat $urlfile`;
    do
        cd "$pname/streams"
        dfname=`curl -k $url -O --remote-header-name -s -w '%{filename_effective}'`;
	aurl=`echo "$url" | sed -e 's/alff\&CI/alff\&amp\;CI/g' -e 's/\;/\\\;/g'`;
	#echo "$aurl";
	regex=`echo "s#"$aurl"#"$dfname"#g"`;
	echo "Hier der Regex: $regex";
	#find ../ -name "ie*.xml" -execdir sed --in-place=.sed -e 's#$aurl#$dfname#g' {} \;
	find ../ -name "ie*.xml" -execdir sed --in-place=.sed -e $regex {} \;
	cd "$currentdir";
    done;
done;

#rm ~/dc_source.txt; rm ~/urls.txt;
#cd ~/;

echo "Script abgeschlossen";