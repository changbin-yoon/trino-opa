package trino

# 기본적으로 모든 접근을 거부
default allow = false

# ============================================
# 서비스 계정 정의
# ============================================
# 서비스 계정 목록 (명시적으로 정의된 5개 계정)
# 실제 환경에서는 실제 서비스 계정 이름으로 변경해야 합니다
service_accounts = [
    "svc-trino-reader",
    "svc-trino-writer",
    "svc-analytics",
    "svc-etl",
    "svc-monitoring"
]

# 서비스 계정 LDAP 그룹 목록 (선택사항)
# 서비스 계정이 특정 LDAP 그룹에 속해 있다면 사용 가능
service_account_groups = [
    "service-accounts",
    "svc-accounts",
    "trino-service-accounts"
]

# ============================================
# Kubernetes 클러스터 CIDR 정의
# ============================================
# Kubernetes 클러스터 내부 IP 대역 (CIDR 형식)
# 실제 환경에서는 실제 Kubernetes 클러스터 CIDR로 변경해야 합니다
kubernetes_cluster_cidrs = [
    "10.0.0.0/8",        # Kubernetes 기본 서비스 네트워크
    "172.16.0.0/12",     # Kubernetes Pod 네트워크 (일부 환경)
    "192.168.0.0/16"     # Kubernetes Pod 네트워크 (일부 환경)
]

# ============================================
# 팀별 스키마 접근 권한 정의
# ============================================
team_catalog_schemas = {
    "team-a": {
        "hive": ["team_a_schema", "team_shared_schema"],
        "iceberg": ["team_a_schema", "team_shared_schema"]
    },
    "team-b": {
        "hive": ["team_shared_schema"],
        "iceberg": ["team_b_schema", "team_shared_schema"]
    },
    "team-c": {
        "hive": ["team_c_schema", "team_shared_schema"],
        "iceberg": ["team_shared_schema"]
    },
    "admin": {
        "hive": ["*"],
        "iceberg": ["*"]
    },
    # 서비스 계정도 특정 스키마에 접근 가능하도록 설정
    "service-accounts": {
        "hive": ["*"],
        "iceberg": ["*"]
    }
}

# ============================================
# 헬퍼 함수: 서비스 계정인지 확인
# ============================================
# 명시적으로 정의된 서비스 계정 목록에서 확인
is_service_account {
    username := input.context.identity.user
    service_accounts[_] == username
}

# 또는 LDAP 그룹으로 확인 (선택사항)
is_service_account {
    user_group := input.context.identity.groups[_]
    service_account_groups[_] == user_group
}

# ============================================
# 헬퍼 함수: 일반 사용자인지 확인
# ============================================
# 서비스 계정 그룹에 속하지 않은 사용자
is_regular_user {
    not is_service_account
}

# ============================================
# 헬퍼 함수: IP 주소가 Kubernetes 클러스터 CIDR에 속하는지 확인
# ============================================
# IP 주소가 Kubernetes 클러스터 CIDR 중 하나에 속하는지 확인
# OPA의 net.cidr_contains 함수 사용 (OPA 0.20.0 이상 권장)
# 만약 net.cidr_contains가 작동하지 않으면 아래의 prefix 매칭 방법 사용

# 방법 1: net.cidr_contains 사용 (정확한 CIDR 체크, 권장)
ip_in_cluster_cidr(client_ip) {
    cidr := kubernetes_cluster_cidrs[_]
    net.cidr_contains(cidr, client_ip)
}

# 방법 2: 간단한 prefix 매칭 (대체 방법, net.cidr_contains가 작동하지 않을 때 사용)
# 10.0.0.0/8 체크
ip_in_cluster_cidr(client_ip) {
    startswith(client_ip, "10.")
}

# 172.16.0.0/12 체크 (172.16. ~ 172.31.)
# 주의: 이 방법은 정확하지 않을 수 있으므로 net.cidr_contains 사용 권장
ip_in_cluster_cidr(client_ip) {
    startswith(client_ip, "172.16.")
}

ip_in_cluster_cidr(client_ip) {
    startswith(client_ip, "172.17.")
}

ip_in_cluster_cidr(client_ip) {
    startswith(client_ip, "172.18.")
}

ip_in_cluster_cidr(client_ip) {
    startswith(client_ip, "172.19.")
}

ip_in_cluster_cidr(client_ip) {
    startswith(client_ip, "172.20.")
}

ip_in_cluster_cidr(client_ip) {
    startswith(client_ip, "172.21.")
}

ip_in_cluster_cidr(client_ip) {
    startswith(client_ip, "172.22.")
}

ip_in_cluster_cidr(client_ip) {
    startswith(client_ip, "172.23.")
}

ip_in_cluster_cidr(client_ip) {
    startswith(client_ip, "172.24.")
}

ip_in_cluster_cidr(client_ip) {
    startswith(client_ip, "172.25.")
}

ip_in_cluster_cidr(client_ip) {
    startswith(client_ip, "172.26.")
}

ip_in_cluster_cidr(client_ip) {
    startswith(client_ip, "172.27.")
}

ip_in_cluster_cidr(client_ip) {
    startswith(client_ip, "172.28.")
}

ip_in_cluster_cidr(client_ip) {
    startswith(client_ip, "172.29.")
}

ip_in_cluster_cidr(client_ip) {
    startswith(client_ip, "172.30.")
}

ip_in_cluster_cidr(client_ip) {
    startswith(client_ip, "172.31.")
}

# 192.168.0.0/16 체크
ip_in_cluster_cidr(client_ip) {
    startswith(client_ip, "192.168.")
}

# ============================================
# 헬퍼 함수: Kubernetes 환경에서 접근하는지 확인
# ============================================
# IP 주소가 Kubernetes 클러스터 CIDR에 속하는지 확인
# 주의: IP 정보가 input에 포함되어야 함
# 가능한 위치: input.context.source.ip, input.context.client.ip 등
is_kubernetes_environment {
    client_ip := input.context.source.ip
    ip_in_cluster_cidr(client_ip)
}

# 대체 위치에서 IP 확인
is_kubernetes_environment {
    client_ip := input.context.client.ip
    ip_in_cluster_cidr(client_ip)
}

# 세션 속성으로 Kubernetes 환경 확인 (Trino 세션 속성 사용 시)
is_kubernetes_environment {
    input.context.session.environment == "kubernetes"
}

# ============================================
# 핵심 정책: 서비스 계정 접근 제어
# ============================================
# 규칙 1: 서비스 계정은 Kubernetes 환경에서만 접근 허용
# 규칙 2: 일반 사용자가 서비스 계정을 사용하려고 하면 차단

# 일반 사용자가 서비스 계정 이름을 사용하려고 하는 경우 차단
# (명시적으로 정의된 서비스 계정 목록에 있는 사용자 이름을 일반 사용자가 사용하는 경우)
deny_service_account_usage {
    is_regular_user
    username := input.context.identity.user
    service_accounts[_] == username
}

# 서비스 계정이 Kubernetes 환경이 아닌 곳에서 접근하는 경우 차단
deny_service_account_non_k8s {
    is_service_account
    not is_kubernetes_environment
}

# 서비스 계정이 Kubernetes 환경에서 접근하는 경우 허용
# (deny 규칙을 통과한 경우에만)
allow {
    input.action.type == "QueryAccessControl"
    is_service_account
    is_kubernetes_environment
    not deny_service_account_usage
}

# ============================================
# 스키마 접근 제어
# ============================================
# 헬퍼 함수: 사용자가 스키마에 접근할 수 있는지 확인
can_access_schema(catalog, schema) {
    user_group := input.context.identity.groups[_]
    team_schemas := team_catalog_schemas[user_group]
    catalog_schemas := team_schemas[catalog]
    catalog_schemas[_] == "*"
}

can_access_schema(catalog, schema) {
    user_group := input.context.identity.groups[_]
    team_schemas := team_catalog_schemas[user_group]
    catalog_schemas := team_schemas[catalog]
    catalog_schemas[_] == schema
}

# 스키마 접근 허용 (서비스 계정 제어 통과 후)
allow {
    input.action.type == "SchemaAccessControl"
    input.action.catalog in ["hive", "iceberg"]
    
    # 서비스 계정 제어 통과 확인
    not deny_service_account_usage
    not deny_service_account_non_k8s
    
    # 스키마 접근 권한 확인
    can_access_schema(input.action.catalog, input.action.schema.schema)
}

allow {
    input.action.type == "SchemaAccessControl"
    input.action.catalog in ["hive", "iceberg"]
    
    not deny_service_account_usage
    not deny_service_account_non_k8s
    
    can_access_schema(input.action.catalog, input.action.schema)
}

# ============================================
# 카탈로그 접근 제어
# ============================================
allow {
    input.action.type == "CatalogAccessControl"
    input.action.catalog in ["hive", "iceberg"]
    
    # 서비스 계정 제어 통과 확인
    not deny_service_account_usage
    not deny_service_account_non_k8s
}

# ============================================
# 테이블 접근 제어
# ============================================
allow {
    input.action.type == "TableAccessControl"
    input.action.catalog in ["hive", "iceberg"]
    
    not deny_service_account_usage
    not deny_service_account_non_k8s
    
    can_access_schema(input.action.table.catalog, input.action.table.schema)
}

allow {
    input.action.type == "TableAccessControl"
    input.action.catalog in ["hive", "iceberg"]
    
    not deny_service_account_usage
    not deny_service_account_non_k8s
    
    can_access_schema(input.action.catalog, input.action.schema)
}

# ============================================
# 컬럼 접근 제어
# ============================================
allow {
    input.action.type == "ColumnAccessControl"
    input.action.catalog in ["hive", "iceberg"]
    
    not deny_service_account_usage
    not deny_service_account_non_k8s
    
    can_access_schema(input.action.column.table.catalog, input.action.column.table.schema)
}

allow {
    input.action.type == "ColumnAccessControl"
    input.action.catalog in ["hive", "iceberg"]
    
    not deny_service_account_usage
    not deny_service_account_non_k8s
    
    can_access_schema(input.action.catalog, input.action.schema)
}

# ============================================
# 시스템 정보 접근 제어
# ============================================
allow {
    input.action.type == "SystemInformationAccessControl"
    
    # 서비스 계정 제어는 시스템 정보 조회에도 적용
    not deny_service_account_usage
    not deny_service_account_non_k8s
}

