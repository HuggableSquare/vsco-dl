vsco-dl
=======

dependency-less ruby script that downloads - [in other words, steals](https://nakedsecurity.sophos.com/2017/09/12/why-are-redditors-ripping-images-from-instagram-because-they-can/) - all the images on a vsco user's account (including metadata)

usage
-----
    Usage: vsco-dl.rb [options] username (or site id)
    -m, --[no-]metadata              Save metadata
    -o, --output=output              Where to save the files (default is cwd)
    -w, --[no-]overwrite             Overwrite previously downloaded files
    -c, --collection                 Download user's collection if available
    -s, --site-id                    Download user via site id instead of username

y tho
-----
¯\\_(ツ)_/¯

s/o to the [instagram archiving project on /r/DataHoarder](https://www.reddit.com/r/DataHoarder/comments/5m36zr/distributed_archivingsnapshots_of_instagram/), which is what inspired me to write this in the first place
