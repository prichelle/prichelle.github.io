// Runs right BEFORE OAuthGenerateAccessToken.
// The advanced scope check has run by now. Put the real dynamic scope(s) back so
// they are written into the access token, next to the placeholder consent:*.
var requested = context.get('consent.requested');
if (requested) {
  var parts = String(requested).split(' ');
  if (parts.indexOf('consent:*') === -1) parts.push('consent:*');
  context.set('oauth.processing.scope', parts.join(' '));
}
