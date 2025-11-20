# Trino OPA 서비스 계정 접근 제어 가이드

## 개요

이 가이드는 Trino와 OPA를 사용하여 서비스 계정과 일반 사용자 계정을 구분하고, 서비스 계정은 Kubernetes 환경에서만 사용 가능하도록 제한하는 방법을 설명합니다.

## 요구사항

1. **서비스 계정은 Kubernetes 환경에서만 접근 허용**
2. **일반 사용자가 DB tool로 접근할 때 서비스 계정 사용 차단**

## 구현 방법

### 1. 서비스 계정 구분 방법

서비스 계정을 구분하는 방법은 두 가지가 있습니다:

#### 방법 1: LDAP 그룹으로 구분 (권장)

서비스 계정을 별도의 LDAP 그룹에 배치합니다:
- `service-accounts`
- `svc-accounts`
- `trino-service-accounts`

**장점:**
- 명확하고 관리하기 쉬움
- LDAP에서 중앙 집중식 관리 가능

#### 방법 2: 사용자 이름 패턴으로 구분

서비스 계정 이름에 특정 prefix/suffix를 사용:
- Prefix: `svc-`, `service-`, `trino-svc-`
- Suffix: `-svc`, `-service`

예시:
- `svc-trino-reader`
- `service-analytics`
- `trino-svc-writer`

### 2. Kubernetes 환경 구분 방법

Kubernetes 환경에서 접근하는지 확인하는 방법:

#### 방법 1: IP 대역으로 구분 (권장)

Kubernetes 클러스터의 IP 대역을 정의:
- `10.0.0.0/8` - Kubernetes 기본 서비스 네트워크
- `172.16.0.0/12` - Kubernetes Pod 네트워크 (일부 환경)
- `192.168.0.0/16` - Kubernetes Pod 네트워크 (일부 환경)

**주의:** IP 정보가 Trino에서 OPA로 전달되려면 추가 설정이 필요합니다 (프록시나 커스텀 플러그인 필요).

#### 방법 2: Trino 세션 속성 사용

Trino 클라이언트에서 세션 속성으로 환경을 지정:

```sql
SET SESSION environment = 'kubernetes';
```

이 경우 `input.context.session.environment`로 접근 가능합니다.

### 3. 정책 로직

#### 규칙 1: 서비스 계정은 Kubernetes 환경에서만 허용

```rego
allow {
    is_service_account
    is_kubernetes_environment
}
```

#### 규칙 2: 일반 사용자가 서비스 계정을 사용하려고 하면 차단

```rego
deny_service_account_usage {
    is_regular_user
    # 서비스 계정 이름 패턴 사용 시도
}
```

#### 규칙 3: 서비스 계정이 Kubernetes 환경이 아닌 곳에서 접근 시 차단

```rego
deny_service_account_non_k8s {
    is_service_account
    not is_kubernetes_environment
}
```

## 설정 방법

### 1. LDAP 그룹 구성

LDAP에서 서비스 계정을 별도 그룹으로 구성:

```
# 서비스 계정 그룹 생성
dn: cn=service-accounts,ou=groups,dc=example,dc=com
cn: service-accounts
member: uid=svc-trino-reader,ou=users,dc=example,dc=com
member: uid=svc-analytics,ou=users,dc=example,dc=com
```

### 2. Trino 설정

`etc/access-control.properties`:

```properties
access-control.name=opa
opa.policy.uri=http://opa-server:8181/v1/data/trino/allow
opa.allow-on-error=false
opa.read-timeout=10s
```

### 3. IP 정보 전달 설정 (선택사항)

Kubernetes 환경에서 IP 정보를 전달하려면:

#### 옵션 A: 프록시를 통한 IP 전달

Nginx 등의 프록시를 사용하여 IP 정보를 헤더로 전달:

```nginx
location / {
    proxy_pass http://trino-server:8080;
    proxy_set_header X-Forwarded-For $remote_addr;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Client-IP $remote_addr;
}
```

#### 옵션 B: Trino 세션 속성 사용

Kubernetes Pod에서 Trino에 연결할 때:

```sql
-- Kubernetes 환경임을 명시
SET SESSION environment = 'kubernetes';
```

### 4. OPA 정책 배포

```bash
# 정책 파일 배포
curl -X PUT http://localhost:8181/v1/policies/trino \
  --data-binary @trino-opa-policy-service-account.rego
```

## 테스트 시나리오

### 시나리오 1: 서비스 계정이 Kubernetes에서 접근 (성공)

```json
{
  "context": {
    "identity": {
      "user": "svc-trino-reader",
      "groups": ["service-accounts", "team-a"]
    },
    "source": {
      "ip": "10.0.1.100"
    }
  },
  "action": {
    "type": "QueryAccessControl"
  }
}
```

**예상 결과:** `allow: true`

### 시나리오 2: 서비스 계정이 외부에서 접근 (실패)

```json
{
  "context": {
    "identity": {
      "user": "svc-trino-reader",
      "groups": ["service-accounts"]
    },
    "source": {
      "ip": "203.0.113.50"  # 외부 IP
    }
  },
  "action": {
    "type": "QueryAccessControl"
  }
}
```

**예상 결과:** `allow: false` (Kubernetes 환경이 아님)

### 시나리오 3: 일반 사용자가 서비스 계정 이름 사용 시도 (실패)

```json
{
  "context": {
    "identity": {
      "user": "svc-malicious-user",  # 서비스 계정 이름 패턴 사용
      "groups": ["team-a"]  # 서비스 계정 그룹에 속하지 않음
    }
  },
  "action": {
    "type": "QueryAccessControl"
  }
}
```

**예상 결과:** `allow: false` (일반 사용자가 서비스 계정 이름 사용 차단)

### 시나리오 4: 일반 사용자가 정상 접근 (성공)

```json
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
```

**예상 결과:** `allow: true`

## 주의사항

### 1. IP 정보 전달

기본적으로 Trino는 IP 정보를 OPA에 전달하지 않습니다. Kubernetes 환경 구분을 위해 IP를 사용하려면:
- 프록시를 통한 IP 헤더 전달
- 커스텀 Trino 플러그인 개발
- Trino 세션 속성 사용

### 2. 보안 고려사항

- IP 주소는 스푸핑될 수 있으므로 신뢰할 수 있는 네트워크 경로에서만 사용
- 서비스 계정 자격 증명은 안전하게 관리 (Kubernetes Secrets 등)
- 정기적으로 서비스 계정 사용 현황 감사

### 3. 성능

서비스 계정 검증 로직이 추가되면 OPA 정책 평가 시간이 약간 증가할 수 있습니다.

## 문제 해결

### 문제: 서비스 계정이 Kubernetes에서도 접근이 거부됨

**확인 사항:**
1. IP 정보가 OPA에 전달되는지 확인
2. Kubernetes IP 대역이 정책에 올바르게 정의되었는지 확인
3. 서비스 계정이 올바른 LDAP 그룹에 속해 있는지 확인

**디버깅:**
```bash
# OPA에 테스트 요청 전송하여 input 확인
curl -X POST http://localhost:8181/v1/data/trino/allow \
  -H "Content-Type: application/json" \
  -d @test-input.json | jq '.'
```

### 문제: 일반 사용자가 서비스 계정을 사용할 수 있음

**확인 사항:**
1. 서비스 계정 그룹이 정책에 올바르게 정의되었는지 확인
2. 사용자 이름 패턴이 올바르게 매칭되는지 확인
3. `deny_service_account_usage` 규칙이 올바르게 작동하는지 확인

## 추가 개선 사항

1. **시간 기반 제한**: 서비스 계정 접근 시간 제한
2. **리소스 제한**: 서비스 계정의 쿼리 복잡도 제한
3. **감사 로깅**: 서비스 계정 사용 현황 로깅
4. **자동화**: 서비스 계정 생성/삭제 시 자동으로 LDAP 그룹 관리

