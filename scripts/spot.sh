#!/bin/bash

COMMANDS=('auth', 'now', 'add', 'pls')

URL_GET_CURRENTLY_PLAYING="https://api.spotify.com/v1/me/player/currently-playing"
URL_GET_PLAYLISTS="https://api.spotify.com/v1/me/playlists"

set -a # automatically export all variables
source ~/.spotify/.env
source ~/.spotify/.colours
set +a

# if [[ "$#" != 1 ]]; then
#     echo "Please provide one of the following commands: ${COMMANDS[@]}"
#     exit
# fi

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

    RESPONSE=$(curl -H "Authorization Basic {$AUTHORIZATION_HEADER}" -H "Content-Type application/x-www-form-urlencoded" "https://accounts.spotify.com/api/token?refresh_token={$REFRESH_TOKEN}&redirect_uri={$REDIRECT_URI}&grant_type=refresh_token&client_id={$CLIENT_ID}&code_verifier={$CODE_VERIFIER}")
    
    echo $RESPONSE
fi
