#!/bin/bash

# a simple script to download content of OA-Repositories into the deposit_storage if direct 
# access via OAI Harvest Job is not successful due to limitations of Rosetta Harvesting facilities

mode="prod"
if [ "$mode" = "devel" ]; then
   cp -r ./resources/* ./target/
   echo "Entwicklungsmodus eingeschaltet. Für Produktion bitte Variable mode ändern"
fi

echo -e "Start: $(date) \n"

## Definiere den Pfad, in dem die zuvor mit dem OAI-Harvester-Job geholten ie.xml liegen.
ingestPath="./${1:-target}"

echo "Schritt 1: Lösche alte Hilfsdateien"
find "$ingestPath" -name flocation.*.txt -type f -execdir rm {} \;
find "$ingestPath" -name urls.*.txt -type f -execdir rm {} \;
find "$ingestPath" -name streams.* -type d -execdir rm -rf {} \;

# Filtere und sortiere mehrteilige Monografien
echo "Schritt 2: Filtere und sortiere mehrteilige Monografien"

# Suche alle Überordnungen - Diese besitzen "HAS_PART"
# -printf "%h\t" kopiert den reinen Pfad und einen Tabulator - ohne Dateinamen in die Variable pname
# -printf "%p\n" kopiert den Pfad + Dateinamen und einen Umbruch in die Variable fname 
multivolumeNum=0
find "$ingestPath" -name "ie*.xml" -exec grep -q '<key id="relationshipSubType">HAS_PART</key>' {} \; -printf "%h\t" -printf "%p\n" | while read -r pname fname; do
	
	dirCounter=$((++multivolumeNum))
	echo "dirCounter $dirCounter"
	echo "fname $fname"

	dname="multivolume_$dirCounter/content"
	echo "dname $dname"
	
	# Erstelle Ordner für mehrteilige Monograpien
	mkdir -p "$dname"
	# Verschiebe Überordnung in der erstellten Ordner
	cp -p -u $fname ./$dname/"parent.xml"
	rm $fname
	
	# Ermittle Anzahl der Unterordnungen
	searchBook='TYPE="book">'
	bookNum="$(grep $searchBook ./$dname/parent.xml | wc -l)"
	echo "bookNum $bookNum"
	
	# Schleife für die Unterordnungen
	for i in $(seq 1 $bookNum)
	do
		echo "Unterordnung: $i"
		
		# Finde ID von der i-ten Unterordnung in der StructMap 
		bookID="$(grep -m$i $searchBook ./$dname/parent.xml)"
		bookID="$(echo $bookID | sed -e 's/.*DMDID="md\(.*\)" ID.*/\1/')" 
		
		echo "bookID: $bookID"
		
		# Suche nach der Unterordung mit der ID: oai:elekpub.bib.uni-wuppertal.de:'$bookID
		find "$ingestPath" -name "ie*.xml" -exec grep -q 'oai:elekpub.bib.uni-wuppertal.de:'$bookID {} \; -printf "%h\t" -printf "%p\n" | while read -r pname2 fname2; do
			
			echo "fname2 $fname2"
			# Verschiebe in den zugehörigen Ordner
			cp -p -u $fname2 ./$dname/"child_"$i".xml"
			rm $fname2			
		done			
	done
	echo -e "\n"	
done

echo "Schritt 3: Erzeuge aktuelle Hilfsdateien"
# Die folgende Schleife sucht alle ie.xml-Dateien in Unterverzeichnissen 
# -printf "%h\t" kopiert den reinen Pfad und einen Tabulator - ohne Dateinamen in die Variable pname
# -printf "%p\n" kopiert den Dateinamen und einen Umbruch in die Variable fname 

find "$ingestPath" \( -type f -name "ie*.xml" -o -name "child_*" \) -exec grep -q "<mets:FLocat.*https" {} \; -printf "%h\t" -printf "%p\n" | while read -r pname fname; do
   
	#Parameter je ie*.xml bzw. child_*.xml
	if [[ $fname =~  .*"ie".*".xml" ]]; then
		count=$(echo $fname | grep -o -P '(?<=/ie).*(?=.xml)' )
	else [[ $fname =~  .*"child".*".xml" ]];
		count=$(echo $fname | grep -o -P '(?<=child_).*(?=.xml)' )
	fi
	echo "$count"
	echo "$pname"
	echo "$fname"
	# Suche jeden <mets:Flocat-Eintrag in der Datei ie*.xml bzw. child_*xml und kopiere ihn in die Hilfsdatei flocation.txt im jeweiligen Unterverzeichnis
	grep "<mets:FLocat.*https" "$fname" >> "$pname"/flocation"$count".txt
	
	## Schreibe das Ergebnis in die Datei urls.txt. Beispiel:
	# <mets:Flocat LOCTYPE="URL" xlin:href="https://example.org" /> wird zu https://example.org in URLs.txt
	cut -d'"' -f4 < "$pname"/flocation"$count".txt >> "$pname"/urls"$count".txt

	#sed -e 's/<mets:FLocat LOCTYPE=\"URL\" xlin:href=\"\|\"\/>\|amp\;//g' "$pname"/flocation.txt >> "$pname"/urls.txt
done

echo "Schritt 4: Harveste URLs aus Repository"

currentdir=$(pwd)
#echo "$currentdir"

# Finde alle urls.txt in den Unterverzeichnissen, erzeuge die streams-Verzeichnisse für Rosetta und Harveste die vorher extrahierten URLs einzeln ab.
find "$ingestPath" -name "urls*.txt" -printf "%h\t" -printf "%p\n" | while read -r pname urlfile; do
	
	parentPath=$(dirname "$pname")
	folderName=$(basename "$parentPath")
	count=$(echo $urlfile | grep -o -P '(?<=urls).*(?=.txt)' )
	streamssubfolder="streams$count"
	
	# Einloggen in VL und speichern von cookie.txt
	loginURL="https://elekpub.bib.uni-wuppertal.de/oai/login/"
	
	randomNum1="$(( $RANDOM % 537 + 1 ))"
	randomNum2="$(( $RANDOM % 108 + 50 ))"
	randomNum3="$(( $RANDOM % 605 + 100 ))"

	user_agent_list=(
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/$randomNum1.36 (KHTML, like Gecko) Chrome/109.0.0.0 Safari/$randomNum1.36"
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/$randomNum2.0.0.0 Safari/537.36"
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 13_1) AppleWebKit/$randomNum3.1.15 (KHTML, like Gecko) Version/16.1 Safari/$randomNum3.1.15"
	)
	
	echo "Login in VL"
	index=$(( $count % 3 ))
	user_agent="${user_agent_list[index]}"
	echo "user_agent: $user_agent"
	# Hier Logindaten eingeben loginUser und loginPassword
	curl = -d "loginUser=&loginPassword=" -c cookie.txt -s -A "$user_agent" "$loginURL"
	cookieDir=$(pwd)
	echo "cookieDir: $cookieDir"
	cookie=$cookieDir"/cookie.txt"
	echo -e "\n"
	
    mkdir -p "$pname/streams"
	mkdir -p "$pname/streams/$streamssubfolder"
    while read -r url; do
        cd "$pname"/streams/"$streamssubfolder" || exit
        # Sammle Datei mit curl ein und kopiere sie in das richtige Unterverzeichnis
		# -b holt sich den zuvor gespeicherten Cookie
        # -k ermöglicht das Harvesten von falsch konfigurierten https-Verbindungen (Sicherheitsrisiko!)
        # -O schneidet den URL-Pfad vom Dateinamen ab: aus https://example.org/data wird data
        # --remote-header-name ersetzt den Dateinamen durch den originalen im "Content-Disposition"-Header 
        # mitgelieferten Namen: als zB. Anlage1.pdf statt data
		echo "Hier: $(pwd)"
		echo "Url: $url"
		dfname=$(curl -b "$cookie" -k "$url" -O --remote-header-name -s -w '%{filename_effective}')
		originalName=$dfname

		dfname=${url##*/}
		echo "OriginalName: $originalName"
		
		# Füge fehlenden Dateisuffix an die Dateien hinzu
		if [[ $url == *"/download/fulltext/raw/"* ]]; then
			extension=".xml"
			dfname=$originalName$extension 
			fname=${dfname%.*}
			originalName=$originalName$extension
			mv $fname $dfname
		fi
		
		if [[ $url == *"/download/pdf/"* ]]; then
			extension=".pdf"
			dfname=$dfname$extension
			mv "$originalName" "$dfname" 
		fi
		
		if [[ $url == *"/download/archive/"* ]]; then
			extension=".tif"
			dfname=$dfname$extension
			mv "$originalName" "$dfname"
		fi

		echo "Filename: $dfname"
						
		# Eventuelle Sonderzeichen umschreiben
		originalName="$(echo $originalName | sed -e 's/&/&amp;/g')"
		originalName="$(echo $originalName | sed -e 's/</&lt;/g')"
		originalName="$(echo $originalName | sed -e 's/>/&gt;/g')"
		
		#Ersetze Links in mets:FLocat durch die Pfadangaben der Dateien auf dem Server
		newPath="$streamssubfolder/$dfname"
		echo "New Path: $newPath"
        regex="s#xlink:href=\"$url#xlink:href=\"$newPath#g"
		
		#Ersetze Links in fileOriginalName durch originalName
		fileOriginalName="<key id=\"fileOriginalName\">"
		regex2="s#$fileOriginalName$url#$fileOriginalName${originalName//&/\\&}#g"
		
		echo -e "\n"
		
        # Schreibe neue Flocation in die Datei ie.xml.sed. Diese muss vermutlich dann noch nach ie.xml kopiert werden
        find ../../ -name "ie$count.xml" -execdir sed --in-place=.sed -e "$regex" {} \;
		find ../../ -name "child_$count.xml" -execdir sed --in-place=.sed -e "$regex" {} \;
		
		# Schreibe Dateinamen in die Datei ie.xml.sed. Diese muss vermutlich dann noch nach ie.xml kopiert werden
        find ../../ -name "ie$count.xml" -execdir sed --in-place=.sed -e "$regex2" {} \;
		find ../../ -name "child_$count.xml" -execdir sed --in-place=.sed -e "$regex2" {} \;
		
        cd "$currentdir" || exit
    done < "$urlfile"

	sleep 5m
done

# Lösche Hilfsdateien und leere Ordner
echo "Schritt 5: Lösche Hilfsdateien"
find "$ingestPath" -name flocation*.txt -type f -execdir rm {} \;
find "$ingestPath" -name urls*.txt -type f -execdir rm {} \;
find "$ingestPath" -name ie*.xml.sed -type f -execdir rm {} \;
find "$ingestPath" -name child_*.xml.sed -type f -execdir rm {} \;
find "$ingestPath" -name cookie.txt -type f -execdir rm {} \;
find "$ingestPath" -empty -type d -delete

echo "Script abgeschlossen: $(date)"
