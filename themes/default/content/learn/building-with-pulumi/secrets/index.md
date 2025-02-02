---
title: "Working with Secrets"
layout: topic
date: 2021-09-20T08:33:36-05:00
draft: false
description: Explore how Pulumi handles secrets across all environments.
meta_desc: Explore how Pulumi handles secrets across all environments.
index: 4
estimated_time: 10
meta_image: meta.png
authors:
    - matt-stratton
tags:
    - secrets
---

All resource input and output values are recorded as _state_ and are stored
in the Pulumi Service, a file, or a pluggable provider that you choose. These
raw values are usually just server names, configuration settings, and so on. In
some cases, however, these values contain sensitive data, such as database
passwords or service tokens.

The Pulumi Service always transmits and stores entire state files securely;
however, Pulumi also supports encrypting specific values as "secrets" for extra
protection. Encryption ensures that these values never appear as plain-text in
your state file. By default, the encryption method uses automatic, per-stack
encryption keys provided by the Pulumi Service or you can use a
[provider of your own choosing](/docs/intro/concepts/secrets#configuring-secrets-encryption)
instead.

To encrypt a configuration setting before runtime, you can use the CLI command
`pulumi config set` command with a `--secret` flag. All these encrypted values
are stored in your state file.

Inside our `my-first-app` program that we have been working with, let's switch
back to the `dev` stack and set a username and password for MongoDB:

{{% choosable language typescript %}}

```bash
$ pulumi stack select dev

$ pulumi config set mongoUsername admin
$ pulumi config set --secret mongoPassword S3cr37
```

If we list the configuration for our stack, the plain-text value for
`mongoPassword` will not be printed:

```bash
$ pulumi config
KEY               VALUE
backendPort      3000
database          cart
frontendPort     3001
mongoPassword    [secret]
mongoUsername    admin
mongoHost        mongodb://mongo:27017
mongoPort        27017
nodeEnvironment  development
```

This is also encrypted in the associated configuration file:

```bash
$ cat Pulumi.dev.yaml

config:
  my-first-app:backendPort: "3000"
  my-first-app:database: cart
  my-first-app:frontendPort: "3001"
  my-first-app:mongoPassword:
    secure: AAABADQXFlU0mxbTmNyl39UfVg4DdFoL94SCNMX3MkvZhBZjeAM=
  my-first-app:mongoUsername: admin
  my-first-app:mongoHost: mongodb://mongo:27017
  my-first-app:mongoPort: "27017"
  my-first-app:nodeEnvironment: development
```

{{% /choosable %}}

{{% choosable language python %}}

```bash
$ pulumi stack select dev

$ pulumi config set mongo_username admin
$ pulumi config set --secret mongo_password S3cr37
```

If we list the configuration for our stack, the plain-text value for
`mongo_password` will not be printed:

```bash
$ pulumi config
KEY               VALUE
backend_port      3000
database          cart
frontend_port     3001
mongo_password    [secret]
mongo_username    admin
mongo_host        mongodb://mongo:27017
mongo_port        27017
node_environment  development
```

This is also encrypted in the associated configuration file:

```bash
$ cat Pulumi.dev.yaml

config:
  my-first-app:backend_port: "3000"
  my-first-app:database: cart
  my-first-app:frontend_port: "3001"
  my-first-app:mongo_password:
    secure: AAABADQXFlU0mxbTmNyl39UfVg4DdFoL94SCNMX3MkvZhBZjeAM=
  my-first-app:mongo_username: admin
  my-first-app:mongo_host: mongodb://mongo:27017
  my-first-app:mongo_port: "27017"
  my-first-app:node_environment: development
```

{{% /choosable %}}

We can access the secrets similarly to other configuration data, however we must
specify that it is a secret. Add this code to {{< langfile >}} inside of `my-first-app`:

{{< chooser language "typescript,python" / >}}

{{% choosable language typescript %}}

```typescript
const config = new pulumi.Config();
// ...

const mongoUsername = config.require("mongoUsername");
export const mongoPassword = config.requireSecret("mongoPassword");
```

{{% /choosable %}}

{{% choosable language python %}}

```python

config = pulumi.Config()
#...

mongo_username = config.require("mongo_username")
mongo_password = config.require_secret("mongo_password")
```

{{% /choosable %}}

We need to make a few changes to use this new username and password. First,
let's go ahead and make sure when our `mongo` container is created, it has the
correct username and password. Update the container definition to use the `envs`
input property to set environment variables for the database username and password:

{{< chooser language "typescript,python" / >}}

{{% choosable language typescript %}}

```typescript
const mongoContainer = new docker.Container("mongoContainer", {
    image: mongoImage.repoDigest,
    name: `mongo-${stack}`,
    ports: [
        {
            internal: mongoPort,
            external: mongoPort,
        },
    ],
    networksAdvanced: [
        {
            name: network.name,
            aliases: ["mongo"],
        },
    ],
    envs: [
        `MONGO_INITDB_ROOT_USERNAME=${mongoUsername}`,
        pulumi.interpolate`MONGO_INITDB_ROOT_PASSWORD=${mongoPassword}`,
    ],
});
```

Then, we need to update the backend container to use the new authentication. We need to slightly change the value of `mongoHost` first:

```bash
$ pulumi config set mongoHost mongo
```

{{% /choosable %}}

{{% choosable language python %}}

```python
mongo_container = docker.Container("mongo_container",
                                   image=mongo_image.repo_digest,
                                   name=f"mongo-{stack}",
                                   ports=[docker.ContainerPortArgs(
                                       internal=mongo_port,
                                       external=mongo_port
                                   )],
                                   networks_advanced=[docker.ContainerNetworksAdvancedArgs(
                                       name=network.name,
                                       aliases=["mongo"]
                                   )],
                                   envs=[
                                         f"MONGO_INITDB_ROOT_USERNAME={mongo_username}",
                                         mongo_password.apply(lambda password: f"MONGO_INITDB_ROOT_PASSWORD={password}")
                                   ])
```

Then, we need to update the backend container to use the new authentication. We need to slightly change the value of `mongo_host` first:

```bash
$ pulumi config set mongo_host mongo
```

{{% /choosable %}}

Then, update the backend container resource as follows:

{{< chooser language "typescript,python" / >}}

{{% choosable language typescript %}}

```typescript
const backendContainer = new docker.Container("backendContainer", {
    name: `backend-${stack}`,
    image: backend.baseImageName,
    ports: [
        {
            internal: backendPort,
            external: backendPort,
        },
    ],
    envs: [
        pulumi.interpolate`DATABASE_HOST=mongodb://${mongoUsername}:${mongoPassword}@${mongoHost}:${mongoPort}`,
        `DATABASE_NAME=${database}?authSource=admin`,
        `NODE_ENV=${nodeEnvironment}`,
    ],
    networksAdvanced: [
        {
            name: network.name,
        },
    ],
}, { dependsOn: [ mongoContainer ]});
```

And finally, add a line at the end of the program to export password as a stack output:

```typescript
#...
export const mongoPassword = mongoPassword;
```

{{% /choosable %}}

{{% choosable language python %}}

```python
backend_container = docker.Container("backend_container",
                                     image=backend.base_image_name,
                                     name=f"backend-{stack}",
                                     ports=[docker.ContainerPortArgs(
                                         internal=backend_port,
                                         external=backend_port
                                     )],
                                     envs=[
                                         Output.concat(
                                             "DATABASE_HOST=mongodb://",
                                             mongo_username,
                                             ":",
                                             config.require_secret("mongo_password"),
                                             "@",
                                             mongo_host,
                                             ":",
                                             f"{mongo_port}",
                                         ), #Changed!
                                         f"DATABASE_NAME={database}?authSource=admin", # Also changed!
                                         f"NODE_ENV={node_environment}"
                                     ],
                                     networks_advanced=[docker.ContainerNetworksAdvancedArgs(
                                         name=network.name
                                     )],
                                     opts=pulumi.ResourceOptions(depends_on=[mongo_container])
                                     )
```

And finally, add a line at the end of the program to export password as a stack output:

```python
#...
pulumi.export("mongo_password", mongo_password)
```

{{% /choosable %}}

When we run `pulumi up`, we find the output is set (so our use of the secret
worked!), but Pulumi knows that value was a secret, so when we try to set it as
an output, it will not display.

If we would like to get the plain-text value, we can do it with this command:

{{% choosable language typescript %}}

```bash
$ pulumi stack output mongoPassword --show-secrets
S3cr37
```

{{% /choosable %}}

{{% choosable language python %}}

```bash
$ pulumi stack output mongo_password --show-secrets
S3cr37
```

{{% /choosable %}}

For more information on how Pulumi uses secrets, including how to set them
programmatically, review the
[corresponding docs](/docs/intro/concepts/secrets/).

---

Congratulations! You’ve finished the Building with Pulumi pathway! In this pathway, you learned all about stacks, outputs, and stack references so you can work in multiple environments. You also learned about secrets in Pulumi and how to use them in your programs.

Go build new things, and watch this space for more learning experiences on Pulumi!
