#!/usr/bin/env python3
"""Generates the AquaShop diagram set as SVG.

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
    s += title_bar("AquaShop System Architecture", "Target design. Phase 1 components are built; the rest are planned.",
                   "System")
    s += legend(1000, 44, [("BUILT — PHASE 1", TEAL), ("PLANNED", DIM)])

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
             "SSR HTML, 2s upstream timeout", TEAL, TEAL, badge="BUILT", badge_color=TEAL)
    s += text(420, 466, "Aggregates service calls, owns no data, holds a 60s in-memory cache of the category nav.", 12.5, MUTED)
    s += text(420, 488, "Liveness does not call the catalog: a catalog outage must not restart every storefront pod.", 12, DIM)
    s += arrow(182, 236, 182, 432, TEAL, "arrowT")

    # --- services
    s += panel(48, 558, 1384, 214, "Domain services — one database each, no shared schema", ORANGE)
    svc = [
        ("catalog-service", "Java 21 / Spring Boot", "products, species profiles", TEAL, False),
        ("order-service", "Java 21 / Spring Boot", "checkout saga, order state", DIM, True),
        ("inventory-service", "Go", "tank stock, TTL holds", DIM, True),
        ("payment-service", "Rust / Axum", "auth, capture, ledger", DIM, True),
        ("aquatics-advisor", "Python / FastAPI", "compatibility rules", DIM, True),
        ("notification-service", "Go", "email + webhook fan-out", DIM, True),
        ("staff-portal", "JSP / WildFly", "back-office", DIM, True),
    ]
    x = 72
    for name, stack, owns, color, dashed in svc:
        w = 182
        s += box(x, 596, w, 96, name.replace("-service", ""), stack, owns,
                 color, color if color == TEAL else MUTED, dashed=dashed)
        if not dashed:
            s += arrow(x + w / 2, 512, x + w / 2, 590, TEAL, "arrowT")
        x += w + 18
    s += text(230, 728, "Every language choice is justified by a property of the service, never by curiosity. "
                       "Rust holds the money state machine because", 12, MUTED)
    s += text(230, 748, "exhaustive compile-time matching over transitions is worth its slow build; that cost is named in the ADR.",
              12, DIM)

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
             "catalog | orders | inventory | payments | advisor | notify", accent=BLUE, title_color=BLUE)
    s += text(760, 946, "One database and one login role per service; each role has CONNECT on its own database only.", 11.5, MUTED)
    s += text(760, 964, "Faithful: credential isolation, no cross-service joins. NOT faithful: blast radius — one restart", 11.5, ORANGE)
    s += text(760, 982, "takes every service down, which per-service RDS instances in the target design would not.", 11.5, ORANGE)

    s += (f'<path d="M163,700 L163,792 L900,792 L900,830" fill="none" stroke="{TEAL}" '
          f'stroke-width="1.6" marker-end="url(#arrowT)"/>')
    s += text(560, 784, "JDBC / Hikari, pool max 10", 10.5, TEAL, mono=True)

    s += footer(W, 1040,
                "Designed for AWS  •  validated with terraform test and mock providers  •  run on k3d  •  never applied",
                "AquaShop  /  docs/diagrams/architecture.svg")
    s += "</svg>"
    (OUT / "architecture.svg").write_text(s, encoding="utf-8")


# ---------------------------------------------------------------- diagram 2 --
def deployment():
    W, H = 1480, 1060
    s = head(W, H, "AquaShop deployment topology")
    s += title_bar("Deployment Topology", "What actually runs, beside what it is designed to become.", "Deployment")
    s += legend(1010, 44, [("RUNS LOCALLY", TEAL), ("VALIDATED, NOT APPLIED", ORANGE)])

    # ---- left: local
    s += panel(48, 120, 760, 800, "Actually running — Windows 11 / WSL2 / 16 GB", TEAL)
    s += box(72, 158, 712, 56, "Windows 11 host", "16 GB total, ~4-5 GB reserved for Windows",
             accent=LINE, title_color=MUTED)
    s += box(88, 230, 680, 56, "WSL2 (Ubuntu)", "~11 GB usable, capped in .wslconfig",
             accent=LINE, title_color=MUTED)
    s += box(104, 302, 648, 56, "Docker Engine (native in WSL, not Docker Desktop)", "one container per k3d node",
             accent=LINE, title_color=MUTED)
    s += box(120, 374, 616, 512, "k3d node container — k3s v1.30", "traefik: disabled | servicelb: disabled | metrics-server: disabled",
             accent=TEAL, title_color=TEAL, fill=PANEL)

    s += text(144, 446, "NAMESPACE  ingress-nginx", 11.5, MUTED, weight="700", mono=True)
    s += box(144, 458, 568, 50, "ingress-nginx controller", "hostPort 80/443 -> 127.0.0.1", accent=LINE, title_color=INK)
    s += text(144, 542, "NAMESPACE  cert-manager", 11.5, MUTED, weight="700", mono=True)
    s += box(144, 554, 568, 50, "cert-manager + CA issuer", "self-signed root, in-cluster leaf", accent=LINE, title_color=INK)
    s += text(144, 638, "NAMESPACE  aquashop-dev   (ResourceQuota 3Gi requests / 4Gi limits)", 11.5, MUTED, weight="700", mono=True)
    s += box(144, 650, 274, 70, "storefront", "req 96Mi / lim 160Mi", accent=TEAL, title_color=TEAL)
    s += box(438, 650, 274, 70, "catalog-service", "req 448Mi / lim 640Mi", accent=TEAL, title_color=TEAL)
    s += box(144, 736, 568, 70, "postgres (StatefulSet, PVC on local-path)",
             "req 192Mi / lim 320Mi — databases: catalog", accent=BLUE, title_color=BLUE)
    s += text(144, 842, "Namespaces uat and prod exist as Argo CD Applications but sit at replicas: 0.", 11.5, ORANGE)
    s += text(144, 862, "One environment is materialised at a time. None of them has ever run concurrently.", 11.5, ORANGE)

    # ---- right: AWS target
    s += panel(832, 120, 600, 800, "Target design — AWS (never applied)", ORANGE)
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

    s += footer(W, 960,
                "Total measured footprint: fill in from `kubectl top pods -A` after the first bootstrap. Estimate for this profile: ~2.6 GB.",
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


if __name__ == "__main__":
    architecture()
    deployment()
    gitflow()
    for f in sorted(OUT.glob("*.svg")):
        print(f"{f.name}: {f.stat().st_size} bytes")
