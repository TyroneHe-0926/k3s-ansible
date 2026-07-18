#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SERVICES=(
    "cert-manager:TLS certificate management"
    "rancher:Kubernetes management UI (requires cert-manager)"
    "longhorn:CSI persistent storage (requires open-iscsi on all nodes)"
    "traefik-dashboard:Traefik ingress controller dashboard"
    "kube-prometheus-stack:Prometheus + Grafana monitoring"
    "pihole:Network-wide DNS ad blocker"
)

usage() {
    echo "Usage: $0 [--all | --list | service1 service2 ...]"
    echo ""
    echo "Available services:"
    for entry in "${SERVICES[@]}"; do
        name="${entry%%:*}"
        desc="${entry#*:}"
        printf "  %-24s %s\n" "$name" "$desc"
    done
    echo ""
    echo "Options:"
    echo "  --all    Install all services in dependency order"
    echo "  --list   List available services"
    echo ""
    echo "Examples:"
    echo "  $0 cert-manager rancher"
    echo "  $0 pihole"
    echo "  $0 --all"
}

install_service() {
    local service="$1"
    local script="$SCRIPT_DIR/install-${service}.sh"

    if [[ ! -f "$script" ]]; then
        echo "Error: no install script found for '$service'"
        return 1
    fi

    bash "$script"
    echo ""
}

if [[ $# -eq 0 ]]; then
    echo "Select services to install:"
    echo ""
    selected=()
    for i in "${!SERVICES[@]}"; do
        name="${SERVICES[$i]%%:*}"
        desc="${SERVICES[$i]#*:}"
        printf "  %d) %-24s %s\n" $((i + 1)) "$name" "$desc"
    done
    echo ""
    read -rp "Enter numbers separated by spaces (e.g., 1 3 6), or 'all': " choices

    if [[ "$choices" == "all" ]]; then
        for entry in "${SERVICES[@]}"; do
            selected+=("${entry%%:*}")
        done
    else
        for choice in $choices; do
            idx=$((choice - 1))
            if [[ $idx -ge 0 && $idx -lt ${#SERVICES[@]} ]]; then
                selected+=("${SERVICES[$idx]%%:*}")
            else
                echo "Invalid selection: $choice"
                exit 1
            fi
        done
    fi

    if [[ ${#selected[@]} -eq 0 ]]; then
        echo "No services selected."
        exit 0
    fi

    echo ""
    echo "Will install: ${selected[*]}"
    read -rp "Continue? [y/N] " confirm
    [[ "$confirm" =~ ^[yY]$ ]] || exit 0
    echo ""

    for service in "${selected[@]}"; do
        install_service "$service"
    done
else
    case "$1" in
        --all)
            for entry in "${SERVICES[@]}"; do
                install_service "${entry%%:*}"
            done
            ;;
        --list)
            for entry in "${SERVICES[@]}"; do
                name="${entry%%:*}"
                desc="${entry#*:}"
                printf "  %-24s %s\n" "$name" "$desc"
            done
            exit 0
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            for service in "$@"; do
                install_service "$service"
            done
            ;;
    esac
fi

echo "=== Setup complete ==="
