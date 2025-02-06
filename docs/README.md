
![challenge screenshot](challenge.jpg)

To view a written out version, check [here](challenge.md).

# My solution
is still a work in progress.

At first, a simple Golang server that manually forwarded all requests seemed
like it might have been a good option to me. However, I remembered using Nginx
for this exact problem a few years ago. Unfortunately I also forgot that Nginx
does not implement the `CONNECT` method. The choices then to solve this issue
would be using a patched 3rd-party build of Nginx with a proxy `CONNECT` method,
or instead to use Apache HTTP Server's proxy modules.