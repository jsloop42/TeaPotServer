# TeaPotServer

`TeaPotServer` is a HTTP2 server written entirely using [Swift NIO](https://github.com/apple/swift-nio). Once the request is obtained from the Swift NIO event loop, it uses `GCD` for processing each request, making use of both evented as well as threaded workflow.

The server is modelled around REST API, with route handler for `GET`, `POST`, `PUT` and `DELETE`. The server accepts HTTPS connection as well as redirects HTTP connections to HTTPS route.

The server has robust file logging with log rotation that conforms to [Swift Log API](https://github.com/apple/swift-log). 

## Running

- Make sure that the path `/var/log/tea-pot-server` exists with the right permission so that the sever can write logs in there.

```bash
cd /var/log
sudo mkdir tea-pot-server
sudo chown username:staff tea-pot-server
````

## Curl with HTTP2

Install a version of curl that supports HTTP2. With homebrew, use the command below.

```bash
$ brew install curl-openssl
$ echo 'export PATH="/usr/local/opt/curl-openssl/bin:$PATH"' >> ~/.zshrc
$ source ~/.zshrc
```

The curl version should show `HTTP2` as one of the features.

```bash
$ curl --version

# curl 7.66.0 (x86_64-apple-darwin18.6.0) libcurl/7.66.0 OpenSSL/1.1.1d zlib/1.2.11 brotli/1.0.7 c-ares/1.15.0 libssh2/1.9.0 nghttp2/1.39.2 librtmp/2.3
# Release-Date: 2019-09-11
# Protocols: dict file ftp ftps gopher http https imap imaps ldap ldaps pop3 pop3s rtmp rtsp scp sftp smb smbs smtp smtps telnet tftp 
# Features: AsynchDNS brotli GSS-API HTTP2 HTTPS-proxy IPv6 Kerberos Largefile libz Metalink NTLM NTLM_WB SPNEGO SSL TLS-SRP UnixSockets
```

### Test Endpoints

`> GET /`

```bash
curl --http2 -X GET "https://[::1]:4430/" -k | jq
```

```
{
  "status": true,
  "data": "ok"
}
```

`> GET /health`

```bash
curl --http2 -X GET "https://[::1]:4430/health" -k | jq
```

```
{
  "status": true,
  "data": {
    "server": "TeaPotServer",
    "database": "none",
    "version": "v1.0"
  }
}
```

`> POST /reverse`

```bash
curl --http2 -X POST "https://[::1]:4430/reverse" -d '{"msg": "42"}' -H 'content-type: application/json' -k | jq
```
```
{
  "status": true,
  "data": "24"
}
```

A route that does not exist sends a `404` error response.

`> POST /reversed`

```bash
curl --http2 -X POST "https://[::1]:4430/reversed" -k | jq
```

```
{
  "status": false,
  "code": 404,
  "msg": "Not Found"
}
```

## Tests

There is an `HTTPClient` which uses `URLSession` to make requests to the server with HTTPS validation disabled so that it works on self signed certificates.

To run the tests, first stop any existing copy of the server and run the test from Xcode. 

## Project Goal

- Illustrate the use of Swift NIO  in developing a production grade HTTP2 server with logging.
