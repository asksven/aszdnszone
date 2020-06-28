FROM asksven/az-cli:1 

#RUN apt-get update && apt-get install -y dnsutils
RUN apk add --no-cache bind-tools

COPY update-ip.sh /
