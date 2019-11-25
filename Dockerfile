FROM alpine

LABEL maintainer="cola <colachg@gmail.com>"

RUN apk add --update tinc net-tools

EXPOSE 655/tcp 655/udp
VOLUME /etc/tinc

ENTRYPOINT [ "/usr/sbin/tincd" ]
CMD [ "-D", "-U", "nobody", "-c", "/etc/tinc", "-d 3"]