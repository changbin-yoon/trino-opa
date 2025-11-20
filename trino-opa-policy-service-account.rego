package trino

# 기본적으로 모든 접근을 거부
default allow = false

# ============================================
# 서비스 계정 정의
# ============================================
# 서비스 계정을 구분하는 방법:
# 1. LDAP 그룹으로 구분 (예: "service-accounts" 그룹에 속한 사용자)
# 2. 사용자 이름 패턴으로 구분 (예: svc-*, service-*로 시작하는 사용자)

# 서비스 계정 LDAP 그룹 목록
service_account_groups = [
    "service-accounts",
    "svc-accounts",
    "trino-service-accounts"
]

# 서비스 계정 사용자 이름 패턴 (정규식 대신 prefix/suffix 사용)
service_account_prefixes = [
    "svc-",
    "service-",
    "trino-svc-"
]

# 서비스 계정 사용자 이름 suffix
service_account_suffixes = [
    "-svc",
    "-service"
]

# ============================================
# Kubernetes 환경 IP 대역 정의
# ============================================
# Kubernetes 클러스터 내부 IP 대역
# 실제 환경에서는 실제 Kubernetes 클러스터 IP 대역으로 변경해야 합니다
kubernetes_ip_ranges = [
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
# 방법 1: LDAP 그룹으로 확인
is_service_account {
    user_group := input.context.identity.groups[_]
    service_account_groups[_] == user_group
}

# 방법 2: 사용자 이름 패턴으로 확인
is_service_account {
    username := input.context.identity.user
    startswith(username, service_account_prefixes[_])
}

is_service_account {
    username := input.context.identity.user
    endswith(username, service_account_suffixes[_])
}

# ============================================
# 헬퍼 함수: 일반 사용자인지 확인
# ============================================
# 서비스 계정 그룹에 속하지 않은 사용자
is_regular_user {
    not is_service_account
}

# ============================================
# 헬퍼 함수: Kubernetes 환경에서 접근하는지 확인
# ============================================
# IP 주소가 Kubernetes IP 대역에 있는지 확인
# 주의: IP 정보가 input에 포함되어야 함
# 가능한 위치: input.context.source.ip, input.context.client.ip 등
is_kubernetes_environment {
    client_ip := input.context.source.ip
    # 간단한 prefix 매칭 (실제로는 CIDR 체크 필요)
    startswith(client_ip, "10.")
}

is_kubernetes_environment {
    client_ip := input.context.source.ip
    startswith(client_ip, "172.16.")
}

is_kubernetes_environment {
    client_ip := input.context.source.ip
    startswith(client_ip, "192.168.")
}

# 대체 위치에서 IP 확인
is_kubernetes_environment {
    client_ip := input.context.client.ip
    startswith(client_ip, "10.")
}

is_kubernetes_environment {
    client_ip := input.context.client.ip
    startswith(client_ip, "172.16.")
}

is_kubernetes_environment {
    client_ip := input.context.client.ip
    startswith(client_ip, "192.168.")
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

# 일반 사용자가 서비스 계정을 사용하려고 하는 경우 차단
# (서비스 계정 그룹에 속하지 않은 사용자가 서비스 계정 이름으로 접근 시도)
deny_service_account_usage {
    is_regular_user
    # 사용자가 서비스 계정 이름 패턴을 사용하려고 하는지 확인
    username := input.context.identity.user
    startswith(username, service_account_prefixes[_])
}

deny_service_account_usage {
    is_regular_user
    username := input.context.identity.user
    endswith(username, service_account_suffixes[_])
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

