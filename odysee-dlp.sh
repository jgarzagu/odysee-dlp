#!/bin/bash

# odysee-dlp
# A small script to download odysee and lbry videos using lbrynet commands.

# ==============================================================================
# NOTES
# ==============================================================================

# NOTE: This command deletes the lbry seed blobs when downloading the files (otherwise twice the storage)
# If you want to delete all lbry seed blobs do: $lbrynet.exe file delete --delete_all

# NOTE: Before starting the script you must start the lbry deamon with the main directory pat you will download the videos
# Example: $lbrynet.exe start --download-directory "D:\\PleiadianKnowledge2\\"
# Otherwise videos will download in the default folder (e.g., C://Users/name/Downloads)

# RUN Example for Lbry Desktop in Windows with Linux WSL:
#./odysee-dlp.sh -b "/mnt/c/Program Files/LBRY/resources/static/daemon/lbrynet.exe" -l links.txt -o "D:\\PleiadianKnowledge\\download\\" -f "/mnt/d/PleiadianKnowledge/download"              

# ==============================================================================
# USAGE VARIABLES
# ==============================================================================

# App
readonly script_name=$(basename "$0")
default_output_dir="/tmp/output"
app_version="1.0.0"

# Bins
lbrynet=

# Paths
odyseeLinks=
lbryDownloadDirectory=
folderDownloadDirectory=
alreadyDownload="download-archive.txt"
skipThumbnail=false

# ==============================================================================
# USAGE / HELP FUNCTION
# ==============================================================================
usage() {
    cat << EOF
Usage: $script_name -b <lbry binary> -l <links> -o <lbry_download_path> -f <system_download_path> [OPTIONS] 
_______________
odysee-dlp: A small script to download odysee and lbry videos using lbrynet commands.

Options:
  -b, --bin     [Required] Lbrynet binary path
  -l, --links    [Required] Lbry video links file (with claim id)
  -o, --lbryoutput  [Required] Lbrynet output path (Must match folder output path)
  -f, --foldeoutput   [Required] System output path (Musth match lbry output path)
  -d, --download-archive     [Optional] Download achieve name
  --skip-thumbnail     [Optional] Skips thumbnail download
  -v, --version  Display script version.
  -h, --help     Display this help message.

Example:
  ./$script_name -b "/mnt/c/Program Files/LBRY/resources/static/daemon/lbrynet.exe" -l links.txt -o "D:\\PleiadianKnowledge\\downloadfolder\\" -f "./downloadfolder/"  
EOF
    exit 1
}

# Loop through all provided command-line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -b|--bin)
            tmp_bin="$2"
            lbrynet="${tmp_bin// /\\ }"
            shift 2
            ;;
        -l|--links)
            odyseeLinks="$2"
            shift 2
            ;;
        -o|--lbryOutput)
            lbryDownloadDirectory="$2"
            shift 2
            ;;
        -f|--folderOutput)
            folderDownloadDirectory="$2"
            shift 2
            ;;
        -d|--download-archive)
            alreadyDownload="$2"
            shift 2
            ;;
        --skip-thumbnail)
            skipThumbnail=true
            shift 1
            ;;
        -v|--version)
            echo "$script_name version $app_version"
            exit 0
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Error: Invalid option '$1'"
            usage
            ;;
    esac
done

# ==============================================================================
# INPUT VALIDATION
# ==============================================================================
# Ensure both required variables (-u and -e) were provided by checking if empty
if [[ -z "$lbrynet" ]] || [[ -z "$odyseeLinks" ]] || [[ -z "$lbryDownloadDirectory" ]] || [[ -z "$folderDownloadDirectory" ]]; then
    echo "Error: Missing required arguments."
    usage
fi

# ==============================================================================
# SYSTEM VALIDATION
# ==============================================================================

echo "--------------------------------------------------"
echo "> Checking requirements"
echo "--------------------------------------------------"

if jq --version &> /dev/null; then
    echo "jq is installed"
else
    echo "Error: jq not installed, install as:"
    echo "sudo apt install jq"
    exit 1
fi

if eval $lbrynet -v &> /dev/null; then
    echo "lbrynet installed"
else
    echo "Error: lbrynet bin not found or not installed"
    echo "Download the app to install lbrynet (https://lbry.com/get)"
    exit 1
fi

if eval curl --version &> /dev/null; then
    echo "curl installed"
else
    echo "Error: curl not installed, install as:"
    echo "sudo apt install curl"
    exit 1
fi

echo "--------------------------------------------------"
echo "> Checking lbrynet daemon is running"
echo "--------------------------------------------------"

if lbrynet.exe status | grep "Could not connect to daemon"  &> /dev/null; then 
    echo "Error: lbrynet daemon is not running"
    echo "Run: lbrynet.exe start --download-dir '<Main Download path>'"
    exit 1
else
    echo "lbrynet daemon is running..."
fi

echo "--------------------------------------------------"
echo "> Printing lbrynet output directories"
echo "--------------------------------------------------"

lbrynet_videos_dir=$(lbrynet.exe settings get | jq -r '.download_dir')
lbrynet_blob_dir=$(lbrynet.exe settings get | jq -r '.data_dir')

echo "Lbrynet videos output directory: $lbrynet_videos_dir"
echo "Lbrynet blobs output directory: $lbrynet_blob_dir"

echo "--------------------------------------------------"
echo "> Processing request for user configuration..."
echo "--------------------------------------------------"
echo "Lbrynet binary: $lbrynet"
echo "Links file: $odyseeLinks" odyseeLinks
echo "Lbry download directory output: $lbryDownloadDirectory"
echo "System download directory output: $folderDownloadDirectory"
echo "Download archive: $alreadyDownload"
echo "Skip thumbnail: $skipThumbnail"
echo "--------------------------------------------------"

# ==============================================================================
# MAIN SCRIPT LOGIC
# ==============================================================================

# Loop through each line (Redirect to random file descriptor so while loop continues on commands that consume stdin)
echo ">> Downloading start..."
while IFS= read -r url <&8; do
    echo -e "\n #### PROCESSING URL ####"
    echo "Processing link: $url"
    claimId=$(echo $url | awk -F':' '{print $3}') # Get claim id
    if [ -z "$claimId" ]; then
        echo "Claim id NOT found in url: $url"
    else
        echo "Claim id found: $claimId"

        # Disable/Enable for extra safety (no double storage)
        #echo "Deleting lbry claim seed if any"
        #(set -x; $lbrynet file delete --claim_id=$claimId)

        ## Check if Download achieve file exists, if not create
        [ -f "$alreadyDownload" ] || touch "$alreadyDownload"
        ## Check if claim id has already download 
        if grep -Fxq "$claimId" $alreadyDownload; then
            echo "Already downloaded, doing nothing"
        else
            echo -e "\n #### RESOLVING METADATA ####"

            # Create download directory
            folderTmp="${folderDownloadDirectory%/}" 
            folder_path="$folderTmp/$claimId/"
            (set -x; mkdir -p "$folder_path")
            
            # Resolve url and save metadata 
            resolve_file_path=$folder_path"resolve.json"
            (set -x; eval $lbrynet resolve lbry://any#$claimId > $resolve_file_path)
            
            # Check that claimid is resolved in the lbry chain:
            if [ ! -f "$resolve_file_path" ]; then
                echo "Error: File $resolve_file_path was not resolved"
                exit 1
            else 
                echo "Metadata was successfully resolved in: $resolve_file_path "
            fi
                        
            # Extract json values
            title=$(jq -r '.[$k].value.title' --arg k "lbry://any#$claimId" $resolve_file_path)
            release_time=$(jq -r '.[$k].value.release_time' --arg k "lbry://any#$claimId" $resolve_file_path)
            canonical_url=$(jq -r '.[$k].canonical_url' --arg k "lbry://any#$claimId" $resolve_file_path)
            normalized_name=$(jq -r '.[$k].normalized_name' --arg k "lbry://any#$claimId" $resolve_file_path)
            video_name=$(jq -r '.[$k].value.source.name' --arg k "lbry://any#$claimId" $resolve_file_path)
            thumbnail=$(jq -r '.[$k].value.thumbnail' --arg k "lbry://any#$claimId" $resolve_file_path)
            description=$(jq -r '.[$k].value.description' --arg k "lbry://any#$claimId" $resolve_file_path)
            tags=$(jq -r '.[$k].value.tags' --arg k "lbry://any#$claimId" $resolve_file_path)

            # Alternative Extract json values
            #json_data=$(cat resolve.json | tr -d '\r')
            #{
            #    IFS= read -r title
            #    IFS= read -r canonical_url
            #} < <(jq -r '.[$k].value.title, .[$k].canonical_url' --arg k "lbry://any#$claimId" <<< "$json_data")

            # Uncomment for debugging 
            echo -e "\n"
            echo "title: $title"
            echo "release_time: $release_time"
            echo "canonical_url: $canonical_url"
            echo "normalized_name: $normalized_name"
            echo "video_name: $video_name"
            echo "thumbnail: $thumbnail"
            echo "description: $description"
            echo "tags: $tags"

            # Check important variables are set (not null)
            required_vars=(title release_time canonical_url normalized_name video_name thumbnail)
            for var in "${required_vars[@]}"; do
                if [[ -z "${!var}" ]]; then
                    echo "Error: Variable '$var' is empty or unset."
                    exit 1
                fi
            done
            echo "All variables set"

            echo -e "\n #### DOWNLOADING THUMBNAIL ####"

            if [[ "$skipThumbnail" == false ]]; then

                # Download thumbnail
                thumbnail_url=$( echo $thumbnail | jq -r '.url')
                thumbnail_file_name_webp=${video_name%.*}.webp
                thumbnail_file_path_webp=$folder_path$thumbnail_file_name_webp
                thumbnail_file_name_jpg=${video_name%.*}.jpg
                thumbnail_file_path_jpg=$folder_path$thumbnail_file_name_jpg
                if [[ ! -f "$thumbnail_file_path_webp" && ! -f "$thumbnail_file_path_jpg" ]]; then
                    echo "Downloading thumbnail:  $thumbnail_url"
                    filename=$(curl -O -J -w "%{filename_effective}" "$thumbnail_url" --output-dir "./$claimId")
                    case "$filename" in
                        *.webp)
                            (set -x; mv "$filename" "$thumbnail_file_path_webp")
                            ;;
                        *.jpg)
                            (set -x; mv "$filename" "$thumbnail_file_path_jpg")
                            ;;
                        *)
                            echo "Missing file extension of thumbnail, adding jpg: $filename"
                            (set -x; mv "$filename" "$folder_path${video_name%.*}.jpg")
                            sleep 15
                            ;;
                        *.*)
                            echo "Unknown file extension of thumbnail filename: $filename"
                            exit 1
                            ;;
                    esac
                else 
                    echo "Thumbnail ($thumbnail_url) already downloaded in: $folder_path${video_name%.*}(.webp or .jpg)"
                fi

                # Check that file is downloaded
                if [[ ! -f "$thumbnail_file_path_webp" && ! -f "$thumbnail_file_path_jpg" ]]; then
                    echo "Error: Thumbnail ($thumbnail_file_path) was not downloaded"
                    exit 1
                else
                    echo "Thumbnail was downloaded in: $folder_path${video_name%.*}(.webp or .jpg)"
                fi

            fi

            echo -e "\n #### DOWNLOADING VIDEO ####"

            ### Downlaod video 
            video_file_path=$folder_path$video_name
            if [ ! -f "$video_file_path" ]; then
                # Start video download
                echo "Downloading video: $video_name"
                lbryFolderOutput="${lbryDownloadDirectory//\\/\\\\}" # Eval removes \ so we add it again. 
                (set -x; eval $lbrynet get $canonical_url --download_directory="$lbryFolderOutput$claimId" --file_name="temp.mp4")
                # The download runs async, check the file every 5 seconds until its downloaded
                while true; do 
                    STATUS=$(eval $lbrynet file list --claim_id=$claimId | jq -r '.items.[0].completed')
                    TOTAL_BYTES=$(eval $lbrynet file list --claim_id=$claimId | jq -r '.items.[0].total_bytes')
                    WRITTEN_BYTES=$(eval $lbrynet file list --claim_id=$claimId | jq -r '.items.[0].written_bytes')
                    echo "Downloading video status: $STATUS (Total bytes: $WRITTEN_BYTES of $TOTAL_BYTES)"
                    if [ -z $STATUS ]; then
                        echo "Error: Command is null: $lbrynet file list --claim_id=$claimId | jq -r '.items.[0].completed'"
                        exit 1
                    fi
                    if [ "$STATUS" = "true" ]; then 
                        echo -e "Download finished! \n"
                        break
                    fi
                    echo "Still downloading... checking again in 2 seconds."
                    sleep 2
                done
                # Rename the file so it doesn't get deleted when removing the blob seed
                (set -x; mv $folder_path"temp.mp4" "$folder_path$video_name")
            else 
                echo "Video ($video_name) already downloaded in: $video_file_path"
            fi

            # Check if video was downloaded
            if [ ! -f "$video_file_path" ]; then
                echo "Error: Video ($video_file_path) was not downloaded"
                exit 1
            else 
                echo "Video was successfully downloaded in: $video_file_path"
            fi

            # Delete all seeds
            echo -e "\n #### MANAGING LBRY SEEDS ####"
            
            echo "Deleting lbry claim seed"
            (set -x; eval $lbrynet file delete --claim_id=$claimId)

            echo "Debating temp.m4 file if any"
            if [ -f $folder_path"temp.mp4" ]; then
                (set -x; rm $folder_path"temp.mp4")
            fi

            # Uncomment for debug
            #echo "List lbry seeds"
            #(set -x; $lbrynet file list --claim_id=$claimId)
            #echo "Sleeping for debug"
            #(set -x; sleep 10)
            
            echo -e "\n #### SAVING SIMPLIFIED METADATA ####"

            # Save simplified metadata
            metadata_file_path=$folder_path"metadata.json"
            jq -n \
                --arg type "lbry" \
                --arg title "$title" \
                --arg release_time "$release_time" \
                --arg url "$url" \
                --arg canonical_url "$canonical_url" \
                --arg normalized_name "$normalized_name" \
                --arg video_name "$video_name" \
                --arg canonical_url "$canonical_url" \
                --argjson thumbnail "$thumbnail" \
                --arg description "$description" \
                --argjson tags "$tags" \
                '{type: $type, title: $title, release_time: $release_time, url: $url,
                canonical_url: $canonical_url, normalized_name: $normalized_name,
                video_name: $video_name, thumbnail: $thumbnail, description: $description,
                tags: $tags}' > $metadata_file_path

            # Check if metadata was created
            if [ ! -f "$metadata_file_path" ]; then
                echo "Error: Simplified Metadata ($metadata_file_path) was not created"
                exit 1
            else 
                echo "Simplified metadata was successfully saved in: $metadata_file_path"
            fi

            echo -e "\n #### SUCCESSFUL DOWNLOAD, APPENDING IN DOWNLOAD ARCHIVE ####"

            (set -x; echo "$claimId" >> $alreadyDownload)

            echo "Claim id ($claimId) saved in downloads achieve file: $alreadyDownload"

            # Sleep 15 sec
            echo -e "\n ...waiting for the next url"
            (set -x; sleep 15)
        fi
    fi
done 8< "$odyseeLinks"

echo -e "\n-------------------------------------------------"
echo -e "Finish downloading all lbry url links...exiting"
exit 0