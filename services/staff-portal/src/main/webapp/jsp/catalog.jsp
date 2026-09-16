<%@ page import="com.fasterxml.jackson.databind.JsonNode" %>
<%@ include file="/WEB-INF/header.jspf" %>
<h1>Catalog</h1>
<p class="muted">Browse only. catalog-service has no write endpoint, so species content cannot be
edited from here — see the README.</p>

<% String error = (String) request.getAttribute("error");
   if (error != null) { %>
  <div class="error"><%= error %></div>
<% } %>

<% JsonNode roots = (JsonNode) request.getAttribute("roots");
   if (roots != null) { %>
  <h2>Top-level categories</h2>
  <table>
    <tr><th>Name</th><th>Status</th><th>Products (subtree)</th></tr>
    <% for (JsonNode c : roots) { %>
    <tr>
      <td><a href="<%= request.getContextPath() %>/catalog?slug=<%= c.path("slug").asText() %>"><%= c.path("name").asText() %></a></td>
      <td><%= c.path("status").asText() %></td>
      <td><%= c.path("totalProducts").asLong() %></td>
    </tr>
    <% } %>
  </table>
<% } %>

<% JsonNode category = (JsonNode) request.getAttribute("category");
   if (category != null) {
     JsonNode self = category.path("category");
     JsonNode breadcrumb = category.path("breadcrumb");
     JsonNode children = category.path("children");
     JsonNode products = category.path("products"); %>
  <p>
    <a href="<%= request.getContextPath() %>/catalog">Catalog</a>
    <% for (JsonNode b : breadcrumb) { %> &raquo; <a href="<%= request.getContextPath() %>/catalog?slug=<%= b.path("slug").asText() %>"><%= b.path("name").asText() %></a><% } %>
  </p>
  <h2><%= self.path("name").asText() %></h2>
  <p><%= self.path("description").asText("") %></p>

  <% if (children.size() > 0) { %>
  <h3>Subcategories</h3>
  <table>
    <tr><th>Name</th><th>Status</th><th>Products (subtree)</th></tr>
    <% for (JsonNode c : children) { %>
    <tr>
      <td><a href="<%= request.getContextPath() %>/catalog?slug=<%= c.path("slug").asText() %>"><%= c.path("name").asText() %></a></td>
      <td><%= c.path("status").asText() %></td>
      <td><%= c.path("totalProducts").asLong() %></td>
    </tr>
    <% } %>
  </table>
  <% } %>

  <% if (products.size() > 0) { %>
  <h3>Products at this level</h3>
  <table>
    <tr><th>SKU</th><th>Name</th><th>Price</th><th>Livestock</th></tr>
    <% for (JsonNode p : products) { %>
    <tr>
      <td><a href="<%= request.getContextPath() %>/catalog?product=<%= p.path("slug").asText() %>"><%= p.path("sku").asText() %></a></td>
      <td><%= p.path("name").asText() %></td>
      <td><%= p.path("price").asText() %> <%= p.path("currency").asText() %></td>
      <td><%= p.path("livestock").asBoolean() %></td>
    </tr>
    <% } %>
  </table>
  <% } %>
<% } %>

<% JsonNode product = (JsonNode) request.getAttribute("product");
   if (product != null) {
     JsonNode summary = product.path("summary");
     JsonNode species = product.path("speciesProfile"); %>
  <h2><%= summary.path("name").asText() %> <span class="muted">(<%= summary.path("sku").asText() %>)</span></h2>
  <p><%= summary.path("summary").asText("") %></p>
  <table>
    <tr><th>Price</th><td><%= summary.path("price").asText() %> <%= summary.path("currency").asText() %></td></tr>
    <tr><th>Livestock</th><td><%= summary.path("livestock").asBoolean() %></td></tr>
  </table>
  <% if (!species.isMissingNode() && !species.isNull()) { %>
  <h3>Care profile</h3>
  <table>
    <% java.util.Iterator<String> fields = species.fieldNames();
       while (fields.hasNext()) { String f = fields.next(); %>
    <tr><th><%= f %></th><td><%= species.path(f).asText() %></td></tr>
    <% } %>
  </table>
  <% } %>
<% } %>
<%@ include file="/WEB-INF/footer.jspf" %>
