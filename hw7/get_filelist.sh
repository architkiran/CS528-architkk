#!/bin/bash
if [ ! -f ~/filelist.txt ] || [ $(wc -l < ~/filelist.txt) -lt 20000 ]; then
    echo "Generating filelist..."
    gsutil ls gs://bu-cs528-architkk/ | grep '\.html$' > ~/filelist.txt
fi
echo "Filelist ready: $(wc -l < ~/filelist.txt) files"
cp ~/filelist.txt /tmp/filelist.txt
