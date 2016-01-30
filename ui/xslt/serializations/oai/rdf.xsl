<?xml version="1.0" encoding="UTF-8"?>
<!--
 Changes:

    08/20/15    KEF     Don't use a <dc:identifier> URL beginning with 
                        "http://kagi" as the cho_uri.  This is a hack to keep
                        WSU's audio server URLs from being picked.  Would be
                        better to generalize to filtering out all URLs without
                        "cdm/ref" in them for ContentDM users, but that would be
                        a lot of code that I'm not ready to introduce.
    09/16/15    KEF     Added custom code for Willamette, which uses a proxy of
                        sorts in front of their contentDM system, such that the
                        public URL for the object isn't standard and needs custom
                        image URLs.
-->

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/"
	xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:oai="http://www.openarchives.org/OAI/2.0/" xmlns:xs="http://www.w3.org/2001/XMLSchema"
	xmlns:dpla="http://dp.la/terms/" xmlns:foaf="http://xmlns.com/foaf/0.1/" xmlns:edm="http://www.europeana.eu/schemas/edm/" xmlns:ore="http://www.openarchives.org/ore/terms/"
	exclude-result-prefixes="oai_dc oai xs" version="2.0">
	<xsl:output indent="yes" encoding="UTF-8"/>

	<xsl:param name="mode" select="doc('input:request')/request/parameters/parameter[name='mode']/value"/>
	<xsl:param name="repository" select="/content/controls/repository"/>
	<xsl:param name="set" select="/content/controls/set"/>
	<xsl:param name="ark" select="/content/controls/ark"/>
	<xsl:param name="production_server" select="/content/config/production_server"/>

	<xsl:template match="/">
		<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/"
			xmlns:ore="http://www.openarchives.org/ore/terms/" xmlns:xsd="http://www.w3.org/2001/XMLSchema#" xmlns:edm="http://www.europeana.eu/schemas/edm/" xmlns:dpla="http://dp.la/terms/"
			xmlns:foaf="http://xmlns.com/foaf/0.1/">
			<!-- either process only those objects with a matching $ark when the process is instantiated by the finding aid upload, or process all objects that contain an ARK URI in dc:relations when bulk harvesting -->

			<xsl:choose>
				<xsl:when test="$mode='test'">
					<xsl:choose>
						<xsl:when test="string($ark)">
							<xsl:apply-templates select="descendant::oai:metadata/*[dc:relation[contains(., $ark)]][position() &lt;= 10]"/>
						</xsl:when>
						<xsl:otherwise>
							<xsl:apply-templates select="descendant::oai:metadata/*[dc:relation[contains(., 'ark:/')]][position() &lt;= 10]"/>
						</xsl:otherwise>
					</xsl:choose>
				</xsl:when>
				<xsl:otherwise>
					<xsl:choose>
						<xsl:when test="string($ark)">
							<xsl:apply-templates select="descendant::oai:metadata/*[dc:relation[contains(., $ark)]]"/>
						</xsl:when>
						<xsl:otherwise>
							<xsl:apply-templates select="descendant::oai:metadata/*[dc:relation[contains(., 'ark:/')]]"/>
						</xsl:otherwise>
					</xsl:choose>
				</xsl:otherwise>
			</xsl:choose>

			<xsl:if test="not($mode='test')">
				<xsl:if test="descendant::oai:resumptionToken">
					<xsl:call-template name="recurse">
						<xsl:with-param name="token" select="descendant::oai:resumptionToken"/>
						<xsl:with-param name="set" select="descendant::oai:request"/>
					</xsl:call-template>
				</xsl:if>
			</xsl:if>
		</rdf:RDF>
	</xsl:template>

	<xsl:template match="oai:metadata/*">
		<xsl:variable name="relation" select="dc:relation[matches(., 'ark:/')]"/>
		<xsl:variable name="cho_uri" select="dc:identifier[not (matches(., 'https?://kaga')) and matches(., 'https?://') and not(matches(., '.jpe?g$'))][1]"/>

		<xsl:variable name="ark">
			<xsl:analyze-string select="$relation" regex=".*(ark:/[0-9]{{5}}/[A-Za-z0-9]+)">
				<xsl:matching-substring>
					<xsl:value-of select="regex-group(1)"/>
				</xsl:matching-substring>
			</xsl:analyze-string>
		</xsl:variable>

		<dpla:SourceResource rdf:about="{$cho_uri}">
			<dcterms:title>
				<xsl:value-of select="dc:title"/>
			</dcterms:title>
			<xsl:apply-templates select="dc:date|dc:type|dc:creator|dc:language|dc:contributor|dc:rights|dc:format|dc:subject"/>

			<xsl:if test="dc:description">
				<dcterms:description>

					<xsl:for-each select="dc:description[not(contains(., '.jpg'))]">
						<xsl:value-of select="normalize-space(.)"/>
						<xsl:if test="not(position()=last())">
							<xsl:text> </xsl:text>
						</xsl:if>
					</xsl:for-each>
				</dcterms:description>
			</xsl:if>

			<dcterms:isPartOf rdf:resource="{concat($production_server, $ark)}"/>
			<dcterms:relation rdf:resource="{$set}"/>
		</dpla:SourceResource>

		<!-- handle images -->
		<xsl:call-template name="resources">
			<xsl:with-param name="cho_uri" select="$cho_uri"/>
		</xsl:call-template>

		<!-- ore:Aggregation -->
		<ore:Aggregation>
			<edm:aggregatedCHO rdf:resource="{$cho_uri}"/>
			<edm:isShownAt rdf:resource="{$cho_uri}"/>
			<edm:dataProvider rdf:resource="{$production_server}contact#{$repository}"/>
			<edm:provider rdf:resource="{$production_server}"/>
			<xsl:call-template name="views">
				<xsl:with-param name="cho_uri" select="$cho_uri"/>
			</xsl:call-template>
			<dcterms:modified rdf:datatype="http://www.w3.org/2001/XMLSchema#dateTime">
				<xsl:value-of select="current-dateTime()"/>
			</dcterms:modified>
		</ore:Aggregation>
	</xsl:template>

	<xsl:template match="dc:date">
		<dcterms:date>
			<xsl:choose>
				<xsl:when test=". castable as xs:dateTime">
					<xsl:attribute name="rdf:datatype">http://www.w3.org/2001/XMLSchema#dateTime</xsl:attribute>
				</xsl:when>
				<xsl:when test=". castable as xs:date">
					<xsl:attribute name="rdf:datatype">http://www.w3.org/2001/XMLSchema#date</xsl:attribute>
				</xsl:when>
				<xsl:when test=". castable as xs:gYearMonth">
					<xsl:attribute name="rdf:datatype">http://www.w3.org/2001/XMLSchema#gYearMonth</xsl:attribute>
				</xsl:when>
				<xsl:when test=". castable as xs:gYear">
					<xsl:attribute name="rdf:datatype">http://www.w3.org/2001/XMLSchema#gYear</xsl:attribute>
				</xsl:when>
			</xsl:choose>
			<xsl:value-of select="."/>
		</dcterms:date>
	</xsl:template>

	<xsl:template match="dc:format|dc:type|dc:language|dc:creator|dc:contributor|dc:rights|dc:subject">
		<xsl:element name="dcterms:{local-name()}" namespace="http://purl.org/dc/terms/">
			<xsl:value-of select="."/>
		</xsl:element>
	</xsl:template>

	<!-- edm:WebResource -->
	<xsl:template name="resources">
		<xsl:param name="cho_uri"/>
		<xsl:choose>
			<!-- contentDM institutions -->
			<xsl:when test="$repository='waps' or $repository='idbb' or $repository='US-ula' or $repository='US-uuml' or $repository='wauar'">
				<!-- get thumbnail -->
				<edm:WebResource rdf:about="{replace($cho_uri, 'cdm/ref', 'utils/getthumbnail')}">
					<edm:rights>placeholder</edm:rights>
				</edm:WebResource>
				<edm:WebResource rdf:about="{replace($cho_uri, 'cdm/ref', 'utils/getstream')}">
					<edm:rights>placeholder</edm:rights>
				</edm:WebResource>
			</xsl:when>
			<!-- University of Montana -->
			<xsl:when test="$repository='mtg'">
				<xsl:if test="dc:description[contains(., '.jpg')]">
					<edm:WebResource rdf:about="{dc:description[contains(., '.jpg')]}">
						<edm:rights>placeholder</edm:rights>
					</edm:WebResource>
				</xsl:if>
			</xsl:when>
			<!-- Omeka -->
			<xsl:when test="$repository='orphs'">
				<xsl:if test="dc:identifier[matches(., '.jpg$')]">
					<edm:WebResource rdf:about="{dc:identifier[matches(., '.jpg$')]}">
						<edm:rights>placeholder</edm:rights>
					</edm:WebResource>
				</xsl:if>
			</xsl:when>
			<!-- Willamette - contentDM but with different CHO URI style -->
			<xsl:when test="$repository='orsaw'">
				<!-- get thumbnail -->
				<edm:WebResource rdf:about="{replace($cho_uri, 'cview/archives.html#!doc:page:(.*)/(.*)', 'utils/getthumbnail/collection/$1/id/$2')}">
					<edm:rights>placeholder</edm:rights>
				</edm:WebResource>
				<edm:WebResource rdf:about="{replace($cho_uri, 'cview/archives.html#!doc:page:(.*)/(.*)', 'utils/getstream/collection/$1/id/$2')}">
					<edm:rights>placeholder</edm:rights>
				</edm:WebResource>
			</xsl:when>
		</xsl:choose>
	</xsl:template>

	<!-- views -->
	<xsl:template name="views">
		<xsl:param name="cho_uri"/>
		<xsl:choose>
			<!-- contentDM institutions -->
			<xsl:when test="$repository='waps' or $repository='idbb' or $repository='US-ula' or $repository='US-uuml' or $repository='wauar'">
				<!-- get thumbnail -->
				<edm:preview rdf:resource="{replace($cho_uri, 'cdm/ref', 'utils/getthumbnail')}"/>
				<edm:object rdf:resource="{replace($cho_uri, 'cdm/ref', 'utils/getstream')}"/>
			</xsl:when>
			<!-- University of Montana -->
			<xsl:when test="$repository='mtg'">
				<xsl:if test="dc:description[contains(., '.jpg')]">
					<edm:preview rdf:resource="{dc:description[contains(., '.jpg')]}"/>
				</xsl:if>
			</xsl:when>
			<!-- Omeka -->
			<xsl:when test="$repository='orphs'">
				<xsl:if test="dc:identifier[matches(., '.jpg$')]">
					<edm:preview rdf:resource="{dc:identifier[matches(., '.jpg$')]}"/>
				</xsl:if>
			</xsl:when>
			<!-- Willamette - contentDM but with different CHO URI style -->
			<xsl:when test="$repository='orsaw'">
				<!-- get thumbnail -->
				<edm:preview rdf:resource="{replace($cho_uri, 'cview/archives.html#!doc:page:(.*)/(.*)', 'utils/getthumbnail/collection/$1/id/$2')}"/>
				<edm:object rdf:resource="{replace($cho_uri, 'cview/archives.html#!doc:page:(.*)/(.*)', 'utils/getstream/collection/$1/id/$2')}"/>
			</xsl:when>
		</xsl:choose>
	</xsl:template>

	<xsl:template name="recurse">
		<xsl:param name="token"/>
		<xsl:param name="set"/>

		<xsl:variable name="oai" as="node()*">
			<xsl:copy-of select="document(concat($set, '?verb=ListRecords&amp;resumptionToken=', $token))"/>
		</xsl:variable>

		<xsl:choose>
			<xsl:when test="string($ark)">
				<xsl:apply-templates select="$oai/descendant::oai:metadata/*[dc:relation[contains(., $ark)]]"/>
			</xsl:when>
			<xsl:otherwise>
				<xsl:apply-templates select="$oai/descendant::oai:metadata/*[dc:relation[contains(., 'ark:/')]]"/>
			</xsl:otherwise>
		</xsl:choose>

		<xsl:if test="$oai/descendant::oai:resumptionToken">
			<xsl:call-template name="recurse">
				<xsl:with-param name="token" select="$oai/descendant::oai:resumptionToken"/>
				<xsl:with-param name="set" select="$set"/>
			</xsl:call-template>
		</xsl:if>
	</xsl:template>

</xsl:stylesheet>
