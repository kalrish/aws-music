FROM base/archlinux

RUN pacman --noconfirm -Syu flac lame python tup && pacman --noconfirm -Sc

COPY get-pip.py /tmp/

RUN python /tmp/get-pip.py && pip install --no-cache-dir awscli

RUN rm -rf -- /tmp/*
