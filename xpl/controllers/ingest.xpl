<?xml version="1.0" encoding="UTF-8"?>
<p:pipeline xmlns:p="http://www.orbeon.com/oxf/pipeline" xmlns:oxf="http://www.orbeon.com/oxf/processors" xmlns:xforms="http://www.w3.org/2002/xforms" xmlns:xxforms="http://orbeon.org/oxf/xml/xforms">

	<p:param type="input" name="data"/>
	<!--<p:param type="output" name="data"/>-->

	<p:processor name="oxf:request">
		<p:input name="config">
			<config>
				<include>/request</include>
			</config>
		</p:input>
		<p:output name="data" id="request"/>
	</p:processor>

	<!-- set up iteration of sets -->
	<p:processor name="oxf:unsafe-xslt">
		<p:input name="data" href="#request"/>
		<p:input name="config">
			<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
				<xsl:output indent="yes"/>
				<xsl:template match="/">
					<sets>
						<xsl:for-each select="tokenize(/request/parameters/parameter[name='sets']/value, '\|')">
							<set>
								<xsl:value-of select="."/>
							</set>
						</xsl:for-each>
					</sets>
				</xsl:template>
			</xsl:stylesheet>
		</p:input>
		<p:output name="data" id="sets"/>
	</p:processor>

	<p:for-each href="#sets" select="//set" id="response" root="response">
		<!-- generate the controls to include the repository ID and ARK URI -->
		<p:processor name="oxf:unsafe-xslt">
			<p:input name="data" href="#request"/>
			<p:input name="config">
				<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
					<xsl:output indent="yes"/>

					<xsl:param name="repository" select="/request/parameters/parameter[name='repository']/value"/>
					<xsl:param name="ark" select="/request/parameters/parameter[name='ark']/value"/>

					<xsl:template match="/">
						<controls>
							<ark>
								<xsl:value-of select="$ark"/>
							</ark>
							<repository>
								<xsl:value-of select="$repository"/>
							</repository>
						</controls>
					</xsl:template>
				</xsl:stylesheet>
			</p:input>
			<p:output name="data" id="controls"/>
		</p:processor>

		<!-- generate URL Generator config -->
		<p:processor name="oxf:unsafe-xslt">
			<p:input name="request" href="#request"/>
			<p:input name="data" href="current()"/>
			<p:input name="config">
				<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
					<xsl:output indent="yes"/>
					<xsl:template match="/">
						<config>
							<url>
								<xsl:value-of select="/set"/>
							</url>
							<mode>xml</mode>
							<content-type>application/xml</content-type>
							<header>
								<name>User-Agent</name>
								<value>XForms/harvester.orbiscascade.org</value>
							</header>
							<encoding>utf-8</encoding>
						</config>
					</xsl:template>
				</xsl:stylesheet>
			</p:input>
			<p:output name="data" id="url-generator-config"/>			
		</p:processor>

		<!-- get OAI-PMH feed -->
		<p:processor name="oxf:url-generator">
			<p:input name="config" href="#url-generator-config"/>
			<p:output name="data" id="oai-pmh"/>
		</p:processor>

		<!-- execute XSLT transformation from OAI to RDF/XML -->
		<p:processor name="oxf:pipeline">
			<p:input name="data" href="#oai-pmh"/>
			<p:input name="controls" href="#controls"/>
			<p:input name="config" href="../views/serializations/oai/rdf.xpl"/>
			<p:output name="data" id="rdf"/>
		</p:processor>
		
		<!-- generate the SPARQL/Update delete query-->
		<p:processor name="oxf:unsafe-xslt">
			<p:input name="data" href="#request"/>
			<p:input name="config">
				<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
					
					<xsl:param name="ark" select="/request/parameters/parameter[name='ark']/value"/>
					
					<xsl:template match="/">
						<xsl:variable name="template">
							<![CDATA[ PREFIX dcterms:	<http://purl.org/dc/terms/>
PREFIX edm:	<http://www.europeana.eu/schemas/edm/>
DELETE {?s ?p ?o} WHERE { 
{?cho dcterms:relation <URI> . 
?ore edm:aggregatedCHO ?cho .
?ore edm:object ?s .
?s ?p ?o}
UNION {?cho dcterms:relation <URI> . 
?s edm:aggregatedCHO ?cho . ?s ?p ?o }
UNION { ?s dcterms:relation <URI> . 
?s ?p ?o }
}]]>
						</xsl:variable>
						
						<query>
							<xsl:value-of select="replace($template, 'URI', concat('http://nwda.orbiscascade.org/', $ark))"/>
						</query>
					</xsl:template>
				</xsl:stylesheet>
			</p:input>
			<p:output name="data" id="sparql-update"/>
		</p:processor>
		
		<!-- use XForms submission to delete triples -->
		<p:processor name="oxf:xforms-submission">
			<p:input name="request" href="#sparql-update"/>
			<p:input name="submission">
				<xforms:submission action="http://localhost:3030/nwda/update" serialization="text/plain" replace="none" method="post"
					mediatype="application/sparql-update"/>
			</p:input>
			<p:output name="response" id="null1"/>
		</p:processor>

		<!-- use XForms submission processor to post data to endpoint -->
		<p:processor name="oxf:xforms-submission">
			<p:input name="request" href="#rdf"/>
			<p:input name="submission">
				<xforms:submission action="http://localhost:3030/nwda/data?default" replace="none" method="post" mediatype="application/rdf+xml"/>
			</p:input>
			<p:output name="response" id="null2"/>
		</p:processor>
		
		<p:processor name="oxf:identity">
			<p:input name="data" href="aggregate('content', #null1, #null2)"/>
			<p:output name="data" ref="response"/>
		</p:processor>
	</p:for-each>
	
	<p:processor name="oxf:unsafe-xslt">
		<p:input name="data" href="#response"/>		
		<p:input name="config">
			<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
				<xsl:output indent="yes"/>
				
				<xsl:template match="/">
					<html xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:type="xs:string" xmlns:xs="http://www.w3.org/2001/XMLSchema">
						<head>
							<title>202 Accepted</title>
						</head>
						<body>
							<h1>202 Accepted</h1>
							<p>The process has been accepted.</p>
						</body>
					</html>
				</xsl:template>
			</xsl:stylesheet>
		</p:input>
		<p:output name="data" id="body"/>
	</p:processor>

	<p:processor name="oxf:http-serializer">
		<p:input name="data" href="#body"/>
		<p:input name="config">
			<config>
				<status-code>202</status-code>
				<content-type>text/plain</content-type>				
			</config>
		</p:input>
	</p:processor>

	<!--<p:processor name="oxf:identity">
		<p:input name="data" href="#response"/>
		<p:output name="data" ref="data"/>
	</p:processor>-->
</p:pipeline>
