module github.com/pulumi/pulumi-hugo

go 1.16

replace github.com/pulumi/pulumi-hugo/themes/default => ./themes/default

require (
	github.com/pulumi/pulumi-hugo/themes/default v0.0.0-20221011161342-11408ffe7e87 // indirect
	github.com/pulumi/registry/themes/default v0.0.0-20221011031657-b54e33cefb2a // indirect
)
