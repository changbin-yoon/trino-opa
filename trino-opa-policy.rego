package trino

# 기본적으로 모든 접근을 거부
default allow = false

# ============================================
# 팀별 스키마 접근 권한 정의
# ============================================
# 각 팀(LDAP 그룹)이 접근할 수 있는 카탈로그별 스키마를 정의
# 실제 환경에서는 팀명과 스키마명을 실제 값으로 변경해야 합니다
team_catalog_schemas = {
    # team-a 그룹: hive의 team_a_schema, team_shared_schema 접근 가능
    "team-a": {
        "hive": ["team_a_schema", "team_shared_schema"],
        "iceberg": ["team_a_schema", "team_shared_schema"]
    },
    # team-b 그룹: iceberg의 team_b_schema, team_shared_schema 접근 가능
    "team-b": {
        "hive": ["team_shared_schema"],
        "iceberg": ["team_b_schema", "team_shared_schema"]
    },
    # team-c 그룹: hive의 team_c_schema, team_shared_schema 접근 가능
    "team-c": {
        "hive": ["team_c_schema", "team_shared_schema"],
        "iceberg": ["team_shared_schema"]
    },
    # admin 그룹: 모든 스키마 접근 가능
    "admin": {
        "hive": ["*"],
        "iceberg": ["*"]
    }
}

# ============================================
# 헬퍼 함수: 사용자가 스키마에 접근할 수 있는지 확인
# ============================================
# 사용자의 그룹 중 하나가 해당 카탈로그의 스키마에 접근 권한이 있는지 확인
can_access_schema(catalog, schema) {
    # 사용자가 속한 그룹 중 하나를 선택
    user_group := input.context.identity.groups[_]
    
    # 해당 그룹의 카탈로그별 스키마 목록 가져오기
    team_schemas := team_catalog_schemas[user_group]
    catalog_schemas := team_schemas[catalog]
    
    # 와일드카드(*)가 있으면 모든 스키마 허용
    catalog_schemas[_] == "*"
}

can_access_schema(catalog, schema) {
    # 사용자가 속한 그룹 중 하나를 선택
    user_group := input.context.identity.groups[_]
    
    # 해당 그룹의 카탈로그별 스키마 목록 가져오기
    team_schemas := team_catalog_schemas[user_group]
    catalog_schemas := team_schemas[catalog]
    
    # 특정 스키마가 허용 목록에 있는지 확인
    catalog_schemas[_] == schema
}

# ============================================
# 카탈로그 접근 제어
# ============================================
# 카탈로그 레벨 접근 허용 (hive, iceberg 모두 허용)
allow {
    input.action.type == "CatalogAccessControl"
    input.action.catalog in ["hive", "iceberg"]
}

# ============================================
# 스키마 접근 제어 (팀별) ⭐ 최우선 구현
# ============================================
# 사용자의 LDAP 그룹을 확인하여 해당 팀의 스키마에만 접근 허용
allow {
    input.action.type == "SchemaAccessControl"
    input.action.catalog in ["hive", "iceberg"]
    
    # 헬퍼 함수를 사용하여 스키마 접근 권한 확인
    # Trino 버전에 따라 input.action.schema 구조가 다를 수 있음
    # 가능한 구조: input.action.schema.schema 또는 input.action.schema
    can_access_schema(input.action.catalog, input.action.schema.schema)
}

# Trino 버전에 따라 스키마 정보가 다른 위치에 있을 수 있음
allow {
    input.action.type == "SchemaAccessControl"
    input.action.catalog in ["hive", "iceberg"]
    
    # 대체 구조: 스키마 정보가 직접 action에 있는 경우
    can_access_schema(input.action.catalog, input.action.schema)
}

# ============================================
# 테이블 접근 제어 (스키마 접근 권한 상속)
# ============================================
# 테이블 접근은 스키마 접근 권한을 상속받음
allow {
    input.action.type == "TableAccessControl"
    input.action.catalog in ["hive", "iceberg"]
    
    # 테이블의 스키마에 대한 접근 권한 확인
    # Trino 버전에 따라 input.action.table 구조가 다를 수 있음
    can_access_schema(input.action.table.catalog, input.action.table.schema)
}

# 대체 구조 지원
allow {
    input.action.type == "TableAccessControl"
    input.action.catalog in ["hive", "iceberg"]
    
    can_access_schema(input.action.catalog, input.action.schema)
}

# ============================================
# 컬럼 접근 제어 (테이블 접근 권한 상속)
# ============================================
# 컬럼 접근은 테이블 접근 권한을 상속받음
allow {
    input.action.type == "ColumnAccessControl"
    input.action.catalog in ["hive", "iceberg"]
    
    # 컬럼이 속한 테이블의 스키마에 대한 접근 권한 확인
    # Trino 버전에 따라 input.action.column 구조가 다를 수 있음
    can_access_schema(input.action.column.table.catalog, input.action.column.table.schema)
}

# 대체 구조 지원
allow {
    input.action.type == "ColumnAccessControl"
    input.action.catalog in ["hive", "iceberg"]
    
    can_access_schema(input.action.catalog, input.action.schema)
}

# ============================================
# 시스템 정보 접근 제어
# ============================================
# 시스템 정보 조회는 모든 사용자에게 허용
allow {
    input.action.type == "SystemInformationAccessControl"
}

# ============================================
# 쿼리 실행 권한 제어
# ============================================
# 쿼리 실행은 위의 리소스 접근 권한에 따라 결정됨
allow {
    input.action.type == "QueryAccessControl"
}

