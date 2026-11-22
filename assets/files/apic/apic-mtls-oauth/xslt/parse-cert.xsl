<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:dp="http://www.datapower.com/extensions"
  xmlns:apigw="http://www.ibm.com/xmlns/datapower/2017/11/apigateway"
  extension-element-prefixes="dp apigw"
  exclude-result-prefixes="dp apigw">
  <xsl:output method="xml" indent="yes"/>
  <xsl:template match="/">
    <!-- pure base64 certificate prepared by normalize-cert.js -->
    <xsl:variable name="base64cert" select="apigw:get-variable('x-client-certificate')"/>

    <!-- dp:get-cert-details parses a certificate given as a "cert:<base64>" string -->
    <xsl:variable name="certDetails" select="dp:get-cert-details(concat('cert:', $base64cert))"/>

    <xsl:variable name="subject" select="string($certDetails/CertificateDetails/*[local-name()='Subject'])"/>
    <xsl:variable name="issuer"  select="string($certDetails/CertificateDetails/*[local-name()='Issuer'])"/>
    <xsl:variable name="serial"  select="string($certDetails/CertificateDetails/*[local-name()='SerialNumber'])"/>
    <xsl:variable name="notAfter" select="string($certDetails/CertificateDetails/*[local-name()='NotAfter'])"/>

    <!-- debug: list every node returned by dp:get-cert-details in the gateway log -->
    <xsl:for-each select="$certDetails/CertificateDetails/*">
      <xsl:message dp:priority="debug">
        <xsl:value-of select="concat('[CERT] ', local-name(), ' = ', substring(string(.), 1, 80))"/>
      </xsl:message>
    </xsl:for-each>

    <!-- hand the values back to the assembly as API Connect context variables -->
    <apigw:set-variable name="'localcertsubject'"  value="$subject"/>
    <apigw:set-variable name="'localcertissuer'"   value="$issuer"/>
    <apigw:set-variable name="'localcertserial'"   value="$serial"/>
    <apigw:set-variable name="'localcertnotafter'" value="$notAfter"/>

    <xsl:copy-of select="/"/>
  </xsl:template>
</xsl:stylesheet>
