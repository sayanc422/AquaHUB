#!/usr/bin/env python3
"""Generates the AquaShop diagram set as SVG (four diagrams).

The diagrams are generated rather than hand-drawn so that coordinates stay
consistent and a change to the palette or spacing is one edit, not thirty.
Output is plain SVG committed to the repo, so diagrams show up in diffs.
"""
from pathlib import Path
from html import escape

OUT = Path(__file__).parent

BG      = "#0f1725"
PANEL   = "#182032"
PANEL2  = "#1d2740"
LINE    = "#2b3654"
INK     = "#e6ecf5"
MUTED   = "#93a1bd"
TEAL    = "#3ddc97"
ORANGE  = "#ff9a4d"
VIOLET  = "#8b7bf7"
PINK    = "#f0546a"
BLUE    = "#4cc9f0"
DIM     = "#55617d"

MONO = "DejaVu Sans Mono, ui-monospace, monospace"
SANS = "DejaVu Sans, Segoe UI, sans-serif"


def head(w, h, title):
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}"
     viewBox="0 0 {w} {h}" font-family="{SANS}" role="img" aria-label="{escape(title)}">
<defs>
  <marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7"
          orient="auto-start-end"><path d="M0,0 L10,5 L0,10 z" fill="{MUTED}"/></marker>
  <marker id="arrowT" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7"
          orient="auto-start-end"><path d="M0,0 L10,5 L0,10 z" fill="{TEAL}"/></marker>
  <marker id="arrowO" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7"
          orient="auto-start-end"><path d="M0,0 L10,5 L0,10 z" fill="{ORANGE}"/></marker>
</defs>
<rect width="{w}" height="{h}" fill="{BG}"/>
"""


def title_bar(text, sub, accent_word=None, x=48, y=76):
    parts = [f'<rect x="{x}" y="{y-42}" width="7" height="46" fill="{TEAL}"/>']
    if accent_word and accent_word in text:
        before, after = text.split(accent_word, 1)
        parts.append(
            f'<text x="{x+22}" y="{y}" font-size="36" font-weight="700" fill="{INK}">'
            f'{escape(before)}<tspan fill="{TEAL}">{escape(accent_word)}</tspan>{escape(after)}</text>')
    else:
        parts.append(f'<text x="{x+22}" y="{y}" font-size="36" font-weight="700" fill="{INK}">{escape(text)}</text>')
    parts.append(f'<text x="{x+24}" y="{y+26}" font-size="14" fill="{MUTED}">{escape(sub)}</text>')
    return "".join(parts)


def panel(x, y, w, h, label=None, accent=LINE, fill=PANEL, r=12, label_color=None):
    s = (f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{fill}" '
         f'stroke="{accent}" stroke-width="1.5"/>')
    if label:
        s += (f'<text x="{x+18}" y="{y+26}" font-size="13" font-weight="700" letter-spacing="1.4" '
              f'fill="{label_color or MUTED}">{escape(label.upper())}</text>')
    return s


def box(x, y, w, h, title, sub=None, note=None, accent=LINE, title_color=None,
        fill=PANEL2, dashed=False, badge=None, badge_color=None):
    dash = ' stroke-dasharray="5 4"' if dashed else ''
    s = (f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="9" fill="{fill}" '
         f'stroke="{accent}" stroke-width="1.5"{dash}/>')
    ty = y + (24 if sub or note else h / 2 + 5)
    s += (f'<text x="{x+14}" y="{ty}" font-size="14.5" font-weight="700" '
          f'fill="{title_color or INK}">{escape(title)}</text>')
    if sub:
        s += f'<text x="{x+14}" y="{ty+19}" font-size="12" font-family="{MONO}" fill="{MUTED}">{escape(sub)}</text>'
    if note:
        s += f'<text x="{x+14}" y="{ty+(38 if sub else 19)}" font-size="11.5" fill="{DIM}">{escape(note)}</text>'
    if badge:
        bw = 8 * len(badge) + 16
        s += (f'<rect x="{x+w-bw-12}" y="{y+11}" width="{bw}" height="19" rx="9.5" '
              f'fill="none" stroke="{badge_color or ORANGE}" stroke-width="1.2"/>'
              f'<text x="{x+w-bw/2-12}" y="{y+24.5}" font-size="10" letter-spacing="0.9" '
              f'text-anchor="middle" fill="{badge_color or ORANGE}">{escape(badge)}</text>')
    return s


def text(x, y, s, size=12, fill=MUTED, weight="400", anchor="start", mono=False, italic=False):
    fam = f' font-family="{MONO}"' if mono else ''
    it = ' font-style="italic"' if italic else ''
    return (f'<text x="{x}" y="{y}" font-size="{size}" fill="{fill}" font-weight="{weight}" '
            f'text-anchor="{anchor}"{fam}{it}>{escape(s)}</text>')


def arrow(x1, y1, x2, y2, color=MUTED, marker="arrow", dashed=False, width=1.6):
    dash = ' stroke-dasharray="6 5"' if dashed else ''
    return (f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{color}" '
            f'stroke-width="{width}"{dash} marker-end="url(#{marker})"/>')


def elbow(x1, y1, x2, y2, color=MUTED, marker="arrow", dashed=False):
    """Orthogonal connector: down from source, across, into target."""
    mid = (y1 + y2) / 2
    dash = ' stroke-dasharray="6 5"' if dashed else ''
    return (f'<path d="M{x1},{y1} L{x1},{mid} L{x2},{mid} L{x2},{y2}" fill="none" '
            f'stroke="{color}" stroke-width="1.6"{dash} marker-end="url(#{marker})"/>')


def pill(x, y, label, color=TEAL, size=11):
    w = 7.2 * len(label) + 22
    return (f'<rect x="{x}" y="{y}" width="{w}" height="22" rx="11" fill="{color}" opacity="0.14"/>'
            f'<rect x="{x}" y="{y}" width="{w}" height="22" rx="11" fill="none" stroke="{color}" opacity="0.55"/>'
            f'<text x="{x+w/2}" y="{y+15}" font-size="{size}" text-anchor="middle" fill="{color}" '
            f'font-weight="600">{escape(label)}</text>'), w


def footer(w, y, left, right):
    return (f'<line x1="48" y1="{y}" x2="{w-48}" y2="{y}" stroke="{LINE}"/>'
            + text(48, y + 26, left, 12, MUTED)
            + text(w - 48, y + 26, right, 11, DIM, anchor="end"))


def legend(x, y, items):
    s = ""
    cx = x
    for label, color in items:
        p, pw = pill(cx, y, label, color)
        s += p
        cx += pw + 10
    return s


# ---------------------------------------------------------------- diagram 1 --
def architecture():
    W, H = 1480, 1120
    s = head(W, H, "AquaShop system architecture")
    s += title_bar("AquaShop System Architecture", "All eight services are built and run together in k3d. Messaging, observability and GitOps remain planned.",
                   "System")
    s += legend(1000, 44, [("BUILT, RUNS IN k3d", TEAL), ("PLANNED", DIM)])

    # --- edge panel
    s += panel(48, 120, 880, 250, "Edge and client", BLUE)
    s += box(72, 158, 220, 74, "Browser", "https://aquashop.localtest.me",
             "TLS to ingress, self-signed CA", TEAL, TEAL)
    s += box(336, 158, 250, 74, "ingress-nginx", "IngressClass: nginx",
             "hostPort 80/443 on the k3d node", TEAL, TEAL)
    s += box(630, 158, 274, 74, "cert-manager", "ClusterIssuer: aquashop-ca-issuer",
             "issues the in-cluster leaf certificate", TEAL, TEAL)
    s += arrow(292, 195, 330, 195, TEAL, "arrowT")
    s += arrow(586, 195, 624, 195, MUTED, "arrow", dashed=True)
    s += text(340, 268, "AWS counterpart: Route 53 -> ACM -> ALB (AWS Load Balancer Controller).",
              12.5, MUTED)
    s += text(340, 290, "What differs locally: TLS terminates inside the cluster at ingress-nginx, not at the load balancer,",
              12, DIM)
    s += text(340, 310, "so ALB listener rules, target-group health checks and WAF association are unvalidated.", 12, DIM)
    s += text(340, 340, "Everything below runs in one k3d node container inside WSL2.", 12, DIM, italic=True)

    # --- cross-cutting panel (right)
    s += panel(956, 120, 476, 250, "Cross-cutting", VIOLET)
    s += box(980, 158, 200, 60, "Observability", "OTel -> Prometheus", accent=DIM, title_color=MUTED, dashed=True)
    s += box(1196, 158, 212, 60, "GitOps", "Argo CD app-of-apps", accent=DIM, title_color=MUTED, dashed=True)
    s += box(980, 232, 200, 60, "CI", "GH Actions per service", accent=DIM, title_color=MUTED, dashed=True)
    s += box(1196, 232, 212, 60, "Infrastructure", "Terraform, never applied", accent=ORANGE, title_color=ORANGE)
    s += text(980, 322, "The Terraform layer is validated with `terraform test`", 12, MUTED, mono=False)
    s += text(980, 342, "and mock providers. It has never been applied to an account.", 12, ORANGE)

    # --- BFF
    s += panel(48, 400, 1384, 128, "Backend for frontend", TEAL)
    s += box(72, 438, 320, 72, "storefront", "TypeScript / Fastify",
             "SSR HTML, br/gzip, bounded upstream calls", TEAL, TEAL, badge="BUILT", badge_color=TEAL)
    s += text(420, 458, "Calls three services: catalog (every page), order (enquiry form), advisor (tank checker).", 12.5, MUTED)
    s += text(420, 480, "Owns no data; a 60s in-memory cache holds the category tree and product list.", 12, DIM)
    s += text(420, 500, "Readiness checks the catalog only: an order or advisor outage fails one feature, not the shop.", 12, DIM)
    s += arrow(182, 236, 182, 432, TEAL, "arrowT")

    # --- services
    s += panel(48, 558, 1384, 214, "Domain services — one database each, no shared schema", ORANGE)
    svc = [
        ("catalog-service", "Java 21 / Spring Boot", "products, species profiles", TEAL, False),
        ("order-service", "Java 21 / Spring Boot", "checkout saga, order state", TEAL, False),
        ("inventory-service", "Go", "tank stock, TTL holds", TEAL, False),
        ("payment-service", "Rust / Axum", "auth, capture, ledger", TEAL, False),
        ("aquatics-advisor", "Python / FastAPI", "compatibility rules", TEAL, False),
        ("notification-service", "Go", "email + webhook fan-out", TEAL, False),
        ("staff-portal", "JSP / WildFly", "read-only back-office", TEAL, False),
    ]
    # Only the three services the storefront actually calls get an arrow from
    # it. The saga in order-service calls inventory and payment and pushes to
    # notification; staff-portal is reached through its own ingress host.
    called_by_bff = {"catalog-service", "order-service", "aquatics-advisor"}
    # 172 wide with 16 between: seven boxes at the old 182 + 18 ran 22 px
    # past the panel's right edge.
    x = 72
    for name, stack, owns, color, dashed in svc:
        w = 172
        s += box(x, 596, w, 96, name.replace("-service", ""), stack, owns,
                 color, color if color == TEAL else MUTED, dashed=dashed)
        if name in called_by_bff:
            s += arrow(x + w / 2, 512, x + w / 2, 590, TEAL, "arrowT")
        x += w + 16
    s += text(190, 722, "order-service drives the checkout saga: it calls inventory (reserve, commit) and payment (authorise), "
                      "then pushes to notification.", 12, MUTED)
    s += text(190, 742, "Every language choice is justified by a property of the service. Rust holds the money state machine "
                      "because exhaustive matching is worth its slow build.", 12, DIM)

    # --- messaging
    s += panel(48, 800, 660, 118, "Asynchronous", VIOLET)
    s += box(72, 838, 612, 62, "NATS JetStream", "subjects: order.*, inventory.*, payment.*",
             accent=DIM, title_color=MUTED, dashed=True)
    s += text(72, 946, "Chosen over Kafka: no consumer needs log replay or partition ordering, and Kafka costs ~1 GB",
              11.5, DIM)
    s += text(72, 964, "that this machine does not have. AWS counterpart: Amazon MQ / MSK (mapping documented).", 11.5, DIM)

    # --- data
    s += panel(736, 800, 696, 118, "Data — shared instance, isolated databases", BLUE)
    s += box(760, 838, 648, 62, "PostgreSQL 16 (StatefulSet, local-path PVC)",
             "catalog | orders | inventory | payments | notify  (advisor owns none)", accent=BLUE, title_color=BLUE)
    s += text(760, 946, "One database and one login role per service; each role has CONNECT on its own database only.", 11.5, MUTED)
    s += text(760, 964, "Faithful: credential isolation, no cross-service joins. NOT faithful: blast radius — one restart", 11.5, ORANGE)
    s += text(760, 982, "takes every service down, which per-service RDS instances in the target design would not.", 11.5, ORANGE)

    s += (f'<path d="M158,700 L158,792 L900,792 L900,830" fill="none" stroke="{TEAL}" '
          f'stroke-width="1.6" marker-end="url(#arrowT)"/>')
    s += text(560, 784, "JDBC / Hikari, pool max 10", 10.5, TEAL, mono=True)

    s += footer(W, 1040,
                "Designed for AWS  •  validated with terraform test and mock providers  •  run on k3d  •  never applied",
                "AquaShop  /  docs/diagrams/architecture.svg")
    s += "</svg>"
    (OUT / "architecture.svg").write_text(s, encoding="utf-8")


# ---------------------------------------------------------------- diagram 2 --
def deployment():
    W, H = 1480, 1260
    s = head(W, H, "AquaShop deployment topology")
    s += title_bar("Deployment Topology", "What actually runs, beside what it is designed to become.", "Deployment")
    s += legend(1010, 44, [("RUNS LOCALLY", TEAL), ("VALIDATED, NOT APPLIED", ORANGE)])

    # ---- left: local
    s += panel(48, 120, 760, 980, "Actually running — Windows 11 / WSL2 / 16 GB", TEAL)
    s += box(72, 158, 712, 56, "Windows 11 host", "16 GB total, ~4-5 GB reserved for Windows",
             accent=LINE, title_color=MUTED)
    s += box(88, 230, 680, 56, "WSL2 (Ubuntu)", "~11 GB usable via .wslconfig (was 7.4 GB unconfigured; applied by 22 Sep 2026)",
             accent=LINE, title_color=MUTED)
    s += box(104, 302, 648, 56, "Docker Engine (native in WSL, not Docker Desktop)", "one container per k3d node",
             accent=LINE, title_color=MUTED)
    s += box(120, 374, 616, 706, "k3d node container — k3s v1.30", "traefik, servicelb: disabled | metrics-server: via Helm (--metrics)",
             accent=TEAL, title_color=TEAL, fill=PANEL)

    s += text(144, 446, "NAMESPACE  ingress-nginx", 11.5, MUTED, weight="700", mono=True)
    s += box(144, 458, 568, 50, "ingress-nginx controller", "hostPort 80/443 -> 127.0.0.1", accent=LINE, title_color=INK)
    s += text(144, 542, "NAMESPACE  cert-manager", 11.5, MUTED, weight="700", mono=True)
    s += box(144, 554, 568, 50, "cert-manager + CA issuer", "self-signed root, in-cluster leaf", accent=LINE, title_color=INK)
    s += text(144, 638, "NAMESPACE  aquashop-dev   (ResourceQuota 3Gi / 4Gi) — full-app: all eight run", 11.5, MUTED, weight="700", mono=True)
    # kubectl top pods, 30 Sep 2026, full-app settled for ~26 h.
    s += box(144, 650, 180, 70, "storefront", "Node, 45 MiB", accent=TEAL, title_color=TEAL)
    s += box(338, 650, 180, 70, "catalog-service", "JVM, 217 MiB", accent=TEAL, title_color=TEAL)
    s += box(532, 650, 180, 70, "order-service", "JVM, 227 MiB", accent=TEAL, title_color=TEAL)
    s += box(144, 734, 180, 70, "inventory-service", "Go, 5 MiB", accent=TEAL, title_color=TEAL)
    s += box(338, 734, 180, 70, "payment-service", "Rust, 1 MiB", accent=TEAL, title_color=TEAL)
    s += box(532, 734, 180, 70, "aquatics-advisor", "Python, 49 MiB", accent=TEAL, title_color=TEAL)
    s += box(144, 818, 180, 70, "notification-service", "Go, 4 MiB", accent=TEAL, title_color=TEAL)
    s += box(338, 818, 374, 70, "staff-portal", "WildFly, 381 MiB  (own ingress host: staff.*)", accent=TEAL, title_color=TEAL)
    s += box(144, 902, 568, 70, "postgres (StatefulSet, PVC on local-path)",
             "61 MiB, 95 MB on disk — catalog, orders, inventory, payments, notify", accent=BLUE, title_color=BLUE)
    s += text(144, 1008, "No uat or prod overlay exists yet; Argo CD (the platform profile) has no manifests.", 11.5, ORANGE)
    s += text(144, 1028, "One environment is materialised at a time. None has ever run concurrently with another.", 11.5, ORANGE)

    # ---- right: AWS target
    s += panel(832, 120, 600, 980, "Target design — AWS (never applied)", ORANGE)
    s += box(856, 158, 552, 52, "Route 53  ->  ACM  ->  ALB (internet-facing)",
             "public subnets, 2 AZs", accent=ORANGE, title_color=ORANGE)
    s += box(856, 226, 552, 52, "AWS Load Balancer Controller", "reads Ingress, writes target groups (IP mode)",
             accent=DIM, title_color=MUTED, dashed=True)
    s += box(856, 294, 552, 96, "EKS managed node group", "private subnets  |  VPC CNI, pod IPs from the subnet",
             "Pod IP exhaustion is subnet arithmetic, not a node limit", accent=DIM, title_color=MUTED, dashed=True)
    s += box(856, 406, 264, 76, "RDS PostgreSQL", "Multi-AZ, per service",
             accent=DIM, title_color=MUTED, dashed=True)
    s += box(1144, 406, 264, 76, "ECR", "immutable tags, scan on push",
             accent=DIM, title_color=MUTED, dashed=True)
    s += box(856, 498, 264, 76, "Secrets Manager", "read via IRSA",
             accent=DIM, title_color=MUTED, dashed=True)
    s += box(1144, 498, 264, 76, "NAT GW + VPC endpoints", "egress, private ECR pulls",
             accent=DIM, title_color=MUTED, dashed=True)

    s += box(856, 596, 552, 108, "Terraform modules", "network | eks | rds | ecr | iam",
             accent=ORANGE, title_color=ORANGE)
    s += text(872, 664, "CI: fmt -> validate -> tflint -> checkov -> terraform test", 11.5, MUTED, mono=True)
    s += text(872, 684, "No backend, no credentials, no apply. Module wiring is proven; AWS behaviour is not.", 11.5, ORANGE)

    s += text(856, 736, "Failure modes I must be able to explain without having reproduced them:", 12.5, INK, weight="700")
    for i, line in enumerate([
        "subnet discovery tags — a missing kubernetes.io/role/elb and the ALB is never created",
        "pod IP exhaustion — /24 per subnet is 251 usable IPs, shared by nodes and pods",
        "IRSA — the pod's service account token is exchanged for STS credentials",
        "Multi-AZ failover — DNS flip, connection pools must reconnect, not a zero-downtime event",
    ]):
        s += text(872, 762 + i * 22, "- " + line, 11.5, MUTED)

    s += arrow(790, 500, 826, 500, ORANGE, "arrowO", dashed=True)
    s += text(808, 478, "maps to", 10, ORANGE, anchor="middle")

    s += footer(W, 1150,
                "Measured, kubectl top node: core 1.32 GiB and core+commerce 2.05 GiB (16 Sep); full-app 2053 MiB (30 Sep 2026).",
                "AquaShop  /  docs/diagrams/deployment.svg")
    s += "</svg>"
    (OUT / "deployment.svg").write_text(s, encoding="utf-8")


# ---------------------------------------------------------------- diagram 3 --
def gitflow():
    W, H = 1480, 1000
    s = head(W, H, "AquaShop delivery flow")
    s += title_bar("Delivery Flow — Two Repositories", "Nobody runs kubectl apply. Promotion is a pull request.", "Delivery")
    s += legend(1050, 44, [("APP REPO", TEAL), ("GITOPS REPO", VIOLET)])

    # swimlane labels
    lanes = [("Developer", 176), ("aquashop (app repo)", 300), ("GitHub Actions", 470),
             ("aquashop-platform (GitOps repo)", 640), ("Cluster", 810)]
    for label, y in lanes:
        s += f'<line x1="48" y1="{y-46}" x2="{W-48}" y2="{y-46}" stroke="{LINE}" stroke-dasharray="3 6"/>'
        s += text(48, y - 54, label.upper(), 11, MUTED, weight="700")

    # developer
    s += box(60, 138, 230, 62, "feature branch", "git push", accent=TEAL, title_color=TEAL)
    s += arrow(250, 200, 250, 250, TEAL, "arrowT")

    # app repo
    s += box(60, 250, 230, 62, "Pull request", "review + required checks", accent=TEAL, title_color=TEAL)
    s += arrow(290, 281, 356, 281, TEAL, "arrowT")
    s += box(356, 250, 230, 62, "merge to main", "squash, one commit", accent=TEAL, title_color=TEAL)
    s += arrow(471, 312, 471, 420, TEAL, "arrowT")

    # CI
    ci = [("lint", 60), ("unit + IT", 196), ("coverage gate", 332), ("Trivy scan", 492),
          ("buildx", 636), ("push :<sha>", 772)]
    for label, x in ci:
        w = 122 if label != "coverage gate" else 146
        s += box(x, 420, w, 58, label, accent=LINE, title_color=INK)
        if x != 60:
            s += arrow(x - 12, 449, x - 2, 449, MUTED)
    s += text(60, 502, "Image tag is the git SHA. Never :latest — a mutable tag makes rollback a guess and makes",
              11.5, DIM)
    s += text(60, 520, "'which image is running' unanswerable from the cluster.", 11.5, DIM)

    s += box(938, 420, 200, 58, "PR to GitOps repo", accent=VIOLET, title_color=VIOLET)
    s += arrow(908, 449, 932, 449, VIOLET, "arrow")
    s += arrow(1038, 478, 1038, 590, VIOLET, "arrow")

    # gitops repo
    s += box(60, 590, 300, 74, "dev overlay", "image tag bumped automatically", accent=VIOLET, title_color=VIOLET)
    s += box(400, 590, 300, 74, "uat overlay", "promotion PR, human approval", accent=VIOLET, title_color=VIOLET)
    s += box(740, 590, 300, 74, "prod overlay", "promotion PR, human approval", accent=VIOLET, title_color=VIOLET)
    s += arrow(360, 627, 394, 627, MUTED)
    s += arrow(700, 627, 734, 627, MUTED)
    s += text(60, 692, "The GitOps commit log is the literal deployment history: every change to what runs is a commit,",
              11.5, MUTED)
    s += text(60, 710, "and a rollback is `git revert` of that commit, not a command typed against a cluster.", 11.5, MUTED)

    # cluster
    s += box(60, 760, 300, 74, "Argo CD app-of-apps", "auto-sync + self-heal on dev", accent=TEAL, title_color=TEAL)
    s += arrow(210, 664, 210, 754, VIOLET, "arrow")
    s += box(400, 760, 300, 74, "aquashop-dev namespace", "rolling update, maxUnavailable 0", accent=TEAL, title_color=TEAL)
    s += arrow(360, 797, 394, 797, TEAL, "arrowT")
    s += box(740, 760, 300, 74, "uat / prod namespaces", "replicas: 0 until materialised", accent=ORANGE, title_color=ORANGE)
    s += arrow(700, 797, 734, 797, ORANGE, "arrowO", dashed=True)

    s += panel(1080, 590, 352, 252, "Interview hooks", VIOLET)
    for i, line in enumerate([
        "Why two repos: a CI bot writing to the app",
        "repo would retrigger CI on its own commit.",
        "",
        "Drift: Argo self-heal reverts a manual",
        "kubectl edit within seconds; that is the",
        "point, and it is also how you lock yourself",
        "out of an emergency fix.",
        "",
        "Rollback: revert the tag-bump commit.",
        "Mean time to recover = sync interval.",
    ]):
        s += text(1100, 642 + i * 20, line, 11.5, MUTED if line else MUTED)

    s += footer(W, 900,
                "Definition of done for this flow: a merged pull request deploys a new version with no manual kubectl anywhere.",
                "AquaShop  /  docs/diagrams/delivery-flow.svg")
    s += "</svg>"
    (OUT / "delivery-flow.svg").write_text(s, encoding="utf-8")


# ---------------------------------------------------------------- diagram 4 --
def physical():
    """What runs where on this one machine: ports, containers, volumes, disk.

    Every value here was read off the live machine on 30 Sep 2026 (docker
    inspect, kubectl get, /proc/meminfo, df). The anonymous volume ids change
    every time the cluster is recreated, so only their mount points are drawn.
    """
    W, H = 1480, 1520
    s = head(W, H, "AquaShop physical deployment")
    s += title_bar("Physical Deployment — this machine", "Where every process, port and byte of data actually lives. Read off the live machine, 30 Sep 2026.",
                   "Physical")
    s += legend(1030, 44, [("SURVIVES --destroy", TEAL), ("LOST ON --destroy", PINK)])

    # ---- Windows
    s += panel(48, 120, 1384, 150, "Windows 11 host — 16 GB RAM", BLUE)
    s += box(72, 158, 420, 90, "Browser (Windows side)", "https://aquashop.localtest.me",
             "https://staff.aquashop.localtest.me   -> both resolve to 127.0.0.1", BLUE, BLUE)
    s += box(516, 158, 420, 90, "WSL localhost forwarding", "127.0.0.1:80 / :443  ->  WSL2 VM",
             "no /etc/hosts or Windows hosts-file edit needed", LINE, INK)
    s += box(960, 158, 448, 90, "C:\\Users\\sayan\\.wslconfig", "memory=11GB  processors=4  swap=4GB",
             "changes apply only after `wsl --shutdown` (PowerShell)", LINE, INK)
    s += arrow(492, 203, 510, 203, BLUE, "arrow")

    # ---- WSL2
    s += panel(48, 290, 1384, 1130, "WSL2 VM — Ubuntu, 11 GiB RAM, 4 vCPU, 4 GiB swap, ext4 1007 GB (44 GB used)", TEAL)

    # left column: the Linux side
    lx, lw = 72, 360
    rows = [
        ("systemd=true (/etc/wsl.conf)", "docker.service enabled", "Docker starts when WSL starts", LINE, INK),
        ("Repository", "~/Config-Scripts/Repo/AquaHUB", "branch claude/clever-shannon-ivtkw6", TEAL, TEAL),
        ("kubeconfig", "~/.kube/config", "context k3d-aquashop -> 0.0.0.0:37127", LINE, INK),
        ("CLI tools", "docker 29.8 k3d 5.9 kubectl 1.37", "helm 3.22, python3 (diagrams)", LINE, INK),
        ("Build-cache volumes (named)", "aquashop-m2  aquashop-npm", "aquashop-maven-repo  maven-repo-cache", TEAL, TEAL),
        ("Tool images", "playwright:v1.48.0-jammy", "PDF + screenshots; maven:3.9 for tests", TEAL, TEAL),
        ("Service images (host copy)", "aquashop/<service>:dev", "built by bootstrap.sh, then imported", TEAL, TEAL),
    ]
    y = 332
    for t, sub, note, acc, tc in rows:
        s += box(lx, y, lw, 84, t, sub, note, acc, tc)
        y += 98
    s += text(lx, y + 14, "No native node, JDK or cargo: every build", 11.5, DIM)
    s += text(lx, y + 32, "and test runs inside a container.", 11.5, DIM)

    # right: Docker engine
    dx, dw = 456, 952
    s += panel(dx, 332, dw, 1068, "Docker Engine — /var/lib/docker — bridge network k3d-aquashop", VIOLET)
    s += box(dx + 24, 366, dw - 48, 74, "container  k3d-aquashop-serverlb", "ghcr.io/k3d-io/k3d-proxy:5.9.0",
             "host 0.0.0.0:37127 -> 6443: the Kubernetes API that kubectl talks to", LINE, INK)

    nx, nw = dx + 24, dw - 48
    s += box(nx, 452, nw, 926, "container  k3d-aquashop-server-0", "rancher/k3s:v1.30.4-k3s1  172.18.0.3  restart: unless-stopped",
             "host 0.0.0.0:80 and :443 -> ingress-nginx hostPort. The whole cluster is this one container.",
             TEAL, TEAL, fill=PANEL)

    ix = nx + 20
    iw = nw - 40
    s += text(ix, 538, "NAMESPACE  ingress-nginx", 11.5, MUTED, weight="700", mono=True)
    s += box(ix, 548, iw, 58, "ingress-nginx-controller  :80 :443", "aquashop.localtest.me /  -> storefront:3000    /api -> catalog-service:8080",
             None, LINE, INK)
    s += text(ix + 14, 622, "staff.aquashop.localtest.me /  -> staff-portal:8080    TLS: Secret aquashop-tls (cert-manager, self-signed CA)",
              11, DIM, mono=True)

    s += text(ix, 656, "NAMESPACES  cert-manager  kube-system", 11.5, MUTED, weight="700", mono=True)
    s += box(ix, 666, iw, 44, "cert-manager (3 pods)   coredns   local-path-provisioner   metrics-server", accent=LINE, title_color=MUTED)

    s += text(ix, 740, "NAMESPACE  aquashop-dev   (Service port shown; all ClusterIP, none reachable from Windows directly)",
              11.5, MUTED, weight="700", mono=True)
    svcs = [("storefront", ":3000"), ("catalog-service", ":8080"), ("order-service", ":8082"),
            ("inventory-service", ":8081"), ("payment-service", ":8083"), ("aquatics-advisor", ":8084"),
            ("notification-service", ":8085"), ("staff-portal", ":8080")]
    bw, gap = (iw - 3 * 12) / 4, 12
    for i, (n, port) in enumerate(svcs):
        bx = ix + (i % 4) * (bw + gap)
        by = 752 + (i // 4) * 60
        s += box(bx, by, bw, 50, n, port, accent=TEAL, title_color=TEAL)
    s += box(ix, 876, iw, 50, "postgres-0  :5432 (headless)", "postgres:16-alpine   databases: catalog orders inventory payments notify",
             accent=BLUE, title_color=BLUE)
    s += box(ix, 936, iw, 44, "Secrets: postgres-credentials, aquashop-tls, order-inquiry-key (made by hand, in no file)",
             accent=PINK, title_color=PINK)

    s += text(ix, 1012, "INSIDE THE NODE CONTAINER'S FILESYSTEM", 11.5, MUTED, weight="700")
    vols = [
        ("/var/lib/rancher/k3s", "anonymous volume",
         "k3s datastore (every object, every Secret) + storage/pvc-..._data-postgres-0 = Postgres, 95 MB", PINK),
        ("/var/lib/kubelet  /var/lib/cni  /var/log", "anonymous volumes", "pod sandboxes, CNI state, container logs", PINK),
        ("containerd image store", "inside the node", "8 aquashop/*:dev images, 5 MB (Go) to 476 MB (WildFly)", PINK),
        ("/k3d/images", "named volume k3d-aquashop-images", "staging area for `k3d image import`", DIM),
    ]
    vy = 1024
    for path, kind, what, col in vols:
        s += (f'<rect x="{ix}" y="{vy}" width="{iw}" height="44" rx="7" fill="{PANEL2}" stroke="{col}" stroke-width="1.3"/>')
        s += text(ix + 14, vy + 19, path, 12, col if col != DIM else MUTED, weight="700", mono=True)
        s += text(ix + 14, vy + 36, kind + "  —  " + what, 11, MUTED)
        vy += 54

    s += (f'<rect x="{ix}" y="{vy + 6}" width="{iw}" height="104" rx="9" fill="{PINK}" fill-opacity="0.10" '
          f'stroke="{PINK}" stroke-width="1.5"/>')
    s += text(ix + 16, vy + 32, "k3d cluster delete  (= bootstrap.sh --destroy)  deletes the database.", 14, PINK, weight="700")
    s += text(ix + 16, vy + 54, "It removes server-0 and its anonymous volumes: verified 30 Sep 2026 on a throwaway cluster. Orders,", 11.5, INK)
    s += text(ix + 16, vy + 72, "enquiries, Flyway history and the order-inquiry-key Secret all go. Back up first: pg_dumpall plus", 11.5, INK)
    s += text(ix + 16, vy + 90, "the key's value (docs/operations-guide.md, section 7). A WSL restart or k3d cluster stop loses nothing.", 11.5, INK)

    # arrows: browser -> node :443, kubectl -> serverlb
    s += (f'<path d="M282,248 L282,276 L1420,276 L1420,470 L{nx + nw},470" fill="none" stroke="{BLUE}" '
          f'stroke-width="1.6" stroke-dasharray="6 5" marker-end="url(#arrow)"/>')
    s += text(1180, 268, "HTTPS :443 via localhost forwarding", 10.5, BLUE, mono=True)
    s += arrow(lx + lw, 528, dx + 20, 403, MUTED, "arrow", dashed=True)
    s += text(lx + lw + 6, 500, "kubectl", 10.5, MUTED, mono=True)

    s += footer(W, 1460,
                "Survives a WSL restart: everything (restart: unless-stopped). Survives --destroy: only the repo, the host images and the named volumes.",
                "AquaShop  /  docs/diagrams/physical.svg")
    s += "</svg>"
    (OUT / "physical.svg").write_text(s, encoding="utf-8")


if __name__ == "__main__":
    architecture()
    deployment()
    gitflow()
    physical()
    for f in sorted(OUT.glob("*.svg")):
        print(f"{f.name}: {f.stat().st_size} bytes")
