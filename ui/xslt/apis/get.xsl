<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:res="http://www.w3.org/2005/sparql-results#" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:saxon="http://saxon.sf.net/"
	version="2.0">
	<xsl:include href="../templates.xsl"/>

	<xsl:param name="ark" select="doc('input:request')/request/parameters/parameter[name='ark']/value"/>
	<xsl:param name="page" as="xs:integer">
		<xsl:choose>
			<xsl:when test="string-length(doc('input:request')/request/parameters/parameter[name='page']/value) &gt; 0 and doc('input:request')/request/parameters/parameter[name='page']/value castable
				as xs:integer and number(doc('input:request')/request/parameters/parameter[name='page']/value) > 0">
				<xsl:value-of select="doc('input:request')/request/parameters/parameter[name='page']/value"/>
			</xsl:when>
			<xsl:otherwise>1</xsl:otherwise>
		</xsl:choose>
	</xsl:param>

	<xsl:variable name="display_path">../</xsl:variable>
	<xsl:variable name="url" select="/content/config/production_server"/>
	<xsl:variable name="repositoryLabel" select="descendant::res:binding[@name='repository'][1]/res:literal"/>
	<xsl:variable name="repositoryUri" select="descendant::res:binding[@name='repo_uri'][1]/res:uri"/>

	<!-- get the did of the related finding aid -->
	<xsl:variable name="did" as="element()*">
		<node>
			<xsl:if test="doc-available(concat($url, $ark, '/xml'))">
				<xsl:copy-of select="document(concat($url, $ark, '/xml'))//*[local-name()='archdesc']/*[local-name()='did']"/>
			</xsl:if>
		</node>
	</xsl:variable>
	

	<!-- pagination -->
	<xsl:variable name="limit" as="xs:integer">100</xsl:variable>
	<xsl:variable name="offset" select="($page - 1) * $limit"/>

	<xsl:variable name="numFound" select="descendant::res:sparql[2]//res:binding[@name='numFound']/res:literal"/>
	

	<xsl:template match="/">
		<xsl:apply-templates select="descendant::res:sparql[1]" mode="root"/>
	</xsl:template>

	<xsl:template match="res:sparql" mode="root">
		<html lang="en">
			<head>
				<title><xsl:value-of select="/content/config/title"/>: </title>
				<meta name="viewport" content="width=device-width, initial-scale=1"/>
				<!-- bootstrap -->
				<script type="text/javascript" src="https://ajax.googleapis.com/ajax/libs/jquery/1.11.0/jquery.min.js"/>
				<link rel="stylesheet" href="http://netdna.bootstrapcdn.com/bootstrap/3.1.1/css/bootstrap.min.css"/>
				<script src="http://netdna.bootstrapcdn.com/bootstrap/3.1.1/js/bootstrap.min.js"/>
				<!-- fancybox -->
				<link rel="stylesheet" href="{$display_path}ui/css/jquery.fancybox.css?v=2.1.5" type="text/css" media="screen"/>
				<script type="text/javascript" src="{$display_path}ui/javascript/jquery.fancybox.pack.js?v=2.1.5"/>
				<script type="text/javascript" src="{$display_path}ui/javascript/get_functions.js"/>
				<!-- local styling -->
				<link rel="stylesheet" href="{$display_path}ui/css/style.css"/>
			</head>
			<body>
				<xsl:call-template name="header"/>
				<xsl:call-template name="body"/>
				<xsl:call-template name="footer"/>
			</body>
		</html>
	</xsl:template>

	<xsl:template name="body">
		<div class="container-fluid content">
			<div class="row">
				<div class="col-md-12">
					<xsl:choose>
						<xsl:when test="count(descendant::res:result) = 0">
							<p>There are no objects associated with this ARK.</p>
						</xsl:when>
						<xsl:otherwise>
							<!-- use the ark URI to get the EAD/XML in response with the xsl document() function, apply template on archdesc/did -->
							<xsl:apply-templates select="$did//*[local-name()='did']"/>
							
							<h3>Associated Cultural Heritage Objects</h3>
							
							<!-- display the pagination toolbar only if there are multiple pages -->
							<xsl:if test="$numFound &gt; 100">
								<xsl:call-template name="pagination"/>
							</xsl:if>							
							
							<!-- call template for results -->
							<xsl:apply-templates select="descendant::res:result"/>
						</xsl:otherwise>
					</xsl:choose>
				</div>
			</div>
		</div>
	</xsl:template>

	<!-- styling for an individual result -->
	<xsl:template match="res:result">
		<div class="col-lg-2 col-md-3 col-sm-6">
			<div class="cho-container text-center">
				<xsl:choose>
					<xsl:when test="res:binding[@name='thumbnail'] and res:binding[@name='depiction']">
						<a href="{res:binding[@name='depiction']}" class="thumbImage" title="{res:binding[@name='title']/res:literal}">
							<img src="{res:binding[@name='thumbnail']/res:uri}" alt="thumbnail" class="cho-thumb"/>
						</a>
						<br/>
					</xsl:when>
					<xsl:when test="res:binding[@name='thumbnail'] and not(res:binding[@name='depiction'])">
						<img src="{res:binding[@name='thumbnail']/res:uri}" alt="thumbnail" class="cho-thumb"/>
						<br/>
					</xsl:when>
				</xsl:choose>
				<a href="{res:binding[@name='cho']/res:uri}" target="_blank" title="{res:binding[@name='title']/res:literal}">
					<xsl:value-of select="if (string-length(res:binding[@name='title']/res:literal) &gt; 50) then concat(substring(res:binding[@name='title']/res:literal, 1, 50), '...') else
						res:binding[@name='title']/res:literal"/>
				</a>
			</div>
		</div>
	</xsl:template>

	<!-- templates for processing the archdesc/did in the EAD file into the collection overview metadata -->
	<xsl:template match="*:did">
		<h2>Overview of Collection</h2>
		<h3>
			<a href="{concat($url, $ark)}">
				<xsl:value-of select="*:unittitle"/>
			</a>
		</h3>
		<dl class="dl-horizontal">
			<dt>Creator:</dt>
			<dd>
				<xsl:value-of select="*:origination"/>
			</dd>
			<xsl:if test="*:unitdate">
				<dt>Dates:</dt>
				<dd>
					<xsl:value-of select="*:unitdate"/>
				</dd>
			</xsl:if>
			<xsl:if test="*:physdesc/*:extent">
				<dt>Quantity:</dt>
				<dd>
					<xsl:value-of select="*:physdesc/*:extent"/>
				</dd>
			</xsl:if>
			<xsl:if test="*:unitid">
				<dt>Collection Number:</dt>
				<dd>
					<xsl:value-of select="*:unitid"/>
				</dd>
			</xsl:if>
			<xsl:if test="*:abstract">
				<dt>Summary:</dt>
				<dd>
					<xsl:value-of select="*:abstract"/>
				</dd>
			</xsl:if>
			<dt>Repository:</dt>
			<dd>
				<a href="{$repositoryUri}">
					<xsl:value-of select="$repositoryLabel"/>
				</a>
			</dd>
			<xsl:if test="*:langmaterial">
				<dt>Languages:</dt>
				<dd>
					<xsl:value-of select="*:langmaterial"/>
				</dd>
			</xsl:if>
			<xsl:if test="*:sponsor">
				<dt>Sponsor:</dt>
				<dd>
					<xsl:value-of select="*:sponsor"/>
				</dd>
			</xsl:if>
		</dl>
	</xsl:template>

	<!-- pagination template -->
	<xsl:template name="pagination">
		<xsl:variable name="previous" select="$page - 1"/>
		<xsl:variable name="current" select="$page"/>
		<xsl:variable name="next" select="$page + 1"/>
		<xsl:variable name="total" select="ceiling($numFound div $limit)"/>

		<div class="row">
			<div class="col-md-6">
				<xsl:variable name="startRecord" select="$offset + 1"/>
				<xsl:variable name="endRecord">
					<xsl:choose>
						<xsl:when test="$numFound &gt; ($offset + $limit)">
							<xsl:value-of select="$offset + $limit"/>
						</xsl:when>
						<xsl:otherwise>
							<xsl:value-of select="$numFound"/>
						</xsl:otherwise>
					</xsl:choose>
				</xsl:variable>
				<p>Records <b><xsl:value-of select="$startRecord"/></b> to <b><xsl:value-of select="$endRecord"/></b> of <b><xsl:value-of select="$numFound"/></b></p>
			</div>
			<!-- paging functionality -->
			<div class="col-md-6">
				<div class="btn-toolbar" role="toolbar">
					<div class="btn-group pull-right">
						<xsl:choose>
							<xsl:when test="$offset &gt;= $limit">
								<a class="btn btn-default pagingBtn" role="button" title="First" href="?ark={$ark}">
									<span class="glyphicon glyphicon-fast-backward"/>
								</a>
								<a class="btn btn-default pagingBtn" role="button" title="Previous" href="?ark={$ark}&amp;page={$previous}">
									<span class="glyphicon glyphicon-backward"/>
								</a>
							</xsl:when>
							<xsl:otherwise>
								<a class="btn btn-default disabled" role="button" title="First" href="?ark={$ark}">
									<span class="glyphicon glyphicon-fast-backward"/>
								</a>
								<a class="btn btn-default disabled" role="button" title="Previous" href="?ark={$ark}&amp;page={$previous}">
									<span class="glyphicon glyphicon-backward"/>
								</a>
							</xsl:otherwise>
						</xsl:choose>
						<!-- current page -->
						<button type="button" class="btn btn-default active">
							<b>
								<xsl:value-of select="$current"/>
							</b>
						</button>
						<!-- next page -->
						<xsl:choose>
							<xsl:when test="$numFound - $offset &gt; $limit">
								<a class="btn btn-default pagingBtn" role="button" title="Next" href="?ark={$ark}&amp;page={$next}">
									<span class="glyphicon glyphicon-forward"/>
								</a>
								<a class="btn btn-default pagingBtn" role="button" href="?ark={$ark}&amp;page={$total}">
									<span class="glyphicon glyphicon-fast-forward"/>
								</a>
							</xsl:when>
							<xsl:otherwise>
								<a class="btn btn-default disabled" role="button" title="Next" href="?ark={$ark}&amp;page={$next}">
									<span class="glyphicon glyphicon-forward"/>
								</a>
								<a class="btn btn-default disabled" role="button" href="?ark={$ark}&amp;page={$total}">
									<span class="glyphicon glyphicon-fast-forward"/>
								</a>
							</xsl:otherwise>
						</xsl:choose>
					</div>
				</div>
			</div>
		</div>
	</xsl:template>

</xsl:stylesheet>
