#!/bin/bash

# A simple script that adapts the download links in the ie.xml files
# to be able to deliver OJS content to Rosetta. 

echo -e "Start: $(date) \n"

# Define the path in which the ie.xml files previously retrieved with the OAI-Harvester-Job are located.
ingestPath="$1"
echo -e "Ingest path: $ingestPath"

# The following loop searches for all ie.xml files in the subdirectories 
find $ingestPath -type f -printf "%p\t" -printf "%f\n" | sort | while read -r filepath filename; do
	
	echo -e "\nFilepath: $filepath"
	echo -e "Filename: $filename"

	# Search for the URLs and save them in an array 
	urlpaths=()
	readarray -t urlpaths < <(xmlstarlet sel -T -t -v "//mets:file/mets:FLocat/@xlink:href" -v @key -n <$filepath)
	
	# Check whether the URL leads to a viewer or not
	# If true, replace the URL.
	i=1	
	for url in "${urlpaths[@]}"; do
		echo -e "\nFound URL: $url"
		if (curl -s -f -L -k $url | grep -Eqo "https:\/\/.*\/download\/.*[0-9]") then     
			newURLPath=$(curl -s -L -k $url | grep -Eo "https:\/\/.*\/download\/.*[0-9]")
			echo "Change URL path to $newURLPath"
			regex="s#xlink:href=\"$url\"/>#xlink:href=\"$newURLPath\"/>#g"
			sed -i -e "$regex" $filepath
		else
			echo "Nothing to do"
		fi
		i=$((i+1))		
	done
done
echo -e "\nEnd: $(date)"
