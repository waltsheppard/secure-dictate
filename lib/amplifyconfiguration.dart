const String amplifyconfig = '''
{
  "auth": {
    "plugins": {
      "awsCognitoAuthPlugin": {
        "UserAgent": "aws-amplify-cli/2.0",
        "Version": "1.0",
        "credentials_provider": {
          "cognito_identity_pool_id": "REPLACE_WITH_IDENTITY_POOL_ID",
          "region": "REPLACE_WITH_REGION"
        },
        "CognitoUserPool": {
          "Default": {
            "PoolId": "REPLACE_WITH_USER_POOL_ID",
            "AppClientId": "REPLACE_WITH_APP_CLIENT_ID",
            "AppClientSecret": "REPLACE_WITH_APP_CLIENT_SECRET_IF_ENABLED_OR_REMOVE",
            "Region": "REPLACE_WITH_REGION"
          }
        },
        "Auth": {
          "Default": {
            "authenticationFlowType": "USER_SRP_AUTH"
          }
        }
      }
    }
  }
}
''';



