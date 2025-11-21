package trino

import future.keywords.if
import future.keywords.in

default allow := false

identity := input.context.identity
user := identity.user
groups := identity.groups
client_ip := input.context.clientIp

# ---------------------------------------------------
# 1) K8s ClusterIP 대역 판별
# ---------------------------------------------------
# 일반적인 Kubernetes 내부 대역 (CIDR)
cluster_cidrs := [
    "10.",
    "172.16.",
    "172.17.",
    "172.18.",
    "172.19.",
    "172.20.",
    "172.21.",
    "172.22.",
    "172.23.",
    "172.24.",
    "172.25.",
    "172.26.",
    "172.27.",
    "172.28.",
    "172.29.",
    "172.30.",
    "172.31.",
    "192.168."
]

is_cluster_ip if {
    some prefix in cluster_cidrs
    startswith(client_ip, prefix)
}

is_external_ip if {
    not is_cluster_ip
}

# ---------------------------------------------------
# 2) 허용된 Service Account 목록
#    (쿠버네티스 serviceAccountName 이 Trino user 로 들어오는 환경을 가정)
# ---------------------------------------------------
allowed_service_accounts := {
    "spark-sa",
    "trino-worker",
    "etl-service",
    "myapp-service-sa"
}

is_service_account if {
    user in allowed_service_accounts
}

# ---------------------------------------------------
# 3) 규칙: 내부 IP(ClusterIP) → 특정 SA만 허용
# ---------------------------------------------------
allow if {
    is_cluster_ip
    is_service_account
}

# ---------------------------------------------------
# 4) 외부 IP → service account 접근 금지, 일반 사용자만 허용
# ---------------------------------------------------
allow if {
    is_external_ip
    not is_service_account
}



#3, 4번을 통하여 allow
