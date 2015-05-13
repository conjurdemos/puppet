# puppet-secrets

This example shows how you can use secrets from Conjur in Puppet-managed configuration files.

## What will be done

We'll apply the configuration of an example app to a host using Puppet with this manifest:

```puppet
$app_config = '/etc/example-app.conf'

# conjur_variable() just generates placeholders for the secrets
$aws_key_id = conjur_variable('myapp_key_id')
$aws_secret_key = conjur_variable('myapp_access_key')

file { $app_config:
  content => "
    AWS[key_id]=$aws_key_id
    AWS[secret_key]=$aws_secret_key
  "
}
# note the master only ever sees the placeholders

# on the agent side: replace placeholders with secrets pulled from Conjur
# (this happens only on applying the manifest)
conjurize_file { $app_config:
  variable_map => {
    myapp_key_id => "!var aws_access_key_id",
    myapp_access_key => "!var aws_secret_access_key"
  }
}
```

As you can see, the configuration contains AWS credentials. Those will be
pulled from Conjur directly on the host (not stored in Puppet catalog).

## Prerequisites
[Launch a Conjur demo environment](http://demo-factory-conjur.herokuapp.com/request/secrets). 
It contains all tools and configuration needed to complete this example.

# Walkthrough

## 1. Build a foundation image

First we'll move into the example directory and copy the public key so our Dockerfile can
add it to the image.

```sh-session
$ cd puppet-secrets
$ ./init.rb
```

We're using a Puppet base image and installing the Conjur CLI and configuration to create our foundation image.
We also add the manifest file to the image.

```sh-session
$ cat Dockerfile
FROM layerworx/puppet

RUN yum install -y https://s3.amazonaws.com/conjur-releases/omnibus/conjur-4.24.0-1.el6.x86_64.rpm

ADD conjur.conf /etc/conjur.conf
ADD conjur-demo.pem /etc/conjur-demo.pem
ADD example-app-config.pp /tmp/example-app-config.pp
```

`conjur.conf` points the node to the Conjur server.

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

## 2. Create a Conjur identity

To allow the Puppet node to connect to Conjur, we will give it a [host identity](https://developer.conjur.net/key_concepts#host_identity).
This is a type of identity in Conjur specifically designed for use by machines and code.
They best way to manage your hosts is to organize them into [layers](https://developer.conjur.net/reference/services/directory/layer). A layer is like a user group, but it's for hosts. We set permissions on the layer and when hosts join the layer they are granted its permissions.

### a. Create a layer

```sh-session
$ conjur layer create example-layer
{
  "id": "example-layer",
  "userid": "demo",
  "ownerid": "demo:user:demo",
  "roleid": "demo:layer:example-layer",
  "resource_identifier": "demo:layer:example-layer",
  "hosts": [

  ]
}
```

### b. Create a host

```sh-session
$ conjur host create example-app | tee host.json
{
  "id": "example-app",
  "userid": "demo",
  "created_at": "2015-05-11T19:11:52Z",
  "ownerid": "demo:user:demo",
  "roleid": "demo:host:example-app",
  "resource_identifier": "demo:host:example-app",
  "api_key": "3c1zzvm1skbpbp21pzqfy2evzeehrsefk3b5ktpw3qj946dkh9qab"
}
```

Now add the host to the layer.

```sh-session
$ conjur layer hosts add example-layer example-app
Host added
```

We can now see the host is in the layer.

```sh-session
$ conjur layer show example-layer
{
  "id": "example-layer",
  "userid": "demo",
  "ownerid": "demo:user:demo",
  "roleid": "demo:layer:example-layer",
  "resource_identifier": "demo:layer:example-layer",
  "hosts": [
    "demo:host:example-app"
  ]
}
```

### c. Create the identity file

This identity will be mounted into the Docker container in Step 4.

```sh-session
$ cat << IDENTITY > conjur.identity
machine https://conjur/api/authn
  login host/$(cat host.json | jsonfield id)
  password $(cat host.json | jsonfield api_key)
IDENTITY
```

Only the owner should have access to the identity file:

```sh-session
$ chmod 0600 conjur.identity
```

## 3. Create and grant the secrets

Now we can create the AWS variables and give the layer permission to view their values.

```sh-session
$ conjur variable create aws_access_key_id AKIAIIYS8CRI7IZZ6YGA
{...}
$ conjur variable create aws_secret_access_key PuU3s0vn0yn0EZOniktCt8dn9KOUu2BETx++wgvD
{...}

$ conjur resource permit variable:aws_access_key_id layer:example-layer execute
Permission granted
$ conjur resource permit variable:aws_secret_access_key layer:example-layer execute
Permission granted
```

## 4. Apply Puppet to the node

```sh-session
$ docker run --add-host conjur:10.0.1.2 -v $PWD/conjur.identity:/etc/conjur.identity -it --rm puppet-demo bash

# conjur authn whoami
{"account":"demo","username":"host/example-app"}

# puppet module install conjur-conjur

# puppet apply -vd --no-stringify_facts /tmp/example-app-config.pp

# cat /etc/example-app.conf

    AWS_ACCESS_KEY_ID=<the-access-key-id>
    AWS_SECRET_ACCESS_KEY=<the-access-key>

```
