# puppet-secrets

Shows how to use secrets from Conjur in Puppet-managed configuration files.

## What will be done

We'll apply configuration of an example-app (TM) to a host using Puppet, with
the manifest:

```puppet
$aws_key_id = conjur_variable('aws_access_key_id')
$aws_secret_key = conjur_variable('aws_secret_access_key')

$app_config = '/etc/example-app.conf'

file { $app_config:
  content => "
    AWS_ACCESS_KEY_ID=$aws_key_id
    AWS_SECRET_ACCESS_KEY=$aws_secret_key
  "
}

$policy = 'puppet-demo'
conjurize_file { $app_config:
  variable_map => {
    aws_access_key_id => "!var $policy/aws/access_key_id",
    aws_secret_access_key => "!var $policy/aws/secret_access_key"
  }
}
```

As you can see, the configuration contains AWS credentials. Those will be
pulled from Conjur directly on the host (not stored in Puppet catalog).

## Build foundation image

```sh-session
$ cat Dockerfile
```

```docker
FROM layerworx/puppet

RUN yum install -y https://s3.amazonaws.com/conjur-releases/omnibus/conjur-4.24.0-1.el6.x86_64.rpm

ADD conjur.conf /etc/conjur.conf
ADD conjur-demo.pem /etc/conjur-demo.pem
ADD example-app-config.pp /tmp/example-app-config.pp
```

```sh-session
$ cat conjur.conf
account: demo
plugins: []
appliance_url: https://conjur/api
cert_file: "/etc/conjur-demo.pem"
netrc_path: /etc/conjur.identity
```

```sh-session
$ docker build -t puppet-demo .
```

## Create Conjur identity

### Create layer

### Create host

### Create the identity file

```sh-session
$ cat << IDENTITY > conjur.identity
machine https://conjur/api/authn
  login host/$(cat host.json | jsonfield id)
  password $(cat host.json | jsonfield api_key)
IDENTITY
```

## Create and grant the secrets

## Apply

```sh-session
$ docker run -v $PWD/conjur.identity:/etc/conjur.identity -it --rm puppet-demo bash

# conjur authn whoami
{"account":"demo","username":"host/puppet"}

# puppet module install conjur-conjur

# puppet apply -vd --no-stringify_facts /tmp/example-app-config.pp

# cat /etc/example-app.conf

    AWS_ACCESS_KEY_ID=<the-access-key-id>
    AWS_SECRET_ACCESS_KEY=<the-access-key>

```
