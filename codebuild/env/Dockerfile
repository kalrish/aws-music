FROM archlinux/base

RUN pacman --noconfirm -Syu flac lame python tup

COPY get-pip.py /tmp/

RUN python /tmp/get-pip.py && pip install --no-cache-dir awscli

RUN rm -rf -- /tmp/* /var/cache/pacman/pkg/
