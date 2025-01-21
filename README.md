# iPhone photo backup script

This is a simple script that utilize rsync to backup your photos from iPhone to your local disk, and organize them into YYYY-MM folders. What's more, it remembers where you finish and will skip those that are fully synchronized the next time you run this script. 

First, mount your iPhone (follow [this guide](https://itsfoss.com/iphone-antergos-linux/) if you not sure how to).

Then simply just run, for example,

```
./backup-iphone-photos.sh -s ~/iPhone/DCIM -d ~/Pictures/phone-backup
```