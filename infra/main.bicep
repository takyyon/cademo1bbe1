targetScope = 'subscription'
param environmentName string
param location string
param resourceGroupName string = ''
param azureTags string = ''

param acaLocation string = 'northcentralusstage' // use North Central US (Stage) for ACA resources
param acaEnvironmentName string = 'aca-env'
param postgreSqlName string = 'postgres'
param redisCacheName string = 'redis'
param webServiceName string = 'web-service'
param apiServiceName string = 'api-service'
param webImageName string = 'docker.io/ahmelsayed/springboard-web:latest'
param apiImageName string = 'docker.io/ahmelsayed/springboard-api:latest'
var azdTag = { 'azd-env-name': environmentName }
var tags = union(empty(azureTags) ? {} : base64ToJson(azureTags), azdTag)

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${environmentName}-rg'
  location: location
  tags: tags
}

module acaEnvironment './core/host/container-apps-environment.bicep' = {
  name: 'container-apps-environment'
  scope: rg
  params: {
    name: acaEnvironmentName
    location: acaLocation
    tags: tags
  }
}

module postgreSql './core/host/springboard-container-app.bicep' = {
  name: 'postgres'
  scope: rg
  params: {
    name: postgreSqlName
    location: acaLocation
    tags: tags
    managedEnvironmentId: acaEnvironment.outputs.id
    serviceType: 'postgres'
  }
}

module redis './core/host/springboard-container-app.bicep' = {
  name: 'redis'
  scope: rg
  params: {
    name: redisCacheName
    location: acaLocation
    tags: tags
    managedEnvironmentId: acaEnvironment.outputs.id
    serviceType: 'redis'
  }
}

// The application backend
module api './core/host/container-app.bicep' = {
  name: 'api'
  scope: rg
  params: {
    name: apiServiceName
    location: acaLocation
    tags: tags
    managedEnvironmentId: acaEnvironment.outputs.id
    imageName: apiImageName
    targetPort: 80
    allowedOrigins: [ '${webServiceName}.${acaEnvironment.outputs.defaultDomain}' ]
    serviceBinds: [
      redis.outputs.serviceBind
      postgreSql.outputs.serviceBind
    ] 
  }
}

// the application frontend
module web './core/host/container-app.bicep' = {
  name: 'web'
  scope: rg
  params: {
    name: webServiceName
    location: acaLocation
    tags: tags
    managedEnvironmentId: acaEnvironment.outputs.id
    imageName: webImageName
    targetPort: 80
    env: [
      {
        name: 'REACT_APP_API_BASE_URL'
        value: 'https://${apiServiceName}.${acaEnvironment.outputs.defaultDomain}'
      }
    ]
  }
}

// module pgweb './core/host/container-app.bicep' = {
//   name: 'pgweb'
//   scope: rg
//   params: {
//     name: 'pgweb'
//     location: acaLocation
//     tags: tags
//     managedEnvironmentId: acaEnvironment.outputs.id
//     imageName: 'docker.io/sosedoff/pgweb:latest'
//     targetPort: 8081
//     command: [
//       '/bin/sh'
//     ]
//     args: [
//       '-c'
//       'PGWEB_DATABASE_URL=$POSTGRES_URL /usr/bin/pgweb --bind=0.0.0.0 --listen=8081'
//     ]
//     serviceBinds: [
//       postgreSql.outputs.serviceBind
//     ] 
//   }
// }

// module redisStat './core/host/container-app.bicep' = {
//   name: 'redis-stat'
//   scope: rg
//   params: {
//     name: 'redis-stat'
//     location: acaLocation
//     tags: tags
//     managedEnvironmentId: acaEnvironment.outputs.id
//     imageName: 'docker.io/insready/redis-stat:latest'
//     targetPort: 3000
//     command: [
//       '/bin/sh'
//     ]
//     args: [
//       '-c'
//       'redis-stat $REDIS_HOST:$REDIS_PORT --auth=$REDIS_PASSWORD --server=0.0.0.0'
//     ]
//     serviceBinds: [
//       redis.outputs.serviceBind
//     ] 
//   }
// }

// module kafka './core/host/springboard-container-app.bicep' = {
//   name: 'kafka'
//   scope: rg
//   params: {
//     name: 'kafka-1'
//     location: acaLocation
//     managedEnvironmentId: acaEnvironment.outputs.id
//     serviceType: 'kafka'
//   }
// }

// module kafkaApp1 './core/host/container-app.bicep' = {
//   name: 'kafka-ui'
//   scope: rg
//   params: {
//     name: 'kafka-ui-1'
//     location: acaLocation
//     managedEnvironmentId: acaEnvironment.outputs.id
//     imageName: ''
//     targetPort: 8080
//     serviceBinds: [
//       kafka.outputs.serviceBind
//     ]
//     command: [
//       '/bin/sh'
//     ]
//     args: [
//       '-c'
//       '''
//       KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS="$KAFKA_BOOTSTRAP_SERVERS" \
//       KAFKA_CLUSTERS_0_PROPERTIES_SASL_JAAS_CONFIG="$KAFKA_PROPERTIES_SASL_JAAS_CONFIG" \
//       KAFKA_CLUSTERS_0_PROPERTIES_SASL_MECHANISM="$KAFKA_SASL_MECHANISM" \
//       KAFKA_CLUSTERS_0_PROPERTIES_SECURITY_PROTOCOL="$KAFKA_SECURITY_PROTOCOL" \
//       java $JAVA_OPTS -jar kafka-ui-api.jar
//       '''
//     ]
//     env: [
//       {
//         name: 'KAFKA_CLUSTERS_0_NAME'
//         value: kafka.outputs.name
//       }
//     ]
//     // cpu: '1.0'
//     // memory: '1.0Gi'
//   }
// }

// App outputs
output REACT_APP_API_BASE_URL string = api.outputs.uri
output REACT_APP_WEB_BASE_URL string = web.outputs.uri
