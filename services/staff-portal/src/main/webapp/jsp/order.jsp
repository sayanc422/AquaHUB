<%@ page import="com.fasterxml.jackson.databind.JsonNode" %>
<%@ include file="/WEB-INF/header.jspf" %>
<h1>Orders</h1>
<p class="muted">Lookup only — order-service has no endpoint that lists every order, only get-by-id
and get-by-reference. A staff member needs the reference a customer gives them.</p>

<form class="lookup" method="get" action="<%= request.getContextPath() %>/orders">
  Reference: <input type="text" name="reference" placeholder="e.g. ORD-..." />
  &nbsp;or id: <input type="text" name="id" placeholder="UUID" />
  <input type="submit" value="Look up" />
</form>

<% String error = (String) request.getAttribute("error");
   if (error != null) { %>
  <div class="error"><%= error %></div>
<% } %>

<% JsonNode order = (JsonNode) request.getAttribute("order");
   if (order != null) { %>
  <h2><%= order.path("reference").asText() %></h2>
  <table>
    <tr><th>State</th><td><%= order.path("state").asText() %></td></tr>
    <tr><th>Email</th><td><%= order.path("email").asText() %></td></tr>
    <tr><th>Total</th><td><%= order.path("totalMinor").asLong() %> <%= order.path("currency").asText() %> (minor units)</td></tr>
    <tr><th>Payment ref</th><td><%= order.path("paymentRef").isNull() ? "-" : order.path("paymentRef").asText() %></td></tr>
    <tr><th>Dispatch at</th><td><%= order.path("dispatchAt").isNull() ? "-" : order.path("dispatchAt").asText() %></td></tr>
    <tr><th>Dispatchable now</th><td><%= order.path("dispatchable").asBoolean() %> <span class="muted">(derived from the clock, not stored)</span></td></tr>
    <tr><th>Failure reason</th><td><%= order.path("failureReason").isNull() ? "-" : order.path("failureReason").asText() %></td></tr>
  </table>

  <h3>Lines</h3>
  <table>
    <tr><th>SKU</th><th>Name</th><th>Qty</th><th>Unit price (minor)</th><th>Livestock</th></tr>
    <% for (JsonNode line : order.path("lines")) { %>
    <tr>
      <td><%= line.path("sku").asText() %></td>
      <td><%= line.path("name").asText() %></td>
      <td><%= line.path("quantity").asInt() %></td>
      <td><%= line.path("unitPriceMinor").asLong() %></td>
      <td><%= line.path("livestock").asBoolean() %></td>
    </tr>
    <% } %>
  </table>

  <h3>Event trail</h3>
  <table>
    <tr><th>At</th><th>From</th><th>To</th><th>Detail</th></tr>
    <% JsonNode events = (JsonNode) request.getAttribute("events");
       if (events != null) { for (JsonNode ev : events) { %>
    <tr>
      <td><%= ev.path("at").asText() %></td>
      <td><%= ev.path("from").isNull() ? "-" : ev.path("from").asText() %></td>
      <td><%= ev.path("to").asText() %></td>
      <td><%= ev.path("detail").asText() %></td>
    </tr>
    <% } } %>
  </table>
<% } %>
<%@ include file="/WEB-INF/footer.jspf" %>
