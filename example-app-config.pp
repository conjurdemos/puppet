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
