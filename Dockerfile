FROM alpine

LABEL maintainer="cola <colachg@gmail.com>"

RUN apk add --update --no-cache tinc net-tools tini

EXPOSE 655/tcp 655/udp
VOLUME /etc/tinc

ENTRYPOINT [ "/sbin/tini", "--" ]
CMD [ "/usr/sbin/tincd", "-D", "-U", "nobody", "-c", "/etc/tinc", "-d 3"]