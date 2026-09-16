<%@ page import="com.fasterxml.jackson.databind.JsonNode" %>
<%@ include file="/WEB-INF/header.jspf" %>
<h1>Stock</h1>
<p class="muted">Read-only. inventory-service has no restock/admin write endpoint, so there is no
adjustment form here — see the README.</p>

<form class="lookup" method="get" action="<%= request.getContextPath() %>/stock">
  SKU: <input type="text" name="sku" placeholder="e.g. INV-AMA-01" />
  <input type="submit" value="Look up" />
</form>

<% String error = (String) request.getAttribute("error");
   if (error != null) { %>
  <div class="error"><%= error %></div>
<% } %>

<% JsonNode stock = (JsonNode) request.getAttribute("stock");
   if (stock != null) { %>
  <h2><%= stock.path("sku").asText() %> — <%= stock.path("totalAvailable").asInt() %> available</h2>
  <table>
    <tr><th>Tank</th><th>Status</th><th>On hand</th><th>Held</th><th>Available</th><th>Note</th></tr>
    <% for (JsonNode tank : stock.path("tanks")) { %>
    <tr>
      <td><%= tank.path("tank").asText() %></td>
      <td><%= tank.path("status").asText() %></td>
      <td><%= tank.path("onHand").asInt() %></td>
      <td><%= tank.path("held").asInt() %></td>
      <td><%= tank.path("available").asInt() %></td>
      <td><%= tank.path("note").asText("") %></td>
    </tr>
    <% } %>
  </table>
<% } %>
<%@ include file="/WEB-INF/footer.jspf" %>
