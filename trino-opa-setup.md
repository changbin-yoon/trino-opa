# Trino와 OPA 연동 가이드

## 개요

이 문서는 Trino와 Open Policy Agent(OPA)를 연동하여 팀별 스키마 접근 제어를 구현하는 방법을 설명합니다.

## Trino와 OPA 간의 연결 방식

### 1. 통신 흐름

```
사용자 쿼리 요청
    ↓
Trino (쿼리 파싱 및 리소스 식별)
    ↓
OPA에 정책 평가 요청 (HTTP POST)
    ↓
OPA (Rego 정책 평가)
    ↓
Trino에 허용/거부 응답 (JSON)
    ↓
쿼리 실행 또는 거부
```

### 2. Trino가 OPA에 전달하는 정보

Trino는 각 쿼리 실행 시 OPA에 다음과 같은 JSON 구조의 요청을 전송합니다:

```json
{
  "context": {
    "identity": {
      "user": "alice",
      "groups": ["team-a", "developers"],
      "principal": "alice@example.com"
    },
    "queryId": "20231115_123456_00001_abcde",
    "trinoVersion": "450"
  },
  "action": {
    "type": "SchemaAccessControl",
    "catalog": "hive",
    "schema": {
      "catalog": "hive",
      "schema": "team_a_schema"
    }
  }
}
```

**주요 필드 설명:**

- `context.identity.user`: 사용자 ID
- `context.identity.groups`: 사용자가 속한 LDAP 그룹 목록 (배열)
- `context.identity.principal`: 사용자 principal 정보
- `action.type`: 접근 제어 타입
  - `CatalogAccessControl`: 카탈로그 접근
  - `SchemaAccessControl`: 스키마 접근
  - `TableAccessControl`: 테이블 접근
  - `ColumnAccessControl`: 컬럼 접근
  - `QueryAccessControl`: 쿼리 실행
  - `SystemInformationAccessControl`: 시스템 정보 조회
- `action.catalog`: 카탈로그 이름 (hive, iceberg 등)
- `action.schema`: 스키마 정보
- `action.table`: 테이블 정보
- `action.column`: 컬럼 정보

### 3. OPA가 Trino에 반환하는 응답

OPA는 정책 평가 결과를 다음과 같은 JSON 형식으로 반환합니다:

```json
{
  "result": {
    "allow": true
  }
}
```

- `allow: true`: 접근 허용
- `allow: false`: 접근 거부 (기본값)

## 접근 제어 범위

OPA를 통한 Trino 접근 제어는 다음 레벨에서 가능합니다:

### 1. 카탈로그 레벨 (Catalog Level)
- 특정 카탈로그(hive, iceberg 등)에 대한 접근 허용/거부

### 2. 스키마 레벨 (Schema Level) ⭐ **최우선 구현**
- 특정 스키마에 대한 접근 제어
- 팀별로 다른 스키마 접근 권한 부여
- 예: team-a는 `team_a_schema`만, team-b는 `team_b_schema`만 접근

### 3. 테이블 레벨 (Table Level)
- 특정 테이블에 대한 접근 제어
- 스키마 접근 권한을 상속받거나 별도로 정의 가능

### 4. 컬럼 레벨 (Column Level)
- 특정 컬럼에 대한 접근 제어
- 민감한 컬럼(예: 개인정보) 마스킹 또는 접근 차단

### 5. 행 레벨 (Row Level)
- OPA 정책을 확장하여 행 단위 필터링 가능
- 예: 사용자별로 자신의 데이터만 조회

## 설정 방법

### 1. Trino 설정

`etc/access-control.properties` 파일 생성:

```properties
access-control.name=opa
opa.policy.uri=http://opa-server:8181/v1/data/trino/allow
opa.allow-on-error=false
opa.read-timeout=10s
```

**설정 설명:**
- `access-control.name`: OPA 접근 제어 사용
- `opa.policy.uri`: OPA 서버의 정책 평가 엔드포인트
- `opa.allow-on-error`: OPA 오류 시 기본 동작 (false: 거부, true: 허용)
- `opa.read-timeout`: OPA 응답 대기 시간

### 2. OPA 설정

#### OPA 서버 실행

```bash
# OPA 서버 실행
opa run --server --log-level=info

# 또는 Docker 사용
docker run -d -p 8181:8181 \
  -v $(pwd):/policies \
  openpolicyagent/opa:latest \
  run --server --log-level=info
```

#### 정책 배포

```bash
# 정책 파일을 OPA에 로드
opa test trino-opa-policy.rego
curl -X PUT http://localhost:8181/v1/policies/trino \
  --data-binary @trino-opa-policy.rego
```

또는 OPA Bundle 방식 사용:

```bash
# 정책 디렉토리 구조
policies/
  └── trino/
      └── policy.rego

# Bundle 생성 및 배포
opa build policies/
curl -X PUT http://localhost:8181/v1/data/trino/allow \
  -H "Content-Type: application/json" \
  -d @bundle.tar.gz
```

### 3. LDAP 그룹 매핑

Trino는 LDAP 인증을 통해 사용자 그룹 정보를 가져옵니다. `etc/password-authenticator.properties` 설정:

```properties
password-authenticator.name=ldap
ldap.url=ldap://ldap-server:389
ldap.user-bind-pattern=uid=${USER},ou=users,dc=example,dc=com
ldap.user-base-dn=ou=users,dc=example,dc=com
ldap.group-base-dn=ou=groups,dc=example,dc=com
```

사용자가 속한 LDAP 그룹은 `input.context.identity.groups` 배열로 OPA에 전달됩니다.

## Rego 정책 구조 설명

### 팀별 스키마 접근 권한 정의

```rego
team_catalog_schemas = {
    "team-a": {
        "hive": ["team_a_schema", "team_shared_schema"],
        "iceberg": ["team_a_schema", "team_shared_schema"]
    },
    "team-b": {
        "hive": ["team_shared_schema"],
        "iceberg": ["team_b_schema", "team_shared_schema"]
    }
}
```

이 구조는:
- 각 팀(LDAP 그룹명)을 키로 사용
- 각 카탈로그별로 접근 가능한 스키마 목록을 정의
- 와일드카드(`*`)를 사용하여 모든 스키마 접근 가능 (admin 그룹)

### 접근 허용 로직

```rego
allow {
    # 1. 사용자가 속한 그룹 확인
    user_group := input.context.identity.groups[_]
    
    # 2. 해당 그룹의 카탈로그별 스키마 목록 가져오기
    team_schemas := team_catalog_schemas[user_group]
    catalog_schemas := team_schemas[input.action.schema.catalog]
    
    # 3. 요청한 스키마가 허용 목록에 있는지 확인
    catalog_schemas[_] == input.action.schema.schema
}
```

## 테스트 방법

### 1. OPA 정책 테스트

```bash
# OPA 테스트 실행
opa test trino-opa-policy.rego -v
```

### 2. 정책 평가 테스트

```bash
# 테스트 입력 JSON 생성
cat > test-input.json <<EOF
{
  "context": {
    "identity": {
      "user": "alice",
      "groups": ["team-a"]
    }
  },
  "action": {
    "type": "SchemaAccessControl",
    "catalog": "hive",
    "schema": {
      "catalog": "hive",
      "schema": "team_a_schema"
    }
  }
}
EOF

# OPA에 정책 평가 요청
curl -X POST http://localhost:8181/v1/data/trino/allow \
  -H "Content-Type: application/json" \
  -d @test-input.json
```

예상 응답:
```json
{
  "result": {
    "allow": true
  }
}
```

### 3. Trino 쿼리 테스트

```sql
-- 허용된 스키마 접근 (성공)
USE hive.team_a_schema;
SHOW TABLES;

-- 거부된 스키마 접근 (실패)
USE hive.team_b_schema;
-- Error: Access Denied
```

## 주의사항

1. **기본 정책**: `default allow = false`로 설정하여 명시적으로 허용하지 않은 모든 접근을 거부합니다.

2. **그룹 우선순위**: 사용자가 여러 그룹에 속한 경우, 첫 번째로 매칭되는 그룹의 권한이 적용됩니다. 필요시 정책을 수정하여 여러 그룹의 권한을 합칠 수 있습니다.

3. **성능**: OPA는 각 쿼리마다 호출되므로, OPA 서버의 응답 시간이 Trino 쿼리 성능에 영향을 줍니다. OPA 서버를 고가용성으로 구성하는 것을 권장합니다.

4. **정책 업데이트**: 정책 변경 시 OPA 서버를 재시작하거나 Bundle을 재배포해야 합니다.

## 확장 가능한 기능

1. **시간 기반 접근 제어**: 특정 시간대에만 접근 허용
2. **IP 기반 접근 제어**: 특정 IP에서만 접근 허용
3. **쿼리 복잡도 제한**: 복잡한 쿼리 실행 제한
4. **행 레벨 보안**: 사용자별로 다른 데이터 행만 조회 가능하도록 필터링

