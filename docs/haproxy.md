# HAProxy Configuration

HAProxy runs on a pfSense cluster outside of Kubernetes, routing traffic to the K3s nodes.

## Backend: Kubernetes HTTP (Traefik)

```haproxy
backend k8s_http
    mode http
    balance roundrobin
    option httpchk GET /_health/ HTTP/1.1\r\nHost:\ traefik.local
    http-check expect status 200

    server www01 192.168.100.70:30080 check inter 5000 fall 3 rise 2
    server www02 192.168.100.71:30080 check inter 5000 fall 3 rise 2
    server tr1   192.168.100.81:30080 check inter 5000 fall 3 rise 2

backend k8s_https
    mode tcp
    balance roundrobin
    option tcp-check

    server www01 192.168.100.70:30444 check inter 5000 fall 3 rise 2
    server www02 192.168.100.71:30444 check inter 5000 fall 3 rise 2
    server tr1   192.168.100.81:30444 check inter 5000 fall 3 rise 2
```

## Frontends

```haproxy
frontend http_front
    bind *:80
    mode http
    default_backend k8s_http

frontend https_front
    bind *:443
    mode tcp
    default_backend k8s_https
```

## Health Check Notes

- Traefik exposes health on `/_health/` path
- Health checks require Host header for proper routing
- NodePort 30080 = HTTP, 30444 = HTTPS
- All three nodes are control-plane, so any can receive traffic

## Application-Specific Health Checks

For more granular health checking (optional):

```haproxy
# Sentry-specific backend (if needed)
backend sentry_http
    mode http
    option httpchk GET /_health/ HTTP/1.1\r\nHost:\ sentry.ediai.com
    http-check expect status 200

    server www01 192.168.100.70:30080 check inter 10000 fall 3 rise 2
    server www02 192.168.100.71:30080 check inter 10000 fall 3 rise 2
    server tr1   192.168.100.81:30080 check inter 10000 fall 3 rise 2

# Grafana-specific backend
backend grafana_http
    mode http
    option httpchk GET /api/health HTTP/1.1\r\nHost:\ grafana.ediai.net
    http-check expect status 200

    server www01 192.168.100.70:30080 check inter 10000 fall 3 rise 2
    server www02 192.168.100.71:30080 check inter 10000 fall 3 rise 2
    server tr1   192.168.100.81:30080 check inter 10000 fall 3 rise 2
```

## Kubernetes NodePort Mapping

| Service | NodePort | Protocol | Purpose |
|---------|----------|----------|---------|
| Traefik HTTP | 30080 | TCP | HTTP ingress |
| Traefik HTTPS | 30444 | TCP | HTTPS ingress |
| K8s Dashboard | 30443 | TCP | Dashboard (direct) |
| EDIai Prod Frontend | 31800 | TCP | Direct access (bypass Traefik) |
| EDIai Prod Backend | 31801 | TCP | Direct access (bypass Traefik) |
| EDIai Staging Frontend | 30800 | TCP | Direct access (bypass Traefik) |
| EDIai Staging Backend | 30801 | TCP | Direct access (bypass Traefik) |
| Discourse | 30300 | TCP | Direct access (bypass Traefik) |

## pfSense Integration

In pfSense HAProxy package:

1. **Backend Servers**: Add all 3 K3s nodes with health checks enabled
2. **Frontend**: Bind to WAN interface, forward to k8s backend
3. **SSL Offloading**: Handled by Cloudflare (orange cloud), HAProxy does TCP passthrough
4. **Sticky Sessions**: Not required (stateless apps)

## Cloudflare → HAProxy → K8s Flow

```
Internet → Cloudflare (SSL termination) → HAProxy (TCP proxy) → Traefik → Pod
```

Note: Cloudflare handles SSL. HAProxy can run in TCP mode for HTTPS traffic since certificates are managed at Cloudflare edge.
