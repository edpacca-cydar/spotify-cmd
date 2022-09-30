# Use Spotify API from the terminal

Requires manually setting up the access token for now.
Currently only works if script is set up in `~/.spotify` directory.
Create `.env` file in this root directory and create a variable named `ACCESS_TOKEN`.
Head to ["spotify for developers" console](https://developer.spotify.com/console), log in with your spotify account and get a token with the scopes you want to have access to.
Only scopes required by these scripts currently are:
    - `playlist-modify-private`
    - `playlist-modify-public`
    - `user-read-currently-playling`

For example [Add Items to Playlist](https://developer.spotify.com/console/post-playlist-tracks/) should give options to create a token with all of these scopes.
Head to the page and click "GET TOKEN" selecting the scopes above. Paste the value into your `.env` file as the value for `ACCESS_TOKEN`.
Alias the `spot.sh` script in `.bashrc` to `spot` or whatever you want.

## Commands

### spot now
Print out currently playing track information

### spot pls
Print out a list of your owned playlists

### spot add
takes playlist name as an argument. Adds currently playing song to that playlist if it exists
