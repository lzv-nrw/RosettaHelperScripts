#!/bin/sh

# a simple script to download content of OA-Repositories into the deposit_storage if direct 
# access via OAI Harvest Job is not successful due to limitations of Rosetta Harvesting facilities

mode="devel"
if [ "$mode" == "devel" ] 
   then
   cp -r ./resources/* ./target/;
   echo "Entwicklungsmodus eingeschaltet. Für Produktion bitte Variable mode ändern";
fi;

## Definiere den Pfad, in dem die zuvor mit dem OAI-Harvester-Job geholten ie.xml liegen.
ingestPath="./target";

echo "Schritt 1: Lösche alte Hilfsdateien";
find $ingestPath -name flocation.txt -type f -execdir rm {} \;
find $ingestPath -name urls.txt -type f -execdir rm {} \;
find $ingestPath -name streams -type d -execdir rm -rf {} \;

echo "Schritt 2: Erzeuge aktuelle Hilfsdateien";

## Die folgende Schleife sucht alle ie.xml-Dateien in Unterverzeichnissen 
# -printf "%h\t" kopiert den reinen Pfad und einen Tabulator - ohne Dateinamen in die Variable pname
# -printf "%p\n" kopiert den Dateinamen und einen Umbruch in die Variable fname 

find $ingestPath -name "ie*.xml" -printf "%h\t" -printf "%p\n" | while read -r pname fname; 
do 
     ## Suche jeden <mets:Flocat-Eintrag in der Datei ie.xml und kopiere ihn in die 
     #Hilfsdatei flocation.txt im jeweiligen Unterverzeichnis 
     
     grep '<mets:FLocat' $fname >> $pname/flocation.txt ;
     
     ## Schreibe das Ergebnis in die Datei urls.txt. Beispiel:
     # <mets:Flocat LOCTYPE="URL" xlin:href="https://example.org" /> wird zu https://example.org in URLs.txt
     
     sed -e 's/<mets:FLocat LOCTYPE=\"URL\" xlin:href=\"\|\"\/>\|amp\;//g' $pname/flocation.txt >> $pname/urls.txt;
done;

echo "Schritt 3: Harveste URLs aus Repository"; 

currentdir=`pwd`;
echo $currentdir;

## Finde alle urls.txt in den Unterverzeichnissen, erzeuge die streams-Verzeichnisse für Rosetta
# und Harveste die vorher extrahierten URLs einzeln ab.
# Nutze cUrl dafür

find $ingestPath -name "urls.txt" -printf "%h\t" -printf "%p\n" | while read -r pname urlfile;
do
    mkdir "$pname/streams"
    for url in `cat $urlfile`;
    do
        cd "$pname/streams"
        
        # Sammle Datei mit curl ein und kopiere sie in das richtige Unterverzeichnis
        # -k ermöglicht das Harvesten von falsch konfigurierten https-Verbindungen (Sicherheitsrisiko!)
        # -O schneidet den URL-Pfad vom Dateinamen ab: aus https://example.org/data wird data
        # --remote-header-name ersetzt den Dateinamen durch den originalen im "Content-Disposition"-Header 
	# mitgelieferten Namen: als zB. Anlage1.pdf statt data
	
	dfname=`curl -k $url -O --remote-header-name -s -w '%{filename_effective}'`;
	aurl=`echo "$url" | sed -e 's/alff\&CI/alff\&amp\;CI/g' -e 's/\;/\\\;/g'`;

	regex=`echo "s#"$aurl"#"$dfname"#g"`;
	echo "Hier der Regex: $regex";
	
	## Schreibe neue Flocation in die Datei ie.xml.sed. Diese muss vermutlich dann noch nach ie.xml kopiert werden
	find ../ -name "ie*.xml" -execdir sed --in-place=.sed -e $regex {} \;
	cd "$currentdir";
    done;
done;

#rm ~/dc_source.txt; rm ~/urls.txt;
#cd ~/;

echo "Script abgeschlossen";
