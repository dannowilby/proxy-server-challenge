FROM golang

# Install Nginx
RUN apt -y install curl ca-certificates
RUN apt -y install nginx

COPY proxy/nginx.conf /etc/nginx/nginx.conf

ENTRYPOINT [ "/etc/init.d/nginx" ]