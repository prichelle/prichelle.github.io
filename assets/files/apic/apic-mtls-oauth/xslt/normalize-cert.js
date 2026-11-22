// Step 1 of the XSLT variant: normalise the certificate header.
// The XSLT needs pure base64 (no PEM armor, no line breaks) to build a "cert:" URL.
var raw = context.get('request.headers.x-client-certificate');

var base64only = String(raw || '')
  .replace('-----BEGIN CERTIFICATE-----', '')
  .replace('-----END CERTIFICATE-----', '')
  .replace(/\s+/g, '');

// context variable read by the stylesheet with apigw:get-variable('x-client-certificate')
context.set('x-client-certificate', base64only);
