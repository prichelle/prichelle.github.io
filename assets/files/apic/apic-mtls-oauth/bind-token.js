// GatewayScript placed in the token path of the Native OAuth provider assembly,
// right before the OAuthGenerateAccessToken policy.
// RFC 8705 section 3.1: bind the access token to the client certificate.
// APIC access tokens are opaque, so the binding is stored as token metadata ("miscinfo"):
//   x5t#S256 : SHA-256 thumbprint of the DER certificate, base64url (the RFC 8705 "cnf" value)
//   fp       : SHA-1 fingerprint in the same format as the context variable
//              application.certificate.fingerprint, so that the protected API can compare
//              without computing any hash.
var crypto = require('crypto');

var raw = context.get('request.headers.x-client-certificate');   // relayed by the TLS terminator
var b64 = String(raw || '')
  .replace(/-----BEGIN CERTIFICATE-----|-----END CERTIFICATE-----/g, '')
  .replace(/\s+/g, '');

if (!b64) {
  context.reject('invalid_client', 'A client certificate is required to obtain a certificate-bound token');
  context.message.statusCode = '401 Unauthorized';
} else {
  var der = Buffer.from(b64, 'base64');
  var x5t = crypto.createHash('sha256').update(der).digest('base64')
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  var fp = crypto.createHash('sha1').update(der).digest('hex').toUpperCase().replace(/(..)(?=.)/g, '$1:');
  var binding = 'x5t#S256=' + x5t + ';fp=' + fp;
  context.set('oauth.processing.metadata.access_token', binding);   // inside the token -> misc_info
  context.set('oauth.processing.metadata.payload', binding);        // returned to the client as "metadata"
}
