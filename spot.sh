#!/bin/bash

COMMANDS=('auth', 'now', 'add', 'pls')

URL_GET_CURRENTLY_PLAYING="https://api.spotify.com/v1/me/player/currently-playing"
URL_GET_PLAYLISTS="https://api.spotify.com/v1/me/playlists"
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
set -a # automatically export all variables
source $SCRIPT_DIR/.env
source $SCRIPT_DIR/.colours
set +a

# if [[ "$#" != 1 ]]; then
#     echo "Please provide one of the following commands: ${COMMANDS[@]}"
#     exit
# fi

export_env_var() {
    if ! grep -q "$1=" $SCRIPT_DIR/.env; then
        echo "export $1=" >> $SCRIPT_DIR/.env
    fi
    sed -i -r "s/$1=.*/$1=${!1}/g" $SCRIPT_DIR/.env
}

function get_currently_playing {
    curl -sS -X "GET" $URL_GET_CURRENTLY_PLAYING -H "Accept: application/json" -H "Content-Type: application/json" -H "Authorization: Bearer $ACCESS_TOKEN" > ~/.spotify/trackdata.json
    ERROR_MESSAGE=$(jq .error.message ~/.spotify/trackdata.json | tr -d '"')
    if [ "$ERROR_MESSAGE" != "null" ]
    then
        echo -e "${Red}${ERROR_MESSAGE}${Color_off}"
        exit
    else
        TRACK_NAME=$(jq .item.name ~/.spotify/trackdata.json | tr -d '"')
        TRACK_ID=$(jq .item.id ~/.spotify/trackdata.json | tr -d '"')
        TRACK_URI=$(jq .item.uri ~/.spotify/trackdata.json | tr -d '"')
        TRACK_ARTIST=$(jq .item.artists[0].name ~/.spotify/trackdata.json | tr -d '"')
        TRACK_ALBUM=$(jq .item.album.name ~/.spotify/trackdata.json | tr -d '"')
    fi
}

function get_playlists {
    curl -sS -X "GET" $URL_GET_PLAYLISTS -H "Accept: application/json" -H "Content-Type: application/json" -H "Authorization: Bearer $ACCESS_TOKEN" > ~/.spotify/playlistdata.json
    ERROR_MESSAGE=$(jq .error.message ~/.spotify/playlistdata.json | tr -d '"')
    
    if [ "$ERROR_MESSAGE" != "null" ]
    then
        echo -e "${Red}${ERROR_MESSAGE}${Color_off}"
        exit
    else
        PLAYLISTS=$(jq .items ~/.spotify/playlistdata.json | tr -d '"')
    fi
}

function print_playlists {
    get_playlists
    echo -e "${Cyan}PLAYLISTS${Color_Off}"
    jq -c '.items[]' ~/.spotify/playlistdata.json | while read playlist; do
        echo -e ${Yellow}$(jq -r '.name' <<< "$playlist")${Color_Off}
    done
}

function add_song_to_playlist {
    curl -sS -X "POST" "https://api.spotify.com/v1/playlists/$1/tracks?uris=$2" -H "Accept: application/json" -H "Content-Type: application/json" -H "Authorization: Bearer $ACCESS_TOKEN"
    echo -e "\\n ${Green}Added ${Yellow}$TRACK_NAME ${Green}to ${Yellow}$PLAYLIST_NAME ${Color_Off}"
}

function check_track_in_playlist {
    curl -sS -X "GET" "https://api.spotify.com/v1/playlists/$1/tracks" -H "Accept: application/json" -H "Content-Type: application/json" -H "Authorization: Bearer $ACCESS_TOKEN" > ~/.spotify/playlisttracks.json
    ERROR_MESSAGE=$(jq .error.message ~/.spotify/playlisttracks.json | tr -d '"')

    if [ "$ERROR_MESSAGE" != "null" ]
    then
        echo -e "${Red}${ERROR_MESSAGE}${Color_off}"
        exit
    else
        while read playlist_track_id; do
            PL_TRACK_URI=$(jq -r '.track.uri' <<< "$playlist_track_id")
            if [ "$PL_TRACK_URI" == "$2" ]; then
                echo -e "${Yellow}${TRACK_NAME}${Color_off} already exists in playlist ${Yellow}${PLAYLIST_NAME}${Color_Off}. Exiting..."
                exit
            fi
        done <<<$(jq -c '.items[]' ~/.spotify/playlisttracks.json)
    fi
}

# Print info for currently playing song
if [[ "$1" == 'now' ]]; then
    get_currently_playing

    echo -e "
${Cyan}NOW PLAYING${Color_Off}
title:  ${Yellow}$TRACK_NAME${Color_Off}
artist: ${Yellow}$TRACK_ARTIST${Color_Off}
album:  ${Yellow}$TRACK_ALBUM${Color_Off}
id:     ${Yellow}$TRACK_ID${Color_Off}
"
fi

# Print out list of playlists
if [[ "$1" == "pls" ]]; then
    print_playlists
fi

# Add currently playing song to a playlist
if [[ "$1" == 'add' ]]; then

    if [[ "$#" != 2 ]]; then
        echo "Please provide a playlist to add to."
        exit
    fi

    get_currently_playing
    echo -e "attempting to add song ${Yellow}${TRACK_NAME}${Color_Off} to playlist ${Yellow}${2}${Color_Off}"

    get_playlists

    while read playlist; do
        PLAYLIST_NAME=$(jq -r '.name' <<< "$playlist")
        
        if [ "$PLAYLIST_NAME" == "$2" ]; then
            echo -e "${Green}found playlist ${2}${Color_Off}"
            PLAYLIST_ID=$(jq -r '.id' <<< "$playlist")
            check_track_in_playlist $PLAYLIST_ID $TRACK_URI
            add_song_to_playlist $PLAYLIST_ID $TRACK_URI
            break
        fi
    done <<<$(jq -c '.items[]' ~/.spotify/playlistdata.json)

    if [ "$PLAYLIST_NAME" != "$2" ]; then
        echo -e "${Red}could not find playlist ${2}${Color_Off}"
    fi
fi

# WIP authentication
if [[ "$1" == 'auth' ]]; then
    # RESPONSE=$(curl -sS -i "https://accounts.spotify.com/authorize?client_id={$CLIENT_ID}&response_type=token&redirect_uri={$REDIRECT_URI}&scope={$SCOPES}")
    # HEADERS=$(sed -n '1,/^\r$/p' <<<"$RESPONSE")
    # LOCATION=$(grep -oP "location: \K.*" <<< "$HEADERS")
    # TOKEN_RESPONSE=$(curl -sS -i -L ${LOCATION//[$'\t\r\n ']})
    # echo $TOKEN_RESPONSE

    # RESPONSE=$(curl -H "Authorization Basic {$AUTHORIZATION_HEADER}" -H "Content-Type application/x-www-form-urlencoded" "https://accounts.spotify.com/api/token?refresh_token={$REFRESH_TOKEN}&redirect_uri={$REDIRECT_URI}&grant_type=refresh_token&client_id={$CLIENT_ID}&code_verifier={$CODE_VERIFIER}")
    # echo $RESPONSE
    
    RESPONSE=$(curl -sS -X POST "https://accounts.spotify.com/api/token" -H "Content-Type: application/x-www-form-urlencoded" -d "grant_type=client_credentials&client_id=${SPOT_CLIENT_ID}&client_secret=${SPOT_CLIENT_SECRET}")
    AUTH_TOKEN=$(jq -r '.access_token' <<< "$RESPONSE")
    echo $AUTH_TOKEN
    export AUTH_TOKEN=$AUTH_TOKEN
    export_env_var "AUTH_TOKEN"
fi

