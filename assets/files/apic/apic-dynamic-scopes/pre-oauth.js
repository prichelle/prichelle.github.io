// Runs BEFORE OAuthValidateRequest (token endpoint only).
if (context.get('api.operation.path') === '/oauth2/token') {
  // Define dynamic scope prefixes here (e.g., ['consent'] or ['consent', 'payment'])
  var DYNAMIC_PREFIXES = ['consent'];

  var raw = context.get('request.parameters.scope.values[0]');
  var requested = decodeURIComponent(String(raw || '').replace(/\+/g, ' '))
    .split(/\s+/).filter(Boolean);

  var dynamicMatches = [];
  var processed = requested.map(function (s) {
    for (var i = 0; i < DYNAMIC_PREFIXES.length; i++) {
      var prefix = DYNAMIC_PREFIXES[i] + ':';
      // Matches "consent:1234", "consent:<uuid>", but not "consent" or "consent:*"
      if (s.indexOf(prefix) === 0 && s.length > prefix.length && s !== (prefix + '*')) {
        dynamicMatches.push(s);
        return prefix + '*'; // Replaces "consent:1234" with "consent:*"
      }
    }
    return s;
  });

  if (dynamicMatches.length > 0) {
    // Store original dynamic scope(s) for restoration before token generation
    context.set('consent.requested', dynamicMatches.join(' '));
    // Set placeholder scope(s) for OAuthValidateRequest
    context.set('oauth.processing.scope', processed.join(' '));
  }
}