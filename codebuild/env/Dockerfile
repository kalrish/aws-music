FROM base/archlinux

RUN pacman --noconfirm -Syu flac lame python tup

COPY get-pip.py /tmp/

RUN python /tmp/get-pip.py && pip install awscli

RUN rm -rf -- /tmp/*
