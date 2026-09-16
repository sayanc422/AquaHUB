<%@ include file="/WEB-INF/header.jspf" %>
<h1>AquaShop Staff Portal</h1>
<p>Internal back-office. Read-only in this version — see the
<a href="https://github.com/sayanc422/AquaHUB/blob/main/services/staff-portal/README.md">README</a>
for what that means and why.</p>
<ul>
  <li><a href="<%= request.getContextPath() %>/orders">Orders</a> — look up an order by reference or id.</li>
  <li><a href="<%= request.getContextPath() %>/stock">Stock</a> — tank-by-tank availability for a SKU.</li>
  <li><a href="<%= request.getContextPath() %>/catalog">Catalog</a> — browse categories and species.</li>
</ul>
<%@ include file="/WEB-INF/footer.jspf" %>
