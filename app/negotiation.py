
from fastapi import Request

_HTML = "text/html"
_JSON = "application/json"


def wants_html(request: Request) -> bool:
    accept = request.headers.get("accept", "")
    if not accept:
        return False

    html_q = -1.0
    json_q = -1.0
    for part in accept.split(","):
        media, _, params = part.strip().partition(";")
        media = media.strip().lower()
        q = 1.0
        for p in params.split(";"):
            p = p.strip()
            if p.startswith("q="):
                try:
                    q = float(p[2:])
                except ValueError:
                    q = 0.0
        if media == _HTML:
            html_q = max(html_q, q)
        elif media == _JSON:
            json_q = max(json_q, q)

    return html_q > 0 and html_q >= json_q
