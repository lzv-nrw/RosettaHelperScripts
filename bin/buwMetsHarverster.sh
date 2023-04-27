#!/bin/bash

# a simple script to download content of OA-Repositories into the deposit_storage if direct 
# access via OAI Harvest Job is not successful due to limitations of Rosetta Harvesting facilities

mode="prod"
if [ "$mode" = "devel" ]; then
   cp -r ./resources/* ./target/
   echo "Entwicklungsmodus eingeschaltet. Für Produktion bitte Variable mode ändern"
fi

## Definiere den Pfad, in dem die zuvor mit dem OAI-Harvester-Job geholten ie.xml liegen.
ingestPath="./${1:-target}"

echo "Schritt 1: Lösche alte Hilfsdateien"
find "$ingestPath" -name flocation.txt -type f -execdir rm {} \;
find "$ingestPath" -name urls.txt -type f -execdir rm {} \;
find "$ingestPath" -name streams -type d -execdir rm -rf {} \;

echo "Schritt 2: Erzeuge aktuelle Hilfsdateien"
## Die folgende Schleife sucht alle ie.xml-Dateien in Unterverzeichnissen 
# -printf "%h\t" kopiert den reinen Pfad und einen Tabulator - ohne Dateinamen in die Variable pname
# -printf "%p\n" kopiert den Dateinamen und einen Umbruch in die Variable fname 

find "$ingestPath" -name "ie*.xml" -printf "%h\t" -printf "%p\n" | while read -r pname fname; do
     # Suche jeden <mets:Flocat-Eintrag in der Datei ie.xml und kopiere ihn in die Hilfsdatei flocation.txt im jeweiligen Unterverzeichnis
     
     grep '<mets:FLocat' "$fname" >> "$pname"/flocation.txt
     
     ## Schreibe das Ergebnis in die Datei urls.txt. Beispiel:
     # <mets:Flocat LOCTYPE="URL" xlin:href="https://example.org" /> wird zu https://example.org in URLs.txt
     
     cut -d'"' -f2 < "$pname"/flocation.txt >> "$pname"/urls.txt

     #sed -e 's/<mets:FLocat LOCTYPE=\"URL\" xlin:href=\"\|\"\/>\|amp\;//g' "$pname"/flocation.txt >> "$pname"/urls.txt
done

echo "Schritt 3: Harveste URLs aus Repository"

currentdir=$(pwd)
#echo "$currentdir"

# Erstelle Backup-Ordner für ie.xml

mkdir "ie_backup"
cp ./content/ie*.xml ./ie_backup

# Einloggen und speichern von cookie
# Hier Logindaten eingeben loginUser und loginPassword
echo "Login"
curl = -d "loginUser=&loginPassword=" -c cookie.txt "https://elekpub.bib.uni-wuppertal.de/oai/login/" -s -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Safari/537.36;"

# Finde alle urls.txt in den Unterverzeichnissen, erzeuge die streams-Verzeichnisse für Rosetta und Harveste die vorher extrahierten URLs einzeln ab.
find "$ingestPath" -name "urls.txt" -printf "%h\t" -printf "%p\n" | while read -r pname urlfile; do
    mkdir "$pname/streams"
    while read -r url; do
        cd "$pname"/streams || exit

        # Sammle Datei mit curl ein und kopiere sie in das richtige Unterverzeichnis
        # -k ermöglicht das Harvesten von falsch konfigurierten https-Verbindungen (Sicherheitsrisiko!)
        # -O schneidet den URL-Pfad vom Dateinamen ab: aus https://example.org/data wird data
        # --remote-header-name ersetzt den Dateinamen durch den originalen im "Content-Disposition"-Header 
        # mitgelieferten Namen: als zB. Anlage1.pdf statt data

		
        dfname=$(curl -b ../../cookie.txt -k "$url" -O --remote-header-name -s -w '%{filename_effective}')
		# Füge fehlenden Dateisuffix an die xml-Dateien hinzu
		if [[ $url == *"/download/fulltext/raw/"* ]]; then
			extension=".xml"
			dfname=$dfname$extension 
			fname=${dfname%.*}
			mv $fname $dfname
		fi
		echo "dfname: $dfname"
        regex="s#$url#/ingest_storage/buw_upload/ubwretro/content/streams/$dfname#g"
        # echo "Hier der Regex: $regex"

        # Schreibe neue Flocation in die Datei ie.xml.sed. Diese muss vermutlich dann noch nach ie.xml kopiert werden
        find ../ -name "ie*.xml" -execdir sed --in-place=.sed -e "$regex" {} \;
        cd "$currentdir" || exit
    done < "$urlfile"
done

# Lösche Hilfsdateien und cookie
rm ./content/flocation.txt
rm ./content/urls.txt
rm ./content/ie.xml.sed
rm cookie.txt 

echo "Script abgeschlossen"
