# Trino OPA 접근 제어 정책

Trino와 Open Policy Agent(OPA)를 연동하여 팀별 스키마 접근 제어 및 서비스 계정 관리를 구현한 정책 파일입니다.

## 파일 구조

### 핵심 파일

- **`trino-opa-policy-service-account.rego`** - OPA Rego 정책 파일
  - 팀별 스키마 접근 제어
  - 서비스 계정 접근 제어 (Kubernetes 클러스터 CIDR에서만 허용)
  - 일반 사용자의 서비스 계정 사용 차단

### 문서 파일

- **`trino-opa-setup.md`** - Trino와 OPA 연동 설정 가이드
  - Trino 설정 방법
  - OPA 설정 방법
  - 정책 배포 방법
  - Trino와 OPA 간 정보 교환 방식 설명

- **`trino-opa-service-account-guide.md`** - 서비스 계정 접근 제어 가이드
  - 서비스 계정 구분 방법
  - Kubernetes 환경 구분 방법
  - 정책 로직 설명
  - 테스트 시나리오

## 주요 기능

### 1. 팀별 스키마 접근 제어
- 각 팀(LDAP 그룹)이 접근할 수 있는 스키마를 카탈로그별로 정의
- hive, iceberg 카탈로그 지원

### 2. 서비스 계정 접근 제어
- 5개의 서비스 계정을 명시적으로 정의
- Kubernetes 클러스터 CIDR에서만 접근 허용
- 일반 사용자가 서비스 계정 이름을 사용하는 경우 차단

## 빠른 시작

### 1. 정책 파일 수정

`trino-opa-policy-service-account.rego` 파일을 열어 다음을 수정하세요:

```rego
# 서비스 계정 목록 (실제 계정 이름으로 변경)
service_accounts = [
    "svc-trino-reader",
    "svc-trino-writer",
    "svc-analytics",
    "svc-etl",
    "svc-monitoring"
]

# Kubernetes 클러스터 CIDR (실제 CIDR로 변경)
kubernetes_cluster_cidrs = [
    "10.0.0.0/8",
    "172.16.0.0/12",
    "192.168.0.0/16"
]

# 팀별 스키마 접근 권한 (실제 팀명과 스키마명으로 변경)
team_catalog_schemas = {
    "team-a": {
        "hive": ["team_a_schema", "team_shared_schema"],
        "iceberg": ["team_a_schema", "team_shared_schema"]
    },
    # ...
}
```

### 2. Trino 설정

`etc/access-control.properties` 파일 생성:

```properties
access-control.name=opa
opa.policy.uri=http://opa-server:8181/v1/data/trino/allow
opa.allow-on-error=false
opa.read-timeout=10s
```

### 3. OPA에 정책 배포

```bash
curl -X PUT http://localhost:8181/v1/policies/trino \
  --data-binary @trino-opa-policy-service-account.rego
```

## 상세 문서

- **설정 가이드**: `trino-opa-setup.md` 참조
- **서비스 계정 가이드**: `trino-opa-service-account-guide.md` 참조

## 정책 동작 방식

1. **기본 정책**: 모든 접근을 기본적으로 거부 (`default allow = false`)
2. **서비스 계정**: Kubernetes 클러스터 CIDR에서만 접근 허용
3. **일반 사용자**: 팀별 스키마 접근 권한에 따라 허용/거부
4. **서비스 계정 사용 차단**: 일반 사용자가 서비스 계정 이름을 사용하는 경우 차단

## 주의사항

- 서비스 계정 목록과 Kubernetes CIDR은 실제 환경에 맞게 수정해야 합니다
- IP 정보가 Trino에서 OPA로 전달되려면 추가 설정이 필요할 수 있습니다 (프록시 또는 커스텀 플러그인)
- 정책 변경 후 OPA 서버에 재배포해야 합니다

