FROM layerworx/puppet

RUN yum install -y https://s3.amazonaws.com/conjur-releases/omnibus/conjur-4.24.0-1.el6.x86_64.rpm

ADD conjur.conf /etc/conjur.conf
ADD conjur-demo.pem /etc/conjur-demo.pem
ADD example-app-config.pp /tmp/example-app-config.pp
