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
